package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.data.AssetSource
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.data.jsonArray
import com.mDev.AdventPraise.data.jsonInt
import com.mDev.AdventPraise.data.jsonObject
import com.mDev.AdventPraise.data.jsonString

/** The Tools sheets and the screens like them (ExtraSheet on iOS); `key` is what `tool_opened` sends. */
enum class ExtraSheet(val key: String) {
    About("about"), Scripture("scripture"), Collections("collections"), Pitch("pitch"), Memory("memory"), Planner("planner"),
    /** The open hymn's sheet music. */
    SheetMusic("sheetMusic"),
    /** The tips, from More → Support. */
    Support("support"),
    /** About Advent Praise, the Privacy Policy and the Terms of Use, from More → About. */
    AboutApp("aboutApp"), Privacy("privacy"), Terms("terms"),
}

/** How much of a hymn's sheet music shows (SheetMusicAccess on iOS). */
enum class SheetMusicAccess(val key: String) {
    Pro("pro"),
    /** Free for everyone: today's Hymn of the Day. */
    HymnOfTheDay("hymn_of_the_day"),
    /** Not Pro: the top of the page and a way to Pro. */
    Preview("preview");

    val showsWholePage: Boolean get() = this != Preview

    companion object {
        /** A preview shows this much of the page, at most. */
        const val PREVIEW_FRACTION = 0.45

        fun resolve(isPro: Boolean, isHymnOfTheDay: Boolean): SheetMusicAccess = when {
            isPro -> Pro
            isHymnOfTheDay -> HymnOfTheDay
            else -> Preview
        }
    }
}

/**
 * One `{ version, hymnals: { "<hymnal key>": { "<hymn number>": … } } }`
 * file from Resources/Extras (PerHymnFile on iOS), keyed by hymnal then
 * hymn number. A missing or malformed file reads as empty.
 */
class PerHymnFile<T>(private val hymnals: Map<String, Map<Int, T>>) {
    fun entry(hymnal: String, number: Int): T? = hymnals[hymnal]?.get(number)

    /** Every entry for one hymnal, by hymn number. */
    fun entries(hymnal: String): List<Pair<Int, T>> = hymnals[hymnal].orEmpty().entries.sortedBy { it.key }.map { it.key to it.value }

    companion object {
        fun <T> empty() = PerHymnFile<T>(emptyMap())

        fun <T> load(assets: AssetSource, name: String, decode: (Any?) -> T?): PerHymnFile<T> {
            val root = assets.readJson(name).jsonObject() ?: return empty()
            val hymnals = root["hymnals"].jsonObject().orEmpty().mapValues { (_, byNumber) ->
                byNumber.jsonObject().orEmpty().mapNotNull { (k, v) ->
                    val n = k.toIntOrNull() ?: return@mapNotNull null
                    decode(v)?.let { n to it }
                }.toMap()
            }
            return PerHymnFile(hymnals)
        }
    }
}

/**
 * A topical section of the SDA Hymnal (1985): Worship, Jesus Christ,
 * Gospel… (HymnCollection on iOS). Christ In Song and its translations are
 * placed by each hymn's SDA Hymnal cross-reference; the SDA Hymnal has
 * every hymn in its section's range.
 */
data class HymnCollection(
    val id: String,
    val title: String,
    /** SF Symbol name on iOS; the UI maps it to a Material symbol. */
    val symbol: String,
    /** Position in the SDA Hymnal. */
    val order: Int,
    /** First and last SDA Hymnal number in the section. */
    val sdah: List<Int>,
    /** Hymn numbers by hymnal key, ascending. */
    val hymns: Map<String, List<Int>>,
) {
    /** The SDA Hymnal's own hymns are its whole section, in order. */
    fun numbers(hymnal: String): List<Int> {
        if (hymnal == HymnalInfo.SDAH_ID && sdah.size == 2 && sdah[0] <= sdah[1]) return (sdah[0]..sdah[1]).toList()
        return hymns[hymnal].orEmpty()
    }

    /** "1–69" */
    val sdahRange: String get() = if (sdah.size == 2) "${sdah[0]}–${sdah[1]}" else ""
}

/** Resources/Extras/hymn_collections.json (HymnCollections on iOS). */
class HymnCollections(assets: AssetSource) {
    val all: List<HymnCollection> = runCatching {
        assets.readJson("hymn_collections.json").jsonObject()!!["collections"].jsonArray()!!.mapNotNull { raw ->
            val o = raw.jsonObject() ?: return@mapNotNull null
            HymnCollection(
                id = o["id"].jsonString() ?: return@mapNotNull null,
                title = o["title"].jsonString().orEmpty(),
                symbol = o["symbol"].jsonString().orEmpty(),
                order = o["order"].jsonInt() ?: 0,
                sdah = o["sdah"].jsonArray().orEmpty().mapNotNull { it.jsonInt() },
                hymns = o["hymns"].jsonObject().orEmpty().mapValues { (_, v) -> v.jsonArray().orEmpty().mapNotNull { it.jsonInt() } },
            )
        }
    }.getOrDefault(emptyList()).sortedBy { it.order }

    /** The collections with hymns in `hymnal`, in hymnal order. */
    fun available(hymnal: String): List<HymnCollection> = all.filter { it.numbers(hymnal).isNotEmpty() }

    /** Collections that include hymn `number` in `hymnal`. */
    fun containing(number: Int, hymnal: String): List<HymnCollection> = all.filter { number in it.numbers(hymnal) }
}

/** A short, sourced note on who wrote a hymn and where it came from. Every field is optional. */
data class HymnStory(
    /** Author of the words (and translator, if any). */
    val words: String? = null,
    /** Composer or tune name. */
    val music: String? = null,
    val year: String? = null,
    /** A few sentences on how the hymn came to be. */
    val story: String? = null,
    /** Where the facts above come from. */
    val sources: List<String> = emptyList(),
) {
    val isEmpty: Boolean get() = listOf(words, music, year, story).all { it.isNullOrEmpty() } && sources.isEmpty()
}

/** Resources/Extras/hymn_stories.json (HymnStories on iOS). */
class HymnStories(assets: AssetSource, private val tunes: SdahTunes?) {
    private val file = PerHymnFile.load(assets, "hymn_stories.json") { raw ->
        val o = raw.jsonObject() ?: return@load null
        HymnStory(o["words"].jsonString(), o["music"].jsonString(), o["year"].jsonString(), o["story"].jsonString(),
            o["sources"].jsonArray().orEmpty().mapNotNull { it.jsonString() })
    }

    fun story(hymnal: String, number: Int): HymnStory? {
        file.entry(hymnal, number)?.takeIf { !it.isEmpty }?.let { return it }
        // An SDA Hymnal hymn sung to its Christ In Song version's tune shares that version's note.
        if (hymnal == HymnalInfo.SDAH_ID) tunes?.cisTune(number)?.let { return story(HymnalInfo.DEFAULT_ID, it) }
        return null
    }
}
