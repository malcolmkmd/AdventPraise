// OWNER: music
package com.mDev.AdventPraise.audio

/**
 * A Standard MIDI File (format 0 or 1), parsed for playback: every track's
 * channel messages merged into one time-ordered list, each with its time in
 * seconds at the written tempo (through the [TempoMap]), and the length of
 * one pass: to the last End of Track, as iOS's AudioToolbox measures it.
 *
 * Meta events other than tempo and End of Track, and SysEx, are dropped.
 */
class StandardMidiFile private constructor(
    val format: Int,
    val tempoMap: TempoMap,
    /** Ticks of each event, in play order. */
    val ticks: LongArray,
    /** Seconds of each event at the written tempo. */
    val times: DoubleArray,
    /** Each event packed as `status | data1 << 8 | data2 << 16`. */
    val messages: IntArray,
    /** The last End of Track (or last event) tick. */
    val endTick: Long,
) {
    val size: Int get() = messages.size

    /** One pass through the file, in seconds at the written tempo. */
    val lengthSeconds: Double = tempoMap.seconds(endTick)

    fun status(index: Int): Int = messages[index] and 0xFF
    fun data1(index: Int): Int = (messages[index] shr 8) and 0xFF
    fun data2(index: Int): Int = (messages[index] shr 16) and 0xFF

    /** Index of the first event at or after `seconds`. */
    fun firstIndex(atOrAfter: Double): Int {
        var low = 0
        var high = times.size
        while (low < high) {
            val mid = (low + high) ushr 1
            if (times[mid] < atOrAfter) low = mid + 1 else high = mid
        }
        return low
    }

    class FormatException(message: String) : Exception(message)

    companion object {
        /** Parses `bytes`; throws [FormatException] when it isn't a usable MIDI file. */
        fun parse(bytes: ByteArray): StandardMidiFile {
            val r = Reader(bytes)
            if (r.tag() != "MThd") throw FormatException("no MThd")
            val headerLength = r.u32().toInt()
            val format = r.u16()
            val trackCount = r.u16()
            val division = r.u16()
            r.skip(headerLength - 6)
            if (format > 1) throw FormatException("format $format")
            if (division == 0) throw FormatException("division 0")

            class Raw(val tick: Long, val order: Long, val message: Int)
            val raws = ArrayList<Raw>(4096)
            val tempos = ArrayList<Pair<Long, Int>>()
            var endTick = 0L
            var lastTick = 0L
            var order = 0L
            repeat(trackCount) {
                if (r.remaining < 8) return@repeat
                val tag = r.tag()
                val length = r.u32().toInt()
                if (tag != "MTrk") { r.skip(length); return@repeat }
                val end = minOf(r.position + length, bytes.size)
                var tick = 0L
                var running = 0
                var sawEnd = false
                while (r.position < end) {
                    tick += r.vlq()
                    if (r.position >= end) break
                    var status = r.u8()
                    when {
                        status == 0xFF -> {
                            val type = r.u8()
                            val len = r.vlq().toInt()
                            if (type == 0x51 && len >= 3) {
                                val us = (r.peek(0) shl 16) or (r.peek(1) shl 8) or r.peek(2)
                                if (us > 0) tempos += tick to us
                            }
                            r.skip(len)
                            if (type == 0x2F) { endTick = maxOf(endTick, tick); sawEnd = true; break }
                        }
                        status == 0xF0 || status == 0xF7 -> r.skip(r.vlq().toInt())
                        else -> {
                            val data1: Int
                            if (status < 0x80) {
                                if (running == 0) throw FormatException("running status with none set")
                                data1 = status
                                status = running
                            } else {
                                running = status
                                data1 = r.u8()
                            }
                            val kind = status and 0xF0
                            val data2 = if (kind == 0xC0 || kind == 0xD0) 0 else r.u8()
                            raws += Raw(tick, order++, status or (data1 shl 8) or (data2 shl 16))
                            lastTick = maxOf(lastTick, tick)
                        }
                    }
                }
                if (!sawEnd) endTick = maxOf(endTick, tick)
                r.position = end
            }
            // Stable: same tick keeps file (track) order.
            raws.sortWith(compareBy<Raw> { it.tick }.thenBy { it.order })
            val map = TempoMap(division, tempos)
            val ticks = LongArray(raws.size) { raws[it].tick }
            return StandardMidiFile(
                format = format,
                tempoMap = map,
                ticks = ticks,
                times = DoubleArray(raws.size) { map.seconds(ticks[it]) },
                messages = IntArray(raws.size) { raws[it].message },
                endTick = maxOf(endTick, lastTick),
            )
        }
    }

    private class Reader(val bytes: ByteArray) {
        var position = 0
        val remaining: Int get() = bytes.size - position

        fun u8(): Int {
            if (position >= bytes.size) throw FormatException("truncated")
            return bytes[position++].toInt() and 0xFF
        }
        fun peek(offset: Int): Int = bytes.getOrNull(position + offset)?.toInt()?.and(0xFF) ?: 0
        fun u16(): Int = (u8() shl 8) or u8()
        fun u32(): Long = (u16().toLong() shl 16) or u16().toLong()
        fun tag(): String = String(CharArray(4) { u8().toChar() })
        fun skip(n: Int) { position = minOf(bytes.size, position + maxOf(0, n)) }
        fun vlq(): Long {
            var value = 0L
            repeat(4) {
                val b = u8()
                value = (value shl 7) or (b and 0x7F).toLong()
                if (b < 0x80) return value
            }
            return value
        }
    }
}

/**
 * Ticks to seconds and back through a file's tempo changes (120 bpm until
 * the first). SMPTE divisions run at a fixed number of ticks a second.
 */
class TempoMap(private val division: Int, changes: List<Pair<Long, Int>>) {
    /** Tick of each segment's start, its seconds and microseconds per quarter. */
    private val startTicks: LongArray
    private val startSeconds: DoubleArray
    private val microsPerQuarter: IntArray

    init {
        val sorted = changes.sortedBy { it.first }
        val ticks = ArrayList<Long>(); val us = ArrayList<Int>()
        ticks += 0L; us += 500_000
        for ((tick, value) in sorted) {
            if (tick == ticks.last()) us[us.lastIndex] = value else { ticks += tick; us += value }
        }
        startTicks = ticks.toLongArray()
        microsPerQuarter = us.toIntArray()
        startSeconds = DoubleArray(ticks.size)
        for (i in 1 until ticks.size) {
            startSeconds[i] = startSeconds[i - 1] + secondsPerTick(microsPerQuarter[i - 1]) * (startTicks[i] - startTicks[i - 1])
        }
    }

    private val smpte: Boolean get() = division and 0x8000 != 0

    private fun secondsPerTick(us: Int): Double {
        if (smpte) {
            val fps = -(division shr 8).toByte().toInt()
            val perFrame = division and 0xFF
            return 1.0 / (fps.coerceAtLeast(1) * perFrame.coerceAtLeast(1))
        }
        return us / 1_000_000.0 / division
    }

    /** Seconds from the start to `tick`. */
    fun seconds(tick: Long): Double {
        val i = segment(tick)
        return startSeconds[i] + (tick - startTicks[i]) * secondsPerTick(microsPerQuarter[i])
    }

    /** The (fractional) tick at `seconds`. */
    fun tick(seconds: Double): Double {
        var i = startSeconds.size - 1
        while (i > 0 && startSeconds[i] > seconds) i--
        return startTicks[i] + (seconds - startSeconds[i]) / secondsPerTick(microsPerQuarter[i])
    }

    /** Beats per minute at `tick`. */
    fun bpm(tick: Long): Double = 60_000_000.0 / microsPerQuarter[segment(tick)]

    private fun segment(tick: Long): Int {
        var i = startTicks.size - 1
        while (i > 0 && startTicks[i] > tick) i--
        return i
    }
}
