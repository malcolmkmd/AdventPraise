package com.mDev.AdventPraise.data

import android.content.res.AssetManager
import java.text.Normalizer
import java.util.Locale

/**
 * How a hymnal numbers its hymns (HymnNumbering on iOS). Christ In Song and
 * its translations share one numbering; the SDA Hymnal (1985) has its own,
 * matched to Christ In Song only by cross-reference ([CrossReference]).
 */
enum class Numbering(val key: String) { ChristInSong("cis"), Sdah("sdah") }

/**
 * One hymnal of hymnals.json: the file key, its own title and its language
 * (HymnalInfo on iOS). A hymnal added on iOS shows up here with no code change.
 */
data class HymnalInfo(
    /** File key, e.g. "english", "ndebele", "sdah". */
    val id: String,
    /** The hymnal's own title, e.g. "Christ In Song". */
    val name: String,
    val language: String,
    val hymnCount: Int,
    val maxNumber: Int,
) {
    /** Christ In Song and its translations share numbers; the SDA Hymnal has its own. */
    val numbering: Numbering get() = if (id == SDAH_ID) Numbering.Sdah else Numbering.ChristInSong

    /**
     * A hymnal of its own (the SDA Hymnal) rather than a translation of
     * Christ In Song: its own numbers, and a tile across the whole row in the
     * translation picker, tagged as its own numbering (DSHymnal.isOwnBook).
     */
    val isOwnBook: Boolean get() = numbering == Numbering.Sdah

    /** The globe's label: the language, or for the SDA Hymnal (English too) the book. */
    val shortLabel: String get() = if (numbering == Numbering.Sdah) "SDA Hymnal" else language

    companion object {
        /** The Seventh-day Adventist Hymnal (1985): a book of its own, numbered 1–695. */
        const val SDAH_ID = "sdah"
        const val DEFAULT_ID = "english"
        /** iOS's fallback when hymnals.json can't be read. */
        val fallback = HymnalInfo(DEFAULT_ID, "Christ In Song", "English", 300, 300)

        /** The catalogue the iOS app ships (Resources/Hymnals/hymnals.json), in its order. */
        fun catalogue(assets: AssetSource): List<HymnalInfo> = runCatching {
            assets.readJson("hymnals.json").jsonArray()!!.map { entry ->
                val o = entry.jsonObject()!!
                HymnalInfo(o["key"].jsonString()!!, o["title"].jsonString()!!, o["language"].jsonString()!!,
                    o["count"].jsonInt()!!, o["maxNumber"].jsonInt()!!)
            }
        }.getOrNull()?.takeIf { it.isNotEmpty() } ?: listOf(fallback)

        fun catalogue(assets: AssetManager): List<HymnalInfo> = catalogue(AndroidAssets(assets))

        /** English (Christ In Song), else the first hymnal. */
        fun default(catalogue: List<HymnalInfo>): HymnalInfo =
            catalogue.firstOrNull { it.id == DEFAULT_ID } ?: catalogue.firstOrNull() ?: fallback

        fun with(id: String?, catalogue: List<HymnalInfo>): HymnalInfo? = catalogue.firstOrNull { it.id == id }
    }
}

sealed interface Block {
    val lines: List<String>

    data class Verse(val number: Int, override val lines: List<String>) : Block
    data class Chorus(override val lines: List<String>) : Block
}

/** One hymn as the reader shows it (Hymn on iOS). */
data class Hymn(
    /** The hymn number within its hymnal. */
    val number: Int,
    val title: String,
    /** Cross-references for the eyebrow row, e.g. ["AH 350", "SDAH 368"]. */
    val references: List<String>,
    /** Verses in order, each distinct chorus stored once where it first appears. */
    val blocks: List<Block>,
    /** The MIDI accompaniment's asset name (with ".mid"), when one ships. */
    val midiAsset: String?,
) {
    /** iOS's `id`: the number. */
    val id: Int get() = number
    val hasAccompaniment: Boolean get() = midiAsset != null
    val verseCount: Int get() = blocks.count { it is Block.Verse }

    /** The order a congregation sings it: a single chorus follows every verse. */
    val sungSequence: List<Block>
        get() {
            val choruses = blocks.filterIsInstance<Block.Chorus>()
            if (choruses.size != 1) return blocks
            val chorus = choruses.first()
            val result = mutableListOf<Block>()
            if (blocks.firstOrNull() is Block.Chorus) result += chorus
            for (block in blocks) if (block is Block.Verse) { result += block; result += chorus }
            return result
        }

    /** Plain text for sharing and correction emails. */
    fun plainText(chorusLabel: String): String = blocks.joinToString("\n\n") { block ->
        when (block) {
            is Block.Verse -> "${block.number}.\n" + block.lines.joinToString("\n")
            is Block.Chorus -> "$chorusLabel:\n" + block.lines.joinToString("\n")
        }
    }

    companion object {
        /** iOS's stand-in when a hymnal has no hymns at all. */
        val placeholder = Hymn(0, "Advent Praise", emptyList(), emptyList(), null)
    }
}

data class SearchHit(val hymn: Hymn, val snippet: String)

/** A loaded hymnal: the iOS app's Hymnal, same search rules. */
class Hymnal(val info: HymnalInfo, val chorusLabel: String, val hymns: List<Hymn>) {
    private val index: Map<Int, Int> = buildMap<Int, Int> { hymns.forEachIndexed { i, h -> putIfAbsent(h.number, i) } }
    private val foldedTitles: List<String> by lazy { hymns.map { fold(it.title) } }
    private val foldedLines: List<List<String>> by lazy { hymns.map { h -> h.blocks.flatMap { it.lines }.map(::fold) } }

    val id: String get() = info.id
    val name: String get() = info.name
    val count: Int get() = hymns.size

    fun hymn(number: Int): Hymn? = index[number]?.let { hymns[it] }

    /** The hymn `offset` places after `number` in hymnal order; the first hymn when `number` isn't here. */
    fun hymnAfter(number: Int, offset: Int = 1): Hymn? {
        val i = index[number] ?: return hymns.firstOrNull()
        return hymns.getOrNull(i + offset)
    }

    /**
     * Accent-, case- and apostrophe-insensitive word search. Every word must
     * appear; title matches rank above lyric matches. A bare number jumps to
     * that hymn first.
     */
    fun search(query: String, inLyrics: Boolean): List<SearchHit> {
        val trimmed = query.trim()
        val words = fold(trimmed).split(' ').filter { it.isNotEmpty() }
        if (words.isEmpty()) return emptyList()
        val number = trimmed.toIntOrNull()
        val titleHits = mutableListOf<SearchHit>()
        val lyricHits = mutableListOf<SearchHit>()
        number?.let(::hymn)?.let { titleHits += SearchHit(it, it.title) }
        hymns.forEachIndexed { i, hymn ->
            if (hymn.number == number) return@forEachIndexed
            if (words.all { foldedTitles[i].contains(it) }) {
                titleHits += SearchHit(hymn, hymn.title)
            } else if (inLyrics) {
                val lines = foldedLines[i]
                if (!words.all { w -> lines.any { it.contains(w) } }) return@forEachIndexed
                val phrase = words.joinToString(" ")
                val best = lines.indexOfFirst { it.contains(phrase) }.takeIf { it >= 0 }
                    ?: lines.indexOfFirst { it.contains(words[0]) }.takeIf { it >= 0 } ?: 0
                val original = hymn.blocks.flatMap { it.lines }
                lyricHits += SearchHit(hymn, original.getOrNull(best) ?: hymn.title)
            }
        }
        return titleHits + lyricHits
    }

    companion object {
        private val refOrder = listOf("vern", "cs", "ah", "ch", "sdah", "cis")
        private val nonWord = Regex("[^\\p{L}\\p{N}']+")
        private val marks = Regex("\\p{M}+")

        fun fold(s: String): String {
            val decomposed = Normalizer.normalize(s.lowercase(Locale.ROOT), Normalizer.Form.NFKD)
            return decomposed.replace(marks, "")
                .replace('’', '\'')
                .replace('‘', '\'')
                .split(nonWord)
                .filter { it.isNotEmpty() }
                .joinToString(" ")
        }

        /** An empty stand-in, only used if a bundled file is missing or corrupt. */
        fun empty(info: HymnalInfo) = Hymnal(info, "Chorus", emptyList())

        /**
         * Decodes `<key>.json`, the file the iOS app reads. Accompaniment comes
         * from `midi` (an SDA Hymnal hymn sounds its Christ In Song version's
         * file only when it is the same tune). Off the main thread: the
         * largest hymnals take a moment.
         */
        fun load(assets: AssetSource, info: HymnalInfo, midi: MidiCatalog? = null): Hymnal? = runCatching {
            val file = assets.readJson("${info.id}.json").jsonObject()!!
            val hymns = file["hymns"].jsonArray()!!.map { entry ->
                val record = entry.jsonObject()!!
                val number = record["number"].jsonInt()!!
                Hymn(
                    number = number,
                    title = record["title"].jsonString()!!,
                    references = references(record["refs"].jsonObject(), number),
                    blocks = record["blocks"].jsonArray()!!.map(::block),
                    midiAsset = midi?.asset(info.id, number),
                )
            }
            Hymnal(info, file["refrain"].jsonString() ?: "Chorus", hymns)
        }.getOrNull()

        /** The first milestone's signature, kept for the reader. */
        fun load(assets: AssetManager, info: HymnalInfo, midi: MidiCatalog, tunes: SdahTunes? = null): Hymnal? =
            load(AndroidAssets(assets), info, if (tunes != null) midi.withTunes(tunes) else midi)

        private fun references(refs: Map<String, Any?>?, number: Int): List<String> {
            if (refs == null) return emptyList()
            return refs.entries.mapNotNull { (k, v) -> v.jsonInt()?.let { k to it } }
                .filterNot { (key, value) -> key == "vern" && value == number }
                .sortedWith(compareBy({ refOrder.indexOf(it.first).let { i -> if (i < 0) 99 else i } }, { it.first }))
                .map { (key, value) -> "${if (key == "vern") "Vern" else key.uppercase(Locale.ROOT)} $value" }
        }

        private fun block(entry: Any?): Block {
            val o = entry.jsonObject()!!
            val lines = o["l"].jsonArray()!!.map { it.jsonString().orEmpty() }
            return if (o["t"].jsonString() == "c") Block.Chorus(lines) else Block.Verse(o["n"].jsonInt() ?: 1, lines)
        }
    }
}
