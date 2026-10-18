// OWNER: music
package com.mDev.AdventPraise.audio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.log10
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * The accompaniment's sampler: one SoundFont preset (the bank's piano,
 * program 0) on every MIDI channel, as iOS's AVAudioUnitSampler plays it.
 * Program changes are ignored (the Christ In Song files ask for pads, choir
 * and organ; iOS loads only the piano). Mono out, as the piano is mono.
 *
 * Per voice: linear interpolation through the (looped) sample, the SF2
 * volume envelope (delay, attack, hold, decay, sustain, release; linear in
 * dB), a two-pole low-pass at the zone's cutoff, velocity, channel volume
 * (CC7) and expression (CC11) as the spec's default concave curves, the
 * sustain pedal (CC64) and pitch bend (±2 semitones).
 *
 * Not thread-safe: the owner drives it from one thread (the audio thread).
 */
class PianoSynth(
    private val font: SoundFont,
    val outputRate: Int,
    bank: Int = 0,
    program: Int = 0,
    private val maxVoices: Int = 64,
) {
    private val preset: SoundFont.Preset =
        font.preset(bank, program) ?: font.presets.firstOrNull() ?: error("SoundFont has no presets")
    private val samples = font.samples

    /** The whole mix's level. A hymn peaks near 0.7 (about −19 dBFS RMS). */
    var masterGain = 0.6f

    private class Channel {
        var volume = 100
        var expression = 127
        var sustain = false
        var bend = 8192
        fun reset() { volume = 100; expression = 127; sustain = false; bend = 8192 }
    }

    private val channels = Array(16) { Channel() }
    private val voices = ArrayList<Voice>(maxVoices)
    private var serial = 0L

    val activeVoices: Int get() = voices.size

    // MARK: MIDI

    /** One packed channel message (`status | data1 << 8 | data2 << 16`). */
    fun send(status: Int, data1: Int, data2: Int) {
        val channel = status and 0x0F
        when (status and 0xF0) {
            0x80 -> noteOff(channel, data1)
            0x90 -> if (data2 == 0) noteOff(channel, data1) else noteOn(channel, data1, data2)
            0xB0 -> controller(channel, data1, data2)
            0xE0 -> pitchBend(channel, (data2 shl 7) or data1)
            // 0xC0 program change: every channel stays the piano. Aftertouch is ignored.
        }
    }

    fun noteOn(channel: Int, key: Int, velocity: Int) {
        if (key !in 0..127 || velocity !in 1..127) return
        // A key struck again on its channel releases the note still ringing.
        for (v in voices) if (v.channel == channel && v.key == key && !v.released) v.release()
        for (zone in font.zones(preset, key, velocity)) {
            if (voices.size >= maxVoices) steal()
            voices += Voice(zone, channel, key, velocity, serial++)
        }
    }

    fun noteOff(channel: Int, key: Int) {
        val pedal = channels[channel].sustain
        for (v in voices) if (v.channel == channel && v.key == key && !v.released) {
            if (pedal) v.heldByPedal = true else v.release()
        }
    }

    fun controller(channel: Int, number: Int, value: Int) {
        val ch = channels[channel]
        when (number) {
            7 -> ch.volume = value
            11 -> ch.expression = value
            64 -> {
                ch.sustain = value >= 64
                if (!ch.sustain) for (v in voices) if (v.channel == channel && v.heldByPedal) { v.heldByPedal = false; v.release() }
            }
            120 -> voices.removeAll { it.channel == channel }
            121 -> { ch.reset(); voices.filter { it.channel == channel }.forEach { it.updatePitch() } }
            123 -> for (v in voices) if (v.channel == channel && !v.released) { v.heldByPedal = false; v.release() }
        }
    }

    fun pitchBend(channel: Int, value: Int) {
        channels[channel].bend = value
        for (v in voices) if (v.channel == channel) v.updatePitch()
    }

    /** Every note off at once and every controller back to its default (a seek or a pause). */
    fun reset() {
        voices.clear()
        channels.forEach { it.reset() }
    }

    private fun steal() {
        val victim = voices.filter { it.released }.minByOrNull { it.level } ?: voices.minByOrNull { it.serial } ?: return
        voices.remove(victim)
    }

    // MARK: Rendering

    /** Adds `frames` of the mix into `out` from `offset` (mono, -1…1). */
    fun render(out: FloatArray, offset: Int, frames: Int) {
        var i = 0
        while (i < frames) {
            val n = min(BLOCK, frames - i)
            val it = voices.iterator()
            while (it.hasNext()) {
                val v = it.next()
                if (!v.render(out, offset + i, n)) it.remove()
            }
            i += n
        }
    }

    // MARK: Voice

    private inner class Voice(zone: SoundFont.VoiceZone, val channel: Int, val key: Int, velocity: Int, val serial: Long) {
        private val start = zone.start.coerceIn(0, samples.size - 1)
        private val end = zone.end.coerceIn(start + 1, samples.size)
        private val loopStart = zone.loopStart.coerceIn(start, end - 1)
        private val loopEnd = zone.loopEnd.coerceIn(loopStart + 1, end)
        private val mode = zone.sampleModes
        private val loops: Boolean get() = (mode == 1 || (mode == 3 && !released)) && loopEnd - loopStart > 2
        private val sampleRate = zone.sample.sampleRate.coerceAtLeast(1)
        private val rootKey = zone.rootKey
        private val tuneCents = zone[SoundFont.Gen.COARSE_TUNE] * 100 + zone[SoundFont.Gen.FINE_TUNE] + zone.sample.pitchCorrection
        private val scaleTuning = zone[SoundFont.Gen.SCALE_TUNING]

        private var position = start.toDouble()
        private var step = 1.0

        // Static gain: attenuation (FluidSynth's 0.4 for SF2 banks), velocity (concave).
        private val baseGain: Double = run {
            val attenuation = zone[SoundFont.Gen.INITIAL_ATTENUATION].coerceIn(0, 1440) * 0.4
            centibelsToGain(attenuation) * concave(velocity)
        }

        // Volume envelope, in seconds and centibels.
        private val delay = timecents(zone[SoundFont.Gen.DELAY_VOL_ENV])
        private val attack = timecents(zone[SoundFont.Gen.ATTACK_VOL_ENV])
        private val hold = timecents(zone[SoundFont.Gen.HOLD_VOL_ENV] + zone[SoundFont.Gen.KEYNUM_TO_VOL_ENV_HOLD] * (60 - key))
        private val decay = timecents(zone[SoundFont.Gen.DECAY_VOL_ENV] + zone[SoundFont.Gen.KEYNUM_TO_VOL_ENV_DECAY] * (60 - key))
        private val sustainCb = zone[SoundFont.Gen.SUSTAIN_VOL_ENV].coerceIn(0, SILENT_CB.toInt()).toDouble()
        private val releaseTime = timecents(zone[SoundFont.Gen.RELEASE_VOL_ENV])
        private var time = 0.0
        private var stage = Stage.Delay
        /** Attenuation from the envelope (cB), or the attack's linear level. */
        private var envCb = SILENT_CB
        private var attackLevel = 0.0
        var released = false
            private set
        var heldByPedal = false
        /** The voice's last gain, for stealing the quietest. */
        var level = 0.0
            private set

        // Low-pass (RBJ biquad, Butterworth Q).
        private var b0 = 1.0; private var b1 = 0.0; private var b2 = 0.0; private var a1 = 0.0; private var a2 = 0.0
        private var x1 = 0.0; private var x2 = 0.0; private var y1 = 0.0; private var y2 = 0.0
        private val filtered: Boolean

        init {
            updatePitch()
            // Cutoff: the zone's, plus the mod envelope (its sustain is full while the note is held),
            // minus the spec's velocity-to-cutoff modulator for velocities from 64.
            var cents = zone[SoundFont.Gen.INITIAL_FILTER_FC].toDouble() + zone[SoundFont.Gen.MOD_ENV_TO_FILTER_FC] *
                (1.0 - zone[SoundFont.Gen.SUSTAIN_MOD_ENV].coerceIn(0, 1000) / 1000.0)
            if (velocity >= 64) cents -= 2400.0 * (127 - velocity) / 127.0
            val fc = 8.176 * 2.0.pow(cents.coerceIn(1500.0, 13500.0) / 1200.0)
            filtered = fc < outputRate * 0.45
            if (filtered) {
                val w = 2 * PI * fc / outputRate
                val alpha = sin(w) / (2 * 0.7071)
                val a0 = 1 + alpha
                b0 = (1 - cos(w)) / 2 / a0; b1 = (1 - cos(w)) / a0; b2 = b0
                a1 = -2 * cos(w) / a0; a2 = (1 - alpha) / a0
            }
        }

        fun updatePitch() {
            val bendCents = (channels[channel].bend - 8192) / 8192.0 * BEND_RANGE_CENTS
            val cents = (key - rootKey) * scaleTuning + tuneCents + bendCents
            step = 2.0.pow(cents / 1200.0) * sampleRate / outputRate
        }

        fun release() {
            if (released) return
            if (stage == Stage.Delay) { stage = Stage.Done; released = true; return }
            if (stage == Stage.Attack) envCb = gainToCentibels(attackLevel)
            released = true
            stage = Stage.Release
        }

        /** Advances the envelope `seconds` and returns its gain. */
        private fun envelope(seconds: Double): Double {
            time += seconds
            while (true) {
                when (stage) {
                    Stage.Delay -> if (time >= delay) { time -= delay; stage = Stage.Attack } else return 0.0
                    Stage.Attack -> {
                        if (time >= attack) { time -= attack; stage = Stage.Hold; envCb = 0.0 }
                        else { attackLevel = if (attack > 0) time / attack else 1.0; return attackLevel }
                    }
                    Stage.Hold -> if (time >= hold) { time -= hold; stage = Stage.Decay } else { envCb = 0.0; return 1.0 }
                    Stage.Decay -> {
                        envCb = if (decay > 0) SILENT_CB * time / decay else sustainCb
                        if (envCb >= sustainCb) { envCb = sustainCb; stage = if (sustainCb >= SILENT_CB) Stage.Done else Stage.Sustain }
                        return if (envCb >= SILENT_CB) 0.0 else centibelsToGain(envCb)
                    }
                    Stage.Sustain -> return if (envCb >= SILENT_CB) 0.0 else centibelsToGain(envCb)
                    Stage.Release -> {
                        envCb += if (releaseTime > 0) SILENT_CB * seconds / releaseTime else SILENT_CB
                        time = 0.0
                        if (envCb >= SILENT_CB) { stage = Stage.Done; return 0.0 }
                        return centibelsToGain(envCb)
                    }
                    Stage.Done -> return 0.0
                }
            }
        }

        /** Adds `frames` into `out`; false once the voice has finished. */
        fun render(out: FloatArray, offset: Int, frames: Int): Boolean {
            if (stage == Stage.Done) return false
            val ch = channels[channel]
            val mix = baseGain * concave(ch.volume) * concave(ch.expression) * masterGain
            val from = level
            val env = envelope(frames.toDouble() / outputRate)
            val to = env * mix
            level = to
            if (stage == Stage.Done && from == 0.0) return false
            val gainStep = (to - from) / frames
            var gain = from
            var pos = position
            for (i in 0 until frames) {
                if (loops && pos >= loopEnd) pos -= (loopEnd - loopStart)
                val index = pos.toInt()
                if (index >= end - 1) { stage = Stage.Done; break }
                val frac = pos - index
                val next = if (loops && index + 1 >= loopEnd) samples[loopStart].toDouble() else samples[index + 1].toDouble()
                var x = (samples[index] + (next - samples[index]) * frac) * SAMPLE_SCALE
                if (filtered) {
                    val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                    x2 = x1; x1 = x; y2 = y1; y1 = y
                    x = y
                }
                out[offset + i] += (x * gain).toFloat()
                gain += gainStep
                pos += step
            }
            position = pos
            return stage != Stage.Done
        }
    }

    private enum class Stage { Delay, Attack, Hold, Decay, Sustain, Release, Done }

    companion object {
        /** Frames per envelope step (the gain ramps linearly inside one). */
        const val BLOCK = 64
        /** −96 dB: a voice this far down has ended. */
        const val SILENT_CB = 960.0
        const val BEND_RANGE_CENTS = 200.0
        private const val SAMPLE_SCALE = 1.0 / 32768.0

        /** SF2 timecents to seconds (−12000 and below: instant). */
        fun timecents(tc: Int): Double = if (tc <= -12000) 0.0 else 2.0.pow(tc / 1200.0)

        fun centibelsToGain(cb: Double): Double = 10.0.pow(-cb / 200.0)
        fun gainToCentibels(gain: Double): Double = if (gain <= 0.0) SILENT_CB else min(SILENT_CB, -200.0 * log10(gain))

        /** The spec's concave curve for velocity, volume and expression, as gain: (value / 127)². */
        fun concave(value: Int): Double {
            if (value <= 0) return 0.0
            val x = min(value, 127) / 127.0
            return x * x
        }

        /** Soft limit for the final mix: linear to ±0.8, then easing towards ±1. */
        fun limit(x: Float): Float {
            val a = abs(x)
            if (a <= 0.8f) return x
            val over = (a - 0.8f) / 0.2f
            val shaped = 0.8f + 0.2f * (over / (1f + over))
            return if (x < 0) -shaped else shaped
        }
    }
}
