package com.mDev.AdventPraise.data

import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * When each part of a hymn's score sounds in its accompaniment, and where it
 * sits on the page (SheetMusicTiming.swift), so the sheet music can follow
 * the MIDI player. Times are seconds into one pass through the MIDI file at
 * its written tempo; the player plays the file once per verse, so the
 * timing repeats for each verse.
 *
 * JSON (one deflated chunk per hymn in sheet-music-sync.pack):
 *     len    one pass through the MIDI file, seconds
 *     match  share of the melody matched to the MIDI
 *     m      [[t, measure], …] measure starts in performance order
 *     e      [[t, note], …] note onsets, in time order
 *     l, nm  each note's voice (0 is the melody) and measure
 *     v      the app's verse number on lyric line 1, 2, …
 *     geo    {"phone"|"pad"|"line": {"ss": staff space, "sy": systems, "ms": each measure's system,
 *             "m": measure boxes, "n": [[x, y, [[line, x, y, w, size], …]], …] noteheads and syllables}}
 * Coordinates are the page's SVG units. A hymn whose notes couldn't be
 * matched one for one has no `e` or `n`: it follows by measure.
 */
data class SheetMusicTiming(
    val passLength: Double,
    val match: Double = 1.0,
    val measureTimes: List<Double>,
    val measureOrder: List<Int>,
    val noteTimes: List<Double> = emptyList(),
    val noteOrder: List<Int> = emptyList(),
    val noteVoices: List<Int> = emptyList(),
    val noteMeasures: List<Int> = emptyList(),
    val verseNumbers: List<Int> = emptyList(),
    val geometry: Map<SheetMusicLayout, Geometry>,
) {
    data class Box(val x: Double, val y: Double, val width: Double, val height: Double)

    data class Syllable(
        /** Lyric line, from 1. */
        val line: Int,
        val x: Double,
        /** Baseline. */
        val y: Double,
        val width: Double,
        val size: Double,
    )

    data class Note(val x: Double, val y: Double, val syllables: List<Syllable>)

    data class Geometry(
        /** Distance between staff lines. */
        val staffSpace: Double = 9.0,
        val measures: List<Box>,
        val notes: List<Note>,
        /** Lines of music, top to bottom: each a band of the page. */
        val systems: List<Box> = emptyList(),
        /** Each measure's system. */
        val measureSystems: List<Int> = emptyList(),
    ) {
        /** The system measure `measure` is in (0 when unknown). */
        fun system(ofMeasure: Int): Int = measureSystems.getOrNull(ofMeasure) ?: 0

        /** The first measure of system `system`, or null past the end. */
        fun firstMeasure(ofSystem: Int): Int? = measureSystems.indexOf(ofSystem).takeIf { it >= 0 }

        /** The widest system's left edge and width, so every system shows at one size. */
        val systemExtent: Pair<Double, Double>
            get() {
                if (systems.isEmpty()) return 0.0 to 0.0
                val left = systems.minOf { it.x }
                val right = systems.maxOf { it.x + it.width }
                return left to right - left
            }
    }

    /** What's sounding: the measure, the melody note and the syllable being sung. */
    data class Cue(val measure: Int, val note: Int?, val syllableNote: Int?, val syllableLine: Int?)

    val followsNotes: Boolean get() = noteTimes.isNotEmpty() && noteVoices.isNotEmpty()

    /** Lyric line that carries app verse `verse`; line 1 for a chorus or a verse not under the music. */
    fun lyricLine(forVerse: Int?): Int {
        val index = forVerse?.let { verseNumbers.indexOf(it) } ?: -1
        return if (index >= 0) index + 1 else 1
    }

    /** What's sounding `offset` seconds into a pass while verse `verse` is sung. */
    fun cue(offset: Double, verse: Int?): Cue {
        val mIndex = lastIndex(measureTimes, offset + 0.02) ?: 0
        val measure = measureOrder[mIndex]
        val start = measureTimes[mIndex]
        val notes = geometry[SheetMusicLayout.Phone]?.notes ?: geometry.values.firstOrNull()?.notes
        val last = lastIndex(noteTimes, offset + 0.02)
        if (!followsNotes || notes == null || last == null) return Cue(measure, null, null, null)
        val line = lyricLine(verse)
        var note: Int? = null
        var syllableNote: Int? = null
        var sungLine: Int? = null
        var index: Int = last
        while (index >= 0 && noteTimes[index] >= start - 0.001) {
            val n = noteOrder[index]
            if (note == null && noteVoices.getOrNull(n) == 0 && noteMeasures.getOrNull(n) == measure) note = n
            if (syllableNote == null && n in notes.indices) {
                syllableLine(notes[n], line)?.let { syllableNote = n; sungLine = it }
            }
            if (note != null && syllableNote != null) break
            index -= 1
        }
        return Cue(measure, note, syllableNote, sungLine)
    }

    /**
     * Where to seek, in seconds into the pass, for a tap on `measure` while
     * at `offset`: the next time it's played, else the latest (a repeat being played again).
     */
    fun seekOffset(toMeasure: Int, from: Double): Double? {
        val times = measureTimes.zip(measureOrder).filter { it.second == toMeasure }.map { it.first }
        if (times.isEmpty()) return null
        return times.firstOrNull { it >= from } ?: times.last()
    }

    /** The measure under a point on the page (SVG units), or null. */
    fun measure(atX: Double, y: Double, layout: SheetMusicLayout): Int? {
        val boxes = geometry[layout]?.measures ?: return null
        var best: Pair<Int, Double>? = null
        boxes.forEachIndexed { index, box ->
            if (atX < box.x || atX > box.x + box.width || y < box.y - box.height * 0.2 || y > box.y + box.height * 1.2) {
                return@forEachIndexed
            }
            val distance = abs(y - (box.y + box.height / 2))
            if (best == null || distance < best!!.second) best = index to distance
        }
        return best?.first
    }

    companion object {
        /** Seconds into the current pass, from elapsed time across every verse; null before anything loads. */
        fun passOffset(elapsed: Double, duration: Double, passes: Int): Double? {
            if (passes <= 0 || duration <= 0) return null
            val pass = duration / passes
            val index = min(max((elapsed / pass).toInt(), 0), passes - 1)
            return min(max(elapsed - index * pass, 0.0), pass)
        }

        /** The pass (0-based) the player is in. */
        fun passIndex(elapsed: Double, duration: Double, passes: Int): Int {
            if (passes <= 0 || duration <= 0) return 0
            return min(max((elapsed / (duration / passes)).toInt(), 0), passes - 1)
        }

        /** The note's syllable on `line`, or the one line all verses share (a refrain written once). */
        fun syllableLine(note: Note, line: Int): Int? {
            if (note.syllables.any { it.line == line }) return line
            if (note.syllables.size == 1 && note.syllables[0].line == 1) return 1
            return null
        }

        /** Last index with `times[i] <= t`, or null. */
        private fun lastIndex(times: List<Double>, t: Double): Int? {
            var low = 0
            var high = times.size
            while (low < high) {
                val mid = (low + high) / 2
                if (times[mid] <= t) low = mid + 1 else high = mid
            }
            return if (low > 0) low - 1 else null
        }

        /** Decodes one sync chunk, exactly as iOS does; null when it isn't usable. */
        fun parse(json: String): SheetMusicTiming? {
            val root = Json.parseOrNull(json).jsonObject() ?: return null
            val length = root["len"].jsonDouble() ?: return null
            val measures = root["m"].jsonArray()?.map { row -> row.jsonArray()?.map { it as? Number } ?: return null }
                ?: return null
            if (measures.isEmpty() || measures.any { it.size < 2 || it[0] == null || it[1] == null }) return null
            val geo = root["geo"].jsonObject() ?: return null
            val events = root["e"].jsonArray().orEmpty().mapNotNull { row ->
                row.jsonArray()?.let { r -> if (r.size >= 2 && r[0] is Number && r[1] is Number) r else null }
            }
            val geometry = LinkedHashMap<SheetMusicLayout, Geometry>()
            for (layout in SheetMusicLayout.entries) {
                val entry = geo[layout.key].jsonObject() ?: continue
                val boxes = entry["m"].jsonArray() ?: continue
                val measureBoxes = boxes.mapNotNull(::box)
                val notes = entry["n"].jsonArray().orEmpty().mapNotNull { raw ->
                    val n = raw.jsonArray() ?: return@mapNotNull null
                    if (n.size != 3) return@mapNotNull null
                    val x = n[0].jsonDouble() ?: return@mapNotNull null
                    val y = n[1].jsonDouble() ?: return@mapNotNull null
                    val syllables = n[2].jsonArray().orEmpty().mapNotNull { s ->
                        val v = s.jsonArray()?.map { it.jsonDouble() } ?: return@mapNotNull null
                        if (v.size != 5 || v.any { it == null }) return@mapNotNull null
                        Syllable(v[0]!!.toInt(), v[1]!!, v[2]!!, v[3]!!, v[4]!!)
                    }
                    Note(x, y, syllables)
                }
                val systems = entry["sy"].jsonArray().orEmpty().mapNotNull(::box)
                var measureSystems = entry["ms"].jsonArray().orEmpty().mapNotNull { it.jsonInt() }
                if (measureSystems.size != measureBoxes.size || measureSystems.any { it !in systems.indices }) {
                    measureSystems = emptyList()
                }
                geometry[layout] = Geometry(
                    staffSpace = entry["ss"].jsonDouble() ?: 9.0,
                    measures = measureBoxes,
                    notes = notes,
                    systems = if (measureSystems.isEmpty()) emptyList() else systems,
                    measureSystems = measureSystems,
                )
            }
            if (geometry.isEmpty()) return null
            return SheetMusicTiming(
                passLength = length,
                match = root["match"].jsonDouble() ?: 0.0,
                measureTimes = measures.map { it[0]!!.toDouble() },
                measureOrder = measures.map { it[1]!!.toInt() },
                noteTimes = events.map { (it[0] as Number).toDouble() },
                noteOrder = events.map { (it[1] as Number).toInt() },
                noteVoices = root["l"].jsonArray().orEmpty().mapNotNull { it.jsonInt() },
                noteMeasures = root["nm"].jsonArray().orEmpty().mapNotNull { it.jsonInt() },
                verseNumbers = root["v"].jsonArray().orEmpty().mapNotNull { it.jsonInt() },
                geometry = geometry,
            )
        }

        private fun box(raw: Any?): Box? {
            val b = raw.jsonArray()?.map { it.jsonDouble() } ?: return null
            if (b.size != 4 || b.any { it == null }) return null
            return Box(b[0]!!, b[1]!!, b[2]!!, b[3]!!)
        }
    }
}

/** Page or one system at a time, in the full-screen viewer. Remembered ("sheetMusic.viewMode"). */
enum class SheetMusicViewMode(val key: String) {
    Page("page"), System("system");

    companion object {
        fun of(key: String?): SheetMusicViewMode? = entries.firstOrNull { it.key == key }
    }
}

/**
 * The marks on the page for what's sounding (SheetMusicHighlight on iOS):
 * the measure's box, a dot on the melody note and the syllable's box.
 */
data class SheetMusicHighlight(
    val measure: SheetMusicTiming.Box? = null,
    /** Centre and radius of the mark on the melody note. */
    val note: Triple<Double, Double, Double>? = null,
    val syllable: SheetMusicTiming.Box? = null,
) {
    /** For the page's script: `{"m": {...}, "n": {...}, "s": {...}}`, null for a mark not shown. */
    val script: String
        get() {
            fun rect(b: SheetMusicTiming.Box?) = b?.let {
                String.format(Locale.ROOT, "{\"x\":%.1f,\"y\":%.1f,\"width\":%.1f,\"height\":%.1f}", it.x, it.y, it.width, it.height)
            } ?: "null"
            val dot = note?.let { String.format(Locale.ROOT, "{\"cx\":%.1f,\"cy\":%.1f,\"r\":%.1f}", it.first, it.second, it.third) } ?: "null"
            return "{\"m\":${rect(measure)},\"n\":$dot,\"s\":${rect(syllable)}}"
        }

    companion object {
        val none = SheetMusicHighlight()

        /** The marks for `cue` on a page drawn with `geometry`. */
        fun of(cue: SheetMusicTiming.Cue, geometry: SheetMusicTiming.Geometry): SheetMusicHighlight {
            val space = geometry.staffSpace
            val measure = geometry.measures.getOrNull(cue.measure)?.let { box ->
                SheetMusicTiming.Box(box.x - space * 0.4, box.y - space * 1.6, box.width + space * 0.8, box.height + space * 3.2)
            }
            val note = cue.note?.let { geometry.notes.getOrNull(it) }?.let { head ->
                Triple(head.x + space * 0.6, head.y, space * 1.05)
            }
            val line = cue.syllableLine
            val syllable = if (line == null) null else cue.syllableNote?.let { geometry.notes.getOrNull(it) }
                ?.syllables?.firstOrNull { it.line == line }
                ?.let { s -> SheetMusicTiming.Box(s.x - s.size * 0.18, s.y - s.size * 0.86, s.width + s.size * 0.36, s.size * 1.14) }
            return SheetMusicHighlight(measure, note, syllable)
        }
    }
}

/**
 * Where the page sits so one system (a band of it) fills a rectangle of the
 * view: a scale, a translation and a clip, in dp (SheetMusicSystemFrame).
 */
data class SheetMusicSystemFrame(
    val scale: Double,
    val x: Double,
    val y: Double,
    /** The page's width once scaled. */
    val width: Double,
    val clipTop: Double,
    val clipRight: Double,
    val clipBottom: Double,
    val clipLeft: Double,
) {
    /** A point in the view, in the page's SVG units. */
    fun pagePoint(px: Double, py: Double): Pair<Double, Double> = (px - x) / scale to (py - y) / scale

    /** For the page's script. */
    val script: String
        get() = String.format(Locale.ROOT, "{\"w\":%.2f,\"tx\":%.2f,\"ty\":%.2f,\"ct\":%.2f,\"cr\":%.2f,\"cb\":%.2f,\"cl\":%.2f}",
            width, x, y, clipTop, clipRight, clipBottom, clipLeft)

    companion object {
        /**
         * `band` fitted into the rectangle (centred, as large as fits), every
         * system at the size that makes `extent` (the widest system) fill the width.
         */
        fun fit(
            band: SheetMusicTiming.Box, extentX: Double, extentWidth: Double,
            pageWidth: Double, pageHeight: Double,
            rectX: Double, rectY: Double, rectWidth: Double, rectHeight: Double,
        ): SheetMusicSystemFrame? {
            if (band.width <= 0 || band.height <= 0 || extentWidth <= 0 || rectWidth <= 0 || rectHeight <= 0) return null
            val scale = min(rectWidth / extentWidth, rectHeight / band.height)
            val x = rectX + (rectWidth - extentWidth * scale) / 2 - extentX * scale
            val y = rectY + (rectHeight - band.height * scale) / 2 - band.y * scale
            return SheetMusicSystemFrame(
                scale = scale, x = x, y = y, width = pageWidth * scale,
                clipTop = band.y * scale,
                clipRight = max(0.0, pageWidth - band.x - band.width) * scale,
                clipBottom = max(0.0, pageHeight - band.y - band.height) * scale,
                clipLeft = band.x * scale,
            )
        }
    }
}
