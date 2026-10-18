// OWNER: music
package com.mDev.AdventPraise.audio

import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import kotlin.math.max
import kotlin.math.min

/** One time through the tune: a verse, then the chorus when the hymn has exactly one (Hymn.AccompanimentPass). */
data class AccompanimentPass(val verse: Int, val verseLines: Int, val chorusLines: Int)

/** The tune is played once per verse; a chorus-only hymn gets one pass (verse 0). */
val Hymn.accompanimentPasses: List<AccompanimentPass>
    get() {
        val choruses = blocks.filterIsInstance<Block.Chorus>()
        val chorusLines = if (choruses.size == 1) choruses[0].lines.size else 0
        val passes = blocks.filterIsInstance<Block.Verse>().map { AccompanimentPass(it.number, it.lines.size, chorusLines) }
        return passes.ifEmpty { listOf(AccompanimentPass(0, 0, chorusLines)) }
    }

/** Where the accompaniment is (PlaybackPosition on iOS). */
data class PlaybackPosition(
    /** The verse being played, as numbered in the hymn (0 for a chorus-only hymn). */
    val verse: Int,
    /** 1-based pass through the tune, for "Verse 2 of 4". */
    val pass: Int,
    val isChorus: Boolean,
    /** Line of the verse or chorus being sung: each pass split evenly across its lines. */
    val line: Int?,
)

/**
 * The performance's arithmetic (HymnMIDIEngine on iOS): `elapsed` is
 * seconds into the whole performance (every verse) at the written tempo;
 * the tune is `passDuration` long and played `passes` times. Wall-clock time
 * is performance time ÷ rate.
 */
object PassClock {
    /** `time` clamped into the performance. */
    fun clamp(time: Double, duration: Double): Double = min(max(time, 0.0), max(duration, 0.0))

    /** The pass (0-based) at `elapsed`. */
    fun passIndex(elapsed: Double, passDuration: Double, passes: Int): Int {
        if (passes <= 0 || passDuration <= 0) return 0
        return min(max((elapsed / passDuration).toInt(), 0), passes - 1)
    }

    /** Seconds into the pass at `elapsed`. */
    fun passOffset(elapsed: Double, passDuration: Double, passes: Int): Double {
        if (passes <= 0 || passDuration <= 0) return 0.0
        return min(max(elapsed - passIndex(elapsed, passDuration, passes) * passDuration, 0.0), passDuration)
    }

    /** Where a seek to `time` lands: the pass and the offset into it (iOS `seek(to:)`). */
    fun seekTarget(time: Double, passDuration: Double, passes: Int): Pair<Int, Double> {
        if (passes <= 0 || passDuration <= 0) return 0 to 0.0
        val clamped = clamp(time, passDuration * passes)
        val pass = min((clamped / passDuration).toInt(), passes - 1)
        return pass to min(clamped - pass * passDuration, passDuration)
    }

    /** The verse and line at `elapsed`, or null when nothing is active. */
    fun position(passes: List<AccompanimentPass>, elapsed: Double, passDuration: Double): PlaybackPosition? {
        if (passes.isEmpty() || passDuration <= 0) return null
        val index = passIndex(elapsed, passDuration, passes.size)
        val current = passes[index]
        val lines = current.verseLines + current.chorusLines
        if (lines <= 0) return PlaybackPosition(current.verse, index + 1, false, null)
        val fraction = min(max(passOffset(elapsed, passDuration, passes.size) / passDuration, 0.0), 0.9999)
        val line = (fraction * lines).toInt()
        return if (line < current.verseLines) PlaybackPosition(current.verse, index + 1, false, line)
        else PlaybackPosition(current.verse, index + 1, true, line - current.verseLines)
    }

    /** "1:05" for a scrub bar label. */
    fun clock(seconds: Double): String {
        val whole = Math.round(max(seconds, 0.0)).toInt()
        return "%d:%02d".format(whole / 60, whole % 60)
    }
}

/**
 * Plays a MIDI file through a [PianoSynth], `passes` times back to back,
 * sample-accurately: each event sounds at its own frame inside a block, at
 * the current rate (tempo). Not thread-safe; the engine drives it from the
 * audio thread under its own lock.
 */
class MidiRenderer(val file: StandardMidiFile, val synth: PianoSynth, val passes: Int) {
    val passDuration: Double = file.lengthSeconds
    val duration: Double = passDuration * passes

    var pass = 0
        private set
    /** Seconds into the current pass, at the written tempo. */
    var offset = 0.0
        private set
    var rate = 1.0
    /** Past the end of the last pass: only release tails sound. */
    var isFinished = false
        private set
    private var next = 0

    /** Seconds into the whole performance. */
    val elapsed: Double get() = pass * passDuration + offset

    /** Jumps to `time` (performance seconds): silences everything and restores the controllers set before it. */
    fun seek(time: Double) {
        val (p, o) = PassClock.seekTarget(time, passDuration, passes)
        pass = p
        offset = o
        isFinished = false
        synth.reset()
        next = file.firstIndex(o)
        // Chase: volume, expression, pedal and bend as they stood (notes aren't re-struck).
        for (i in 0 until next) {
            val status = file.status(i)
            val kind = status and 0xF0
            if (kind == 0xB0 || kind == 0xE0) synth.send(status, file.data1(i), file.data2(i))
        }
    }

    /** Renders `frames` into `out` from `at` (overwrites). Advances the performance. */
    fun render(out: FloatArray, at: Int, frames: Int) {
        java.util.Arrays.fill(out, at, at + frames, 0f)
        val secondsPerFrame = rate / synth.outputRate
        var done = 0
        while (done < frames) {
            if (isFinished) {
                synth.render(out, at + done, frames - done)
                break
            }
            // Events due now.
            while (next < file.size && file.times[next] <= offset + 1e-9) {
                synth.send(file.status(next), file.data1(next), file.data2(next))
                next++
            }
            val untilEvent = if (next < file.size) file.times[next] - offset else Double.MAX_VALUE
            val untilEnd = passDuration - offset
            val span = min(untilEvent, untilEnd)
            val framesToSpan = if (span <= 0) 0 else min((frames - done).toLong(), Math.ceil(span / secondsPerFrame).toLong()).toInt()
            if (framesToSpan > 0) {
                synth.render(out, at + done, framesToSpan)
                done += framesToSpan
                offset = min(offset + framesToSpan * secondsPerFrame, passDuration)
            }
            if (offset >= passDuration) {
                // The pass is over: its last events (the closing note-offs) first, then the
                // tune from the top for the next verse, or the end.
                while (next < file.size) {
                    synth.send(file.status(next), file.data1(next), file.data2(next))
                    next++
                }
                if (pass + 1 < passes) {
                    pass++
                    offset = 0.0
                    next = 0
                } else {
                    offset = passDuration
                    isFinished = true
                }
            }
        }
        for (i in at until at + frames) out[i] = PianoSynth.limit(out[i])
    }
}
