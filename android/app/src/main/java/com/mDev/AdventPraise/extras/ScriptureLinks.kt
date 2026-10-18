package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.data.AssetSource
import com.mDev.AdventPraise.data.jsonArray
import com.mDev.AdventPraise.data.jsonString

/**
 * A Bible passage (Passage on iOS): "Book C", "Book C:V" or "Book C:V–W".
 * `from` null is the whole chapter; `to` null a single verse.
 */
data class Passage(val book: String, val chapter: Int, val from: Int? = null, val to: Int? = null) : Comparable<Passage> {
    val id: String get() = reference

    val reference: String
        get() {
            val from = from ?: return "$book $chapter"
            if (to == null || to == from) return "$book $chapter:$from"
            return "$book $chapter:$from–$to"
        }

    /**
     * The passage on bible.com in the King James Version. A universal link:
     * it opens the YouVersion Bible app when installed, otherwise the browser.
     */
    val bibleUrl: String?
        get() {
            val code = BibleBook.usfm(book) ?: return null
            var path = "$code.$chapter"
            from?.let { f -> path += ".$f" + (to?.let { t -> if (t != f) "-$t" else "" } ?: "") }
            return "https://www.bible.com/bible/1/$path"
        }

    /** Canonical order: book, chapter, then verse. */
    override fun compareTo(other: Passage): Int = compareValuesBy(this, other,
        { BibleBook.order(it.book) }, { it.chapter }, { it.from ?: 0 }, { it.to ?: 0 })

    /** True when the two share at least one verse (a whole chapter overlaps every passage in it). */
    fun overlaps(other: Passage): Boolean {
        if (book != other.book || chapter != other.chapter) return false
        val a = from ?: return true
        val b = other.from ?: return true
        return a <= (other.to ?: b) && b <= (to ?: a)
    }

    companion object {
        /** Parses "Book C", "Book C:V" or "Book C:V-W" (hyphen or en dash). Null when it isn't one. */
        fun parse(reference: String): Passage? {
            val space = reference.lastIndexOf(' ')
            if (space < 0) return null
            val book = reference.substring(0, space)
            if (BibleBook.usfm(book) == null) return null
            val parts = reference.substring(space + 1).split(':', '-', '–').filter { it.isNotEmpty() }
            val numbers = parts.map { it.toIntOrNull() }
            if (numbers.isEmpty() || numbers.size > 3 || numbers.any { (it ?: 0) <= 0 }) return null
            return Passage(book, numbers[0]!!, numbers.getOrNull(1), numbers.getOrNull(2))
        }
    }
}

/** Where a reference comes from. */
enum class ScriptureSource(val key: String, val label: String) {
    /** The hymn's own words quote or paraphrase the passage (checked against the KJV). */
    Lyric("lyric", "From the hymn’s words"),
    /** The scripture text printed with the hymn in Christ in Song (1908). */
    Hymnal("cis1908", "Printed in Christ in Song (1908)"),
    /** Hymnary.org's scripture index for the hymn. */
    Hymnary("hymnary", "Hymnary.org scripture index"),
}

enum class ScriptureConfidence(val key: String) {
    /** The hymn quotes the verse. */
    High("high"),
    /** The hymn clearly echoes the passage without quoting it. */
    Medium("medium"),
}

/** One cited passage with where it came from: a `[ref, source, confidence]` row. */
data class ScriptureLink(val passage: Passage, val source: ScriptureSource, val confidence: ScriptureConfidence) {
    val id: String get() = passage.id

    companion object {
        fun fromRow(raw: Any?): ScriptureLink? {
            val row = raw.jsonArray() ?: return null
            if (row.size < 3) return null
            val passage = row[0].jsonString()?.let(Passage::parse) ?: return null
            val source = ScriptureSource.entries.firstOrNull { it.key == row[1].jsonString() } ?: return null
            val confidence = ScriptureConfidence.entries.firstOrNull { it.key == row[2].jsonString() } ?: return null
            return ScriptureLink(passage, source, confidence)
        }
    }
}

object BibleBook {
    val names = listOf(
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
        "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah",
        "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
        "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
        "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    )

    /** USFM book codes, the IDs bible.com uses, in the same order as [names]. */
    private val codes = listOf(
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH",
        "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK",
        "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
        "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH",
        "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD",
        "REV",
    )

    private val index: Map<String, Int> = names.withIndex().associate { it.value to it.index }

    /** Position in the canon; unknown names sort after Revelation. */
    fun order(book: String): Int = index[book] ?: names.size

    fun usfm(book: String): String? = index[book]?.let { codes[it] }
}

/** One passage and the hymns (in one hymnal) that cite it. */
data class PassageHymns(val passage: Passage, val numbers: List<Int>) {
    val id: String get() = passage.id
}

/**
 * Resources/Extras/scripture_links.json (ScriptureLinks on iOS): the Bible
 * passages each hymn draws on, and the reverse index. A row that doesn't
 * parse is skipped (the file is checked when it's built).
 */
class ScriptureLinks(assets: AssetSource) {
    private val file = PerHymnFile.load(assets, "scripture_links.json") { raw ->
        raw.jsonArray()?.mapNotNull(ScriptureLink::fromRow)
    }

    fun links(hymnal: String, number: Int): List<ScriptureLink> =
        file.entry(hymnal, number).orEmpty().sortedBy { it.passage }

    /** Every cited passage in a hymnal, in canonical order, with its hymns. */
    fun index(hymnal: String): List<PassageHymns> {
        val byPassage = mutableMapOf<Passage, MutableList<Int>>()
        for ((number, links) in file.entries(hymnal)) {
            for (link in links) byPassage.getOrPut(link.passage) { mutableListOf() } += number
        }
        return byPassage.keys.sorted().map { PassageHymns(it, byPassage.getValue(it).sorted()) }
    }

    /** Hymns whose passages overlap `passage`, excluding `excluding`. */
    fun hymns(citing: Passage, hymnal: String, excluding: Int? = null): List<Int> =
        file.entries(hymnal).filter { (n, links) -> n != excluding && links.any { it.passage.overlaps(citing) } }.map { it.first }
}
