// OWNER: cast
package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.audio.accompanimentPasses
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn

/** A hymn's words as the TV shows them: the hymn, its hymnal and what that hymnal calls the chorus. */
data class CastWords(
    val hymn: Hymn,
    val hymnalId: String,
    val hymnalName: String,
    val chorusLabel: String,
) {
    /** The receiver's `hymnKey` ("<hymnalKey>-<number>"). */
    val tvKey: String get() = "$hymnalId-${hymn.number}"
}

/** What the TV shows of the words: which page, Blank, and the theme. */
data class CastScreen(
    /** An index into the sung sequence, or -1 for the title card. */
    val pageIndex: Int,
    val blank: Boolean,
    val theme: CastTheme,
) {
    companion object {
        /** Church mode closed: the hymn about to be sung, its number large. */
        val TitleCard = CastScreen(-1, false, CastTheme())
    }
}

/** Builds `load` (PROTOCOL.md) from a hymn, as iOS's worship display lays it out. */
object CastLoads {
    /**
     * The sung sequence (iOS `Hymn.sungSequence`), each page labelled for the
     * footer: "Verse 2 of 4" for a verse, the hymnal's chorus label for a chorus.
     */
    fun pages(hymn: Hymn, chorusLabel: String): List<CastPage> {
        val verses = hymn.verseCount
        return hymn.sungSequence.map { block ->
            when (block) {
                is Block.Verse -> CastPage(CastPage.VERSE, "Verse ${block.number} of $verses", block.lines)
                is Block.Chorus -> CastPage(CastPage.CHORUS, chorusLabel, block.lines)
            }
        }
    }

    /**
     * `midi` is the hymn's own accompaniment file (for an SDA Hymnal hymn,
     * its Christ In Song tune's file, resolved by the catalogue from
     * sdah_tunes.json); `passes` is one per verse, as the phone's player plays it.
     */
    fun load(
        words: CastWords,
        screen: CastScreen,
        tempo: Float? = null,
        autoplay: Boolean = false,
        startMs: Long = 0,
    ): SenderMessage.Load {
        val hymn = words.hymn
        val pages = pages(hymn, words.chorusLabel)
        return SenderMessage.Load(
            hymnalKey = words.hymnalId,
            hymnalName = words.hymnalName,
            number = hymn.number,
            title = hymn.title,
            pages = pages,
            pageIndex = if (screen.pageIndex < 0) -1 else screen.pageIndex.coerceAtMost(maxOf(pages.size - 1, 0)),
            blank = screen.blank,
            theme = screen.theme,
            midi = hymn.midiAsset,
            passes = hymn.accompanimentPasses.size,
            tempo = tempo,
            autoplay = autoplay && hymn.midiAsset != null,
            startMs = startMs.coerceAtLeast(0),
        )
    }
}
