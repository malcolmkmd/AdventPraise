package com.mDev.AdventPraise

import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The search rules are iOS's (Hymnal.search): accents, case and apostrophes don't matter. */
class HymnalSearchTest {
    private fun hymn(n: Int, title: String, vararg lines: String) =
        Hymn(n, title, emptyList(), listOf(Block.Verse(1, lines.toList())), null)

    private val hymnal = Hymnal(
        HymnalInfo("english", "Christ In Song", "English", 4, 4),
        "Chorus",
        listOf(
            hymn(1, "Watchman Blow The Gospel Trumpet", "Every soul a warning give;"),
            hymn(2, "Blessed Assurance", "O what a foretaste of glory divine!"),
            hymn(3, "Ev’ry Hour", "I need Thee every hour, most gracious Lord;"),
            hymn(4, "Every Day", "Day by day"),
        ),
    )

    @Test fun foldIgnoresCaseAccentsAndCurlyApostrophes() {
        assertEquals("ev'ry hour", Hymnal.fold("Ev’ry Hour"))
        assertEquals("cafe creme", Hymnal.fold("Café  Crème!"))
    }

    @Test fun titlesRankAboveLyrics() {
        val hits = hymnal.search("every", inLyrics = true).map { it.hymn.number }
        assertEquals(listOf(4, 1, 3), hits)
    }

    @Test fun aBareNumberComesFirst() {
        assertEquals(2, hymnal.search("2", inLyrics = true).first().hymn.number)
    }

    @Test fun titlesOnlySkipsLyrics() {
        assertTrue(hymnal.search("glory", inLyrics = false).isEmpty())
        assertEquals("O what a foretaste of glory divine!", hymnal.search("glory", inLyrics = true).single().snippet)
    }

    @Test fun aSingleChorusFollowsEveryVerse() {
        val h = Hymn(9, "T", emptyList(), listOf(Block.Verse(1, listOf("a")), Block.Chorus(listOf("c")), Block.Verse(2, listOf("b"))), null)
        assertEquals(listOf("a", "c", "b", "c"), h.sungSequence.map { it.lines.first() })
    }
}
