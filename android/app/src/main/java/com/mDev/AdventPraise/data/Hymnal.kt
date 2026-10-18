package com.mDev.AdventPraise.data

import android.content.res.AssetManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import java.util.Locale

/**
 * How a hymnal numbers its hymns. Christ In Song and its translations share
 * one numbering; the SDA Hymnal (1985) has its own, matched to Christ In Song
 * only by cross-reference (HymnalCrossReference.swift on iOS).
 */
enum class Numbering(val key: String) { ChristInSong("cis"), Sdah("sdah") }

/** One hymnal of hymnals.json: the file key, its own title and its language. */
data class HymnalInfo(
    val id: String,
    val name: String,
    val language: String,
    val hymnCount: Int,
    val maxNumber: Int,
) {
    val numbering: Numbering get() = if (id == SDAH_ID) Numbering.Sdah else Numbering.ChristInSong
    /** What the globe tab says: the language, or "SDA Hymnal". */
    val shortLabel: String get() = if (numbering == Numbering.Sdah) "SDA Hymnal" else language

    companion object {
        const val SDAH_ID = "sdah"
        val fallback = HymnalInfo("english", "Christ In Song", "English", 300, 300)

        /** The catalogue the iOS app ships (Resources/Hymnals/hymnals.json). */
        fun catalogue(assets: AssetManager): List<HymnalInfo> = runCatching {
            val array = JSONArray(assets.open("hymnals.json").bufferedReader().use { it.readText() })
            (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                HymnalInfo(o.getString("key"), o.getString("title"), o.getString("language"),
                    o.getInt("count"), o.getInt("maxNumber"))
            }
        }.getOrNull()?.takeIf { it.isNotEmpty() } ?: listOf(fallback)
    }
}

sealed interface Block {
    val lines: List<String>

    data class Verse(val number: Int, override val lines: List<String>) : Block
    data class Chorus(override val lines: List<String>) : Block
}

data class Hymn(
    val number: Int,
    val title: String,
    /** Cross-references for the eyebrow row, e.g. ["AH 350", "SDAH 368"]. */
    val references: List<String>,
    /** Verses in order, each distinct chorus stored once where it first appears. */
    val blocks: List<Block>,
    /** The MIDI accompaniment's asset name, when one ships. */
    val midiAsset: String?,
) {
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
}

data class SearchHit(val hymn: Hymn, val snippet: String)

/** A loaded hymnal: the iOS app's Hymnal, same search rules. */
class Hymnal(val info: HymnalInfo, val chorusLabel: String, val hymns: List<Hymn>) {
    private val index: Map<Int, Int> = buildMap<Int, Int> { hymns.forEachIndexed { i, h -> putIfAbsent(h.number, i) } }
    private val foldedTitles: List<String> = hymns.map { fold(it.title) }
    private val foldedLines: List<List<String>> = hymns.map { h -> h.blocks.flatMap { it.lines }.map(::fold) }

    val id: String get() = info.id
    val name: String get() = info.name

    fun hymn(number: Int): Hymn? = index[number]?.let { hymns[it] }

    /** The hymn `offset` places after `number` in hymnal order. */
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

        /** Decodes `<key>.json`, the file the iOS app reads. */
        fun load(assets: AssetManager, info: HymnalInfo, midi: MidiCatalog, tunes: SdahTunes? = null): Hymnal? = runCatching {
            val file = JSONObject(assets.open("${info.id}.json").bufferedReader().use { it.readText() })
            val records = file.getJSONArray("hymns")
            val hymns = (0 until records.length()).map { i ->
                val record = records.getJSONObject(i)
                val number = record.getInt("number")
                Hymn(
                    number = number,
                    title = record.getString("title"),
                    references = references(record.optJSONObject("refs"), number),
                    blocks = blocks(record.getJSONArray("blocks")),
                    // An SDA Hymnal hymn sounds its Christ In Song version's
                    // accompaniment only when it is the same tune.
                    midiAsset = if (info.numbering == Numbering.Sdah) {
                        tunes?.cisTune(number)?.let { midi.asset(HymnalInfo.fallback.id, it) }
                    } else {
                        midi.asset(info.id, number)
                    },
                )
            }
            Hymnal(info, file.optString("refrain", "Chorus"), hymns)
        }.getOrNull()

        private fun references(refs: JSONObject?, number: Int): List<String> {
            if (refs == null) return emptyList()
            return refs.keys().asSequence()
                .map { it to refs.getInt(it) }
                .filterNot { (key, value) -> key == "vern" && value == number }
                .sortedWith(compareBy({ refOrder.indexOf(it.first).let { i -> if (i < 0) 99 else i } }, { it.first }))
                .map { (key, value) -> "${if (key == "vern") "Vern" else key.uppercase(Locale.ROOT)} $value" }
                .toList()
        }

        private fun blocks(array: JSONArray): List<Block> = (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            val linesJson = o.getJSONArray("l")
            val lines = (0 until linesJson.length()).map { linesJson.getString(it) }
            if (o.optString("t") == "c") Block.Chorus(lines) else Block.Verse(o.optInt("n", 1), lines)
        }
    }
}

/**
 * The same hymn in Christ In Song's numbering and in the SDA Hymnal's: the
 * English hymns' checked "SDAH n" references, as on iOS. Numbers alone never
 * match across the two numberings.
 */
class CrossReference(english: Hymnal) {
    /** Christ In Song number → SDA Hymnal number (the first English hymn naming it). */
    private val sdahForCis: Map<Int, Int> = buildMap<Int, Int> {
        for (hymn in english.hymns) {
            hymn.references.firstNotNullOfOrNull { ref ->
                if (ref.startsWith("SDAH ")) ref.removePrefix("SDAH ").toIntOrNull() else null
            }?.let { put(hymn.number, it) }
        }
    }
    private val cisForSdah: Map<Int, Int> = buildMap<Int, Int> {
        for ((cis, sdah) in sdahForCis.entries.sortedBy { it.key }) if (!containsKey(sdah)) put(sdah, cis)
    }

    /** Hymn `number` of `from` as numbered in `to`; null when `to` doesn't have it. */
    fun number(number: Int, from: HymnalInfo, to: HymnalInfo): Int? {
        val mapped = when {
            from.numbering == to.numbering -> number
            to.numbering == Numbering.Sdah -> sdahForCis[number]
            else -> cisForSdah[number]
        }
        return mapped?.takeIf { it <= to.maxNumber }
    }
}

/**
 * Resources/Extras/sdah_tunes.json, shared with iOS: the Christ In Song hymn
 * sung to the same tune as an SDA Hymnal hymn.
 */
class SdahTunes(assets: AssetManager) {
    private val tune: Map<Int, Int> = runCatching {
        val o = JSONObject(assets.open("sdah_tunes.json").bufferedReader().use { it.readText() }).getJSONObject("tune")
        o.keys().asSequence().mapNotNull { k -> k.toIntOrNull()?.let { it to o.getInt(k) } }.toMap()
    }.getOrDefault(emptyMap())

    fun cisTune(number: Int): Int? = tune[number]
}

/**
 * Which hymns have accompaniment: Resources/Midi/midi-manifest.json, the
 * same manifest the iOS app reads. A listed number only counts if its file
 * is in the assets.
 */
class MidiCatalog(assets: AssetManager) {
    private val files: Map<String, Map<Int, String>> = runCatching {
        val bundled = assets.list("")?.filter { it.endsWith(".mid") }?.toSet().orEmpty()
        val hymnals = JSONObject(assets.open("midi-manifest.json").bufferedReader().use { it.readText() })
            .getJSONObject("hymnals")
        hymnals.keys().asSequence().associateWith { key ->
            val entry = hymnals.getJSONObject(key)
            val pattern = entry.getString("file")
            val numbers = entry.getJSONArray("hymns")
            buildMap<Int, String> {
                for (i in 0 until numbers.length()) {
                    val n = numbers.getInt(i)
                    val name = String.format(Locale.ROOT, pattern, n) + ".mid"
                    if (name in bundled) put(n, name)
                }
            }
        }
    }.getOrDefault(emptyMap())

    fun asset(hymnal: String, number: Int): String? = files[hymnal]?.get(number)
}
