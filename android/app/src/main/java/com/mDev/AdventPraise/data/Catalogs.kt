package com.mDev.AdventPraise.data

import android.content.res.AssetManager
import com.mDev.AdventPraise.extras.HymnCollections
import com.mDev.AdventPraise.extras.HymnStories
import com.mDev.AdventPraise.extras.ScriptureLinks

/**
 * Every bundled catalogue, read once and lazily (iOS keeps these as
 * statics): the hymnals, accompaniment, sheet music, SDA Hymnal tunes,
 * collections, stories and scripture links. AppServices holds one.
 * Reads happen on first use, so touch them off the main thread.
 */
class Catalogs(val assets: AssetSource) {
    constructor(assets: AssetManager) : this(AndroidAssets(assets))

    val hymnals: List<HymnalInfo> by lazy { HymnalInfo.catalogue(assets) }
    val defaultHymnal: HymnalInfo get() = HymnalInfo.default(hymnals)
    val sdah: HymnalInfo? get() = HymnalInfo.with(HymnalInfo.SDAH_ID, hymnals)

    val tunes: SdahTunes by lazy { SdahTunes(assets) }
    val midi: MidiCatalog by lazy { MidiCatalog(assets, tunes) }
    val sheetMusic: SheetMusicCatalog by lazy { SheetMusicCatalog(assets, tunes) }
    val collections: HymnCollections by lazy { HymnCollections(assets) }
    val stories: HymnStories by lazy { HymnStories(assets, tunes) }
    val scripture: ScriptureLinks by lazy { ScriptureLinks(assets) }

    fun hymnal(id: String?): HymnalInfo? = HymnalInfo.with(id, hymnals)

    /** Decodes a hymnal with its accompaniment. */
    fun load(info: HymnalInfo): Hymnal? = Hymnal.load(assets, info, midi)

    /** Christ In Song ↔ SDA Hymnal, from the English hymns. */
    fun crossReference(english: Hymnal): CrossReference = CrossReference(english)

    /** The reader's sheet music button beside the globe shows only when this is true. */
    fun hasSheetMusic(hymnal: String, number: Int): Boolean = sheetMusic.has(hymnal, number)
}
