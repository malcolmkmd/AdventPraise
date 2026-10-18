// OWNER: music
package com.mDev.AdventPraise.audio

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * A SoundFont 2 bank, read for playback: the 16-bit samples, the presets,
 * instruments and their zones (SF2.04, sections 7–9). [zones] resolves which
 * samples sound for a key and velocity, with every generator summed the way
 * the spec says (instrument zone over its global zone, plus the preset's
 * offsets).
 */
class SoundFont private constructor(
    val name: String,
    /** Every sample point in the bank (the smpl chunk), 16-bit signed. */
    val samples: ShortArray,
    val sampleHeaders: List<SampleHeader>,
    val presets: List<Preset>,
    val instruments: List<Instrument>,
) {
    data class SampleHeader(
        val name: String,
        val start: Int,
        val end: Int,
        val loopStart: Int,
        val loopEnd: Int,
        val sampleRate: Int,
        val originalPitch: Int,
        val pitchCorrection: Int,
        val type: Int,
    )

    /** One zone's generators, raw (operator → 16-bit amount, signed). */
    class Zone(val generators: Map<Int, Int>) {
        operator fun get(op: Int): Int? = generators[op]
        val keyRange: IntRange get() = range(Gen.KEY_RANGE)
        val velocityRange: IntRange get() = range(Gen.VEL_RANGE)
        private fun range(op: Int): IntRange {
            val raw = generators[op] ?: return 0..127
            return (raw and 0xFF)..((raw shr 8) and 0xFF)
        }
    }

    class Preset(val name: String, val program: Int, val bank: Int, val global: Zone?, val zones: List<Zone>)
    class Instrument(val name: String, val global: Zone?, val zones: List<Zone>)

    /** What sounds for one key: a sample and the summed generators. */
    class VoiceZone(val sample: SampleHeader, private val values: IntArray) {
        operator fun get(op: Int): Int = values[op]
        /** The key the sample was recorded at (overridingRootKey, else the sample's own). */
        val rootKey: Int get() = values[Gen.OVERRIDING_ROOT_KEY].takeIf { it in 0..127 } ?: sample.originalPitch
        /** 0 no loop, 1 loop, 3 loop until released. */
        val sampleModes: Int get() = values[Gen.SAMPLE_MODES] and 3
        val start: Int get() = sample.start + values[Gen.START_ADDRS_OFFSET] + values[Gen.START_ADDRS_COARSE] * 32768
        val end: Int get() = sample.end + values[Gen.END_ADDRS_OFFSET] + values[Gen.END_ADDRS_COARSE] * 32768
        val loopStart: Int get() = sample.loopStart + values[Gen.STARTLOOP_ADDRS_OFFSET] + values[Gen.STARTLOOP_ADDRS_COARSE] * 32768
        val loopEnd: Int get() = sample.loopEnd + values[Gen.ENDLOOP_ADDRS_OFFSET] + values[Gen.ENDLOOP_ADDRS_COARSE] * 32768
    }

    fun preset(bank: Int, program: Int): Preset? =
        presets.firstOrNull { it.bank == bank && it.program == program }

    /**
     * The zones that sound for `key` at `velocity` in `preset`: each matching
     * instrument zone with its generators (defaults, then the instrument's
     * global zone, then its own), plus the preset's offsets (global, then local).
     */
    fun zones(preset: Preset, key: Int, velocity: Int): List<VoiceZone> {
        val out = ArrayList<VoiceZone>(2)
        for (pz in preset.zones) {
            val pKeys = pz[Gen.KEY_RANGE]?.let { pz.keyRange } ?: preset.global?.keyRange ?: 0..127
            val pVels = pz[Gen.VEL_RANGE]?.let { pz.velocityRange } ?: preset.global?.velocityRange ?: 0..127
            if (key !in pKeys || velocity !in pVels) continue
            val instrument = pz[Gen.INSTRUMENT]?.let(instruments::getOrNull) ?: continue
            for (iz in instrument.zones) {
                val iKeys = iz[Gen.KEY_RANGE]?.let { iz.keyRange } ?: instrument.global?.keyRange ?: 0..127
                val iVels = iz[Gen.VEL_RANGE]?.let { iz.velocityRange } ?: instrument.global?.velocityRange ?: 0..127
                if (key !in iKeys || velocity !in iVels) continue
                val sample = iz[Gen.SAMPLE_ID]?.let(sampleHeaders::getOrNull) ?: continue
                val values = Gen.defaults.copyOf()
                instrument.global?.generators?.forEach { (op, v) -> if (op < values.size) values[op] = v }
                iz.generators.forEach { (op, v) -> if (op < values.size) values[op] = v }
                // Preset generators add to the instrument's (local replaces global, per operator).
                val offsets = HashMap<Int, Int>()
                preset.global?.generators?.forEach { (op, v) -> offsets[op] = v }
                pz.generators.forEach { (op, v) -> offsets[op] = v }
                offsets.forEach { (op, v) -> if (op < values.size && op in Gen.additive) values[op] += v }
                out += VoiceZone(sample, values)
            }
        }
        return out
    }

    /** Generator operators (SF2.04 section 8.1.2). */
    object Gen {
        const val START_ADDRS_OFFSET = 0
        const val END_ADDRS_OFFSET = 1
        const val STARTLOOP_ADDRS_OFFSET = 2
        const val ENDLOOP_ADDRS_OFFSET = 3
        const val START_ADDRS_COARSE = 4
        const val MOD_LFO_TO_PITCH = 5
        const val VIB_LFO_TO_PITCH = 6
        const val MOD_ENV_TO_PITCH = 7
        const val INITIAL_FILTER_FC = 8
        const val INITIAL_FILTER_Q = 9
        const val MOD_LFO_TO_FILTER_FC = 10
        const val MOD_ENV_TO_FILTER_FC = 11
        const val END_ADDRS_COARSE = 12
        const val MOD_LFO_TO_VOLUME = 13
        const val CHORUS_SEND = 15
        const val REVERB_SEND = 16
        const val PAN = 17
        const val DELAY_MOD_ENV = 25
        const val ATTACK_MOD_ENV = 26
        const val HOLD_MOD_ENV = 27
        const val DECAY_MOD_ENV = 28
        const val SUSTAIN_MOD_ENV = 29
        const val RELEASE_MOD_ENV = 30
        const val DELAY_VOL_ENV = 33
        const val ATTACK_VOL_ENV = 34
        const val HOLD_VOL_ENV = 35
        const val DECAY_VOL_ENV = 36
        const val SUSTAIN_VOL_ENV = 37
        const val RELEASE_VOL_ENV = 38
        const val KEYNUM_TO_VOL_ENV_HOLD = 39
        const val KEYNUM_TO_VOL_ENV_DECAY = 40
        const val INSTRUMENT = 41
        const val KEY_RANGE = 43
        const val VEL_RANGE = 44
        const val STARTLOOP_ADDRS_COARSE = 45
        const val KEYNUM = 46
        const val VELOCITY = 47
        const val INITIAL_ATTENUATION = 48
        const val ENDLOOP_ADDRS_COARSE = 50
        const val COARSE_TUNE = 51
        const val FINE_TUNE = 52
        const val SAMPLE_ID = 53
        const val SAMPLE_MODES = 54
        const val SCALE_TUNING = 56
        const val EXCLUSIVE_CLASS = 57
        const val OVERRIDING_ROOT_KEY = 58
        const val COUNT = 61

        /** Every generator's default (section 8.1.3). */
        val defaults: IntArray = IntArray(COUNT).also {
            it[INITIAL_FILTER_FC] = 13500
            for (op in intArrayOf(DELAY_MOD_ENV, ATTACK_MOD_ENV, HOLD_MOD_ENV, DECAY_MOD_ENV, RELEASE_MOD_ENV,
                DELAY_VOL_ENV, ATTACK_VOL_ENV, HOLD_VOL_ENV, DECAY_VOL_ENV, RELEASE_VOL_ENV)) it[op] = -12000
            it[KEY_RANGE] = 0x7F00
            it[VEL_RANGE] = 0x7F00
            it[KEYNUM] = -1
            it[VELOCITY] = -1
            it[SCALE_TUNING] = 100
            it[OVERRIDING_ROOT_KEY] = -1
        }

        /** Operators a preset zone may offset (not ranges, indexes, sample addressing or modes). */
        val additive: Set<Int> = (0 until COUNT).toSet() - setOf(
            START_ADDRS_OFFSET, END_ADDRS_OFFSET, STARTLOOP_ADDRS_OFFSET, ENDLOOP_ADDRS_OFFSET,
            START_ADDRS_COARSE, END_ADDRS_COARSE, STARTLOOP_ADDRS_COARSE, ENDLOOP_ADDRS_COARSE,
            INSTRUMENT, KEY_RANGE, VEL_RANGE, KEYNUM, VELOCITY, SAMPLE_ID, SAMPLE_MODES, EXCLUSIVE_CLASS,
            OVERRIDING_ROOT_KEY, 14, 18, 19, 20, 42, 49, 55, 59, 60,
        )
    }

    class FormatException(message: String) : Exception(message)

    companion object {
        /** Reads a whole .sf2 file. Throws [FormatException] when it isn't one. */
        fun parse(bytes: ByteArray): SoundFont {
            val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            fun tag(at: Int) = String(CharArray(4) { (bytes[at + it].toInt() and 0xFF).toChar() })
            if (bytes.size < 12 || tag(0) != "RIFF" || tag(8) != "sfbk") throw FormatException("not a SoundFont")
            val end = minOf(bytes.size, 8 + buf.getInt(4))

            var name = ""
            var smplAt = -1
            var smplLength = 0
            val pdta = HashMap<String, Pair<Int, Int>>()

            fun chunks(from: Int, to: Int, each: (String, Int, Int) -> Unit) {
                var at = from
                while (at + 8 <= to) {
                    val id = tag(at)
                    val size = buf.getInt(at + 4)
                    if (size < 0 || at + 8 + size > bytes.size) throw FormatException("chunk $id overruns")
                    each(id, at + 8, size)
                    at += 8 + size + (size and 1)
                }
            }

            chunks(12, end) { id, body, size ->
                if (id != "LIST") return@chunks
                val list = tag(body)
                chunks(body + 4, body + size) { sub, at, length ->
                    when (list) {
                        "INFO" -> if (sub == "INAM") name = cString(bytes, at, length)
                        "sdta" -> if (sub == "smpl") { smplAt = at; smplLength = length }
                        "pdta" -> pdta[sub] = at to length
                    }
                }
            }
            if (smplAt < 0) throw FormatException("no samples")
            val samples = ShortArray(smplLength / 2)
            ByteBuffer.wrap(bytes, smplAt, smplLength - (smplLength and 1)).order(ByteOrder.LITTLE_ENDIAN)
                .asShortBuffer().get(samples)

            fun records(id: String, size: Int): List<Int> {
                val (at, length) = pdta[id] ?: throw FormatException("no $id")
                return (0 until length / size).map { at + it * size }
            }
            fun gens(id: String): List<Pair<Int, Int>> = records(id, 4).map {
                (buf.getShort(it).toInt() and 0xFFFF) to buf.getShort(it + 2).toInt()
            }
            fun bags(id: String): List<Int> = records(id, 4).map { buf.getShort(it).toInt() and 0xFFFF }

            val pgen = gens("pgen")
            val igen = gens("igen")
            val pbag = bags("pbag")
            val ibag = bags("ibag")

            // A zone is global when it is first and doesn't end with its instrument / sample.
            fun zonesOf(bagFrom: Int, bagTo: Int, bagGens: List<Int>, all: List<Pair<Int, Int>>, terminal: Int): Pair<Zone?, List<Zone>> {
                var global: Zone? = null
                val zones = ArrayList<Zone>()
                for (b in bagFrom until bagTo) {
                    val from = bagGens.getOrNull(b) ?: continue
                    val to = bagGens.getOrNull(b + 1) ?: all.size
                    val map = LinkedHashMap<Int, Int>()
                    for (g in from until minOf(to, all.size)) {
                        val (op, raw) = all[g]
                        // Ranges are two unsigned bytes; everything else is signed.
                        map[op] = if (op == Gen.KEY_RANGE || op == Gen.VEL_RANGE) raw and 0xFFFF else raw
                    }
                    val zone = Zone(map)
                    if (terminal !in map) { if (b == bagFrom && global == null) global = zone } else zones += zone
                }
                return global to zones
            }

            val instRecords = records("inst", 22)
            val instruments = instRecords.dropLast(1).mapIndexed { i, at ->
                val (global, zones) = zonesOf(buf.getShort(at + 20).toInt() and 0xFFFF,
                    buf.getShort(instRecords[i + 1] + 20).toInt() and 0xFFFF, ibag, igen, Gen.SAMPLE_ID)
                Instrument(cString(bytes, at, 20), global, zones)
            }
            val presetRecords = records("phdr", 38)
            val presets = presetRecords.dropLast(1).mapIndexed { i, at ->
                val (global, zones) = zonesOf(buf.getShort(at + 24).toInt() and 0xFFFF,
                    buf.getShort(presetRecords[i + 1] + 24).toInt() and 0xFFFF, pbag, pgen, Gen.INSTRUMENT)
                Preset(cString(bytes, at, 20), buf.getShort(at + 20).toInt() and 0xFFFF,
                    buf.getShort(at + 22).toInt() and 0xFFFF, global, zones)
            }
            val headers = records("shdr", 46).dropLast(1).map { at ->
                SampleHeader(
                    name = cString(bytes, at, 20),
                    start = buf.getInt(at + 20),
                    end = buf.getInt(at + 24),
                    loopStart = buf.getInt(at + 28),
                    loopEnd = buf.getInt(at + 32),
                    sampleRate = buf.getInt(at + 36),
                    originalPitch = bytes[at + 40].toInt() and 0xFF,
                    pitchCorrection = bytes[at + 41].toInt(),
                    type = buf.getShort(at + 44).toInt() and 0xFFFF,
                )
            }
            return SoundFont(name, samples, headers, presets, instruments)
        }

        private fun cString(bytes: ByteArray, at: Int, length: Int): String {
            val end = (at until at + length).firstOrNull { bytes[it].toInt() == 0 } ?: (at + length)
            return String(bytes, at, end - at, Charsets.ISO_8859_1)
        }
    }
}
