package com.mDev.AdventPraise.data

import java.io.ByteArrayOutputStream
import java.util.zip.Inflater

/**
 * Which page width to show (SheetMusicLayout on iOS). The scores are
 * engraved ahead of time into one vector page per hymn in three widths,
 * shipped as packs of raw DEFLATE pages (Resources/SheetMusic).
 */
enum class SheetMusicLayout(val key: String) {
    /** Narrow: a phone in portrait, or a tablet in a narrow split. */
    Phone("phone"),
    /** Wide: a tablet, a wide split, or a phone in landscape. */
    Pad("pad"),
    /** Shortest lines (two or three measures): system by system on a phone held upright. */
    Line("line");

    companion object {
        /** The pad pages once the music has this much width (dp, as iOS points). */
        const val PAD_WIDTH = 700.0
        /** Below this width, system by system uses the shortest lines. */
        const val LINE_WIDTH = 600.0

        /** The whole page. */
        fun forWidth(width: Double): SheetMusicLayout = if (width >= PAD_WIDTH) Pad else Phone

        /** System by system: the phone's lines when there's room, the shortest held upright. */
        fun forSystems(width: Double): SheetMusicLayout = if (width < LINE_WIDTH) Line else Phone

        fun of(key: String): SheetMusicLayout? = entries.firstOrNull { it.key == key }
    }
}

/** One engraved page: its SVG (drawn in `currentColor`) and its size in SVG units. */
data class SheetMusicPage(val svg: String, val width: Double, val height: Double)

/**
 * Which hymns have sheet music, and their pages and timing
 * (SheetMusicCatalog.swift). `sheet-music-manifest.json` gives each page's
 * place in its pack:
 *
 *     {"hymnal": "english", "packs": {"phone": "sheet-music-phone", ...},
 *      "hymns": {"100": {"phone": {"w": 798, "h": 1726, "o": 0, "n": 21033}, ..., "sync": {"o": 0, "n": 5660}}}}
 *
 * An SDA Hymnal hymn shows its Christ In Song version's score only when it's
 * the same tune and the setting is public domain ([SdahTunes.cisScore]).
 */
class SheetMusicCatalog(private val assets: AssetSource, private val tunes: SdahTunes?) {
    data class PageEntry(val w: Double, val h: Double, val o: Long, val n: Int)
    data class Chunk(val o: Long, val n: Int)
    data class Entry(val pages: Map<SheetMusicLayout, PageEntry>, val sync: Chunk?)

    private class Manifest(val hymnal: String, val packs: Map<String, String>, val hymns: Map<String, Entry>)

    private val manifest: Manifest? by lazy { loadManifest() }

    private fun loadManifest(): Manifest? = runCatching {
        val root = assets.readJson("sheet-music-manifest.json").jsonObject()!!
        val packs = root["packs"].jsonObject()!!.mapValues { it.value.jsonString()!! }
        val hymns = root["hymns"].jsonObject()!!.mapValues { (_, value) ->
            val o = value.jsonObject()!!
            val pages = SheetMusicLayout.entries.mapNotNull { layout ->
                val p = o[layout.key].jsonObject() ?: return@mapNotNull null
                layout to PageEntry(p["w"].jsonDouble()!!, p["h"].jsonDouble()!!,
                    (p["o"] as Number).toLong(), p["n"].jsonInt()!!)
            }.toMap()
            val sync = o["sync"].jsonObject()?.let { Chunk((it["o"] as Number).toLong(), it["n"].jsonInt()!!) }
            Entry(pages, sync)
        }
        Manifest(root["hymnal"].jsonString()!!, packs, hymns)
    }.getOrNull()

    /** The hymnal the scores belong to ("english"). */
    val hymnal: String? get() = manifest?.hymnal

    private fun entry(hymnal: String, number: Int): Entry? {
        val manifest = manifest ?: return null
        if (manifest.hymnal == hymnal) return manifest.hymns[number.toString()]
        if (hymnal != HymnalInfo.SDAH_ID || manifest.hymnal != HymnalInfo.DEFAULT_ID) return null
        val cis = tunes?.cisScore(number) ?: return null
        return manifest.hymns[cis.toString()]
    }

    /** Whether hymn `number` in `hymnal` has sheet music (the reader's button beside the globe). */
    fun has(hymnal: String, number: Int): Boolean = entry(hymnal, number) != null

    /** How many hymns have sheet music in `hymnal` (`maxNumber` bounds the SDA Hymnal's count). */
    fun count(hymnal: String, maxNumber: Int = 695): Int {
        val manifest = manifest ?: return 0
        if (manifest.hymnal == hymnal) return manifest.hymns.size
        if (hymnal != HymnalInfo.SDAH_ID) return 0
        return (1..maxOf(maxNumber, 1)).count { entry(hymnal, it) != null }
    }

    /** The page for hymn `number` in `layout`, read from its pack and inflated. Off the main thread. */
    fun page(hymnal: String, number: Int, layout: SheetMusicLayout): SheetMusicPage? {
        val manifest = manifest ?: return null
        val page = entry(hymnal, number)?.pages?.get(layout) ?: return null
        val pack = manifest.packs[layout.key] ?: return null
        val bytes = inflate("$pack.pack", page.o, page.n) ?: return null
        return SheetMusicPage(String(bytes, Charsets.UTF_8), page.w, page.h)
    }

    /** Hymn `number`'s timing against its MIDI file and its page geometry. Null if none ships. */
    fun timing(hymnal: String, number: Int): SheetMusicTiming? {
        val manifest = manifest ?: return null
        val chunk = entry(hymnal, number)?.sync ?: return null
        val pack = manifest.packs["sync"] ?: return null
        val bytes = inflate("$pack.pack", chunk.o, chunk.n) ?: return null
        return SheetMusicTiming.parse(String(bytes, Charsets.UTF_8))
    }

    private fun inflate(name: String, offset: Long, length: Int): ByteArray? {
        val compressed = assets.readRange(name, offset, length) ?: return null
        return inflateRaw(compressed)
    }

    companion object {
        /** Raw DEFLATE (no zlib header), as iOS's `decompressed(using: .zlib)` reads it. */
        fun inflateRaw(compressed: ByteArray): ByteArray? = runCatching {
            val inflater = Inflater(true)
            try {
                // A raw stream needs one extra byte to finish (java.util.zip's documented quirk).
                inflater.setInput(compressed + byteArrayOf(0))
                val out = ByteArrayOutputStream(compressed.size * 4)
                val buffer = ByteArray(64 * 1024)
                while (!inflater.finished()) {
                    val n = inflater.inflate(buffer)
                    if (n == 0 && (inflater.needsInput() || inflater.needsDictionary())) break
                    out.write(buffer, 0, n)
                }
                if (!inflater.finished()) null else out.toByteArray()
            } finally {
                inflater.end()
            }
        }.getOrNull()
    }
}
