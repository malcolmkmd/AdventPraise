package com.mDev.AdventPraise.data

import android.content.res.AssetManager
import java.util.Locale

/**
 * The same hymn in Christ In Song (and the hymnals numbered like it) and in
 * the SDA Hymnal (1985): the English hymns' checked "SDAH n" references, as
 * on iOS (HymnalCrossReference.swift). Numbers alone never match across the
 * two numberings.
 */
class CrossReference(english: Hymnal) {
    /** Christ In Song number → SDA Hymnal number (the first English hymn naming it). */
    val sdahForCis: Map<Int, Int> = buildMap<Int, Int> {
        for (hymn in english.hymns) {
            hymn.references.firstNotNullOfOrNull { ref ->
                if (ref.startsWith("SDAH ")) ref.removePrefix("SDAH ").toIntOrNull() else null
            }?.let { put(hymn.number, it) }
        }
    }

    /** SDA Hymnal number → Christ In Song number. */
    val cisForSdah: Map<Int, Int> = buildMap<Int, Int> {
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
 * Resources/Extras/sdah_tunes.json, shared with iOS (SDAHTunes): the
 * Christ In Song hymn sung to the same tune as an SDA Hymnal hymn, so it can
 * use that version's accompaniment, and, where tune and setting are public
 * domain (`sheet`), its sheet music.
 */
class SdahTunes(assets: AssetSource) {
    constructor(assets: AssetManager) : this(AndroidAssets(assets))

    private val tune: Map<Int, Int>
    private val sheet: Set<Int>

    init {
        val file = assets.readJson("sdah_tunes.json").jsonObject()
        tune = file?.get("tune").jsonObject().orEmpty().mapNotNull { (k, v) ->
            val key = k.toIntOrNull() ?: return@mapNotNull null
            v.jsonInt()?.let { key to it }
        }.toMap()
        sheet = file?.get("sheet").jsonArray().orEmpty().mapNotNull { it.jsonInt() }.toSet()
    }

    /** The Christ In Song hymn sung to the same tune as SDA Hymnal `number`. */
    fun cisTune(number: Int): Int? = tune[number]

    /** The Christ In Song score to show for SDA Hymnal `number`: same tune, public domain setting. */
    fun cisScore(number: Int): Int? = if (number in sheet) cisTune(number) else null
}

/**
 * Which hymns have accompaniment: Resources/Midi/midi-manifest.json, the
 * same manifest the iOS app reads (MIDICatalog). A listed number only
 * counts if its file is in the assets. An SDA Hymnal hymn plays its Christ
 * In Song version's file when the two are sung to the same tune.
 */
class MidiCatalog private constructor(
    private val files: Map<String, Map<Int, String>>,
    private val tunes: SdahTunes?,
) {
    constructor(assets: AssetSource, tunes: SdahTunes? = null) : this(load(assets), tunes)
    constructor(assets: AssetManager) : this(AndroidAssets(assets))

    /** The same catalogue, sounding SDA Hymnal hymns through `tunes`. */
    fun withTunes(tunes: SdahTunes) = MidiCatalog(files, tunes)

    /** The asset name (with ".mid") for hymn `number` in `hymnal`, if one ships. */
    fun asset(hymnal: String, number: Int): String? {
        if (hymnal == HymnalInfo.SDAH_ID) {
            return tunes?.cisTune(number)?.let { files[HymnalInfo.DEFAULT_ID]?.get(it) }
        }
        return files[hymnal]?.get(number)
    }

    companion object {
        private fun load(assets: AssetSource): Map<String, Map<Int, String>> = runCatching {
            val bundled = assets.list().filter { it.endsWith(".mid") }.toSet()
            val hymnals = assets.readJson("midi-manifest.json").jsonObject()!!["hymnals"].jsonObject()!!
            hymnals.mapValues { (_, value) ->
                val entry = value.jsonObject()!!
                val pattern = entry["file"].jsonString()!!
                buildMap<Int, String> {
                    for (n in entry["hymns"].jsonArray().orEmpty().mapNotNull { it.jsonInt() }) {
                        val name = String.format(Locale.ROOT, pattern, n) + ".mid"
                        if (name in bundled && !containsKey(n)) put(n, name)
                    }
                }
            }
        }.getOrDefault(emptyMap())
    }
}
