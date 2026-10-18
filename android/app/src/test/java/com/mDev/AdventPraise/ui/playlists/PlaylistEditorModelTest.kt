package com.mDev.AdventPraise.ui.playlists

import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.ui.design.HapticEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The playlist editor's mutations and their haptics (PlaylistEditorView / ReaderModel's playlist section). */
class PlaylistEditorModelTest {
    private val book = PlaylistBook(MemoryStore())
    private val queue = HymnQueue(book)
    private val haptics = mutableListOf<HapticEvent>()
    private val hymnal = Hymnal(HymnalInfo("english", "Christ In Song", "English", 5, 5), "Chorus",
        (1..5).map { Hymn(it, "Hymn $it", emptyList(), listOf(Block.Verse(1, listOf("line"))), null) })

    private fun editor(numbers: List<Int>): PlaylistEditorModel {
        val id = book.create("english", "Sabbath", numbers.first()).playlist.id
        numbers.drop(1).forEach { book.add("english", id, it) }
        return PlaylistEditorModel(book, queue, { "english" }, id) { haptics += it }
    }

    @Test fun aDragDownLandsWhereItWasDropped() {
        val e = editor(listOf(1, 2, 3, 4))
        e.move(from = 0, to = 2)
        assertEquals(listOf(2, 3, 1, 4), e.playlist!!.hymnNumbers)
        assertEquals(listOf(HapticEvent.Selection), haptics)
    }

    @Test fun aDragUpLandsWhereItWasDropped() {
        val e = editor(listOf(1, 2, 3, 4))
        e.move(from = 3, to = 0)
        assertEquals(listOf(4, 1, 2, 3), e.playlist!!.hymnNumbers)
        e.move(from = 1, to = 1)
        assertEquals("dropping where it started changes nothing", 1, haptics.size)
    }

    @Test fun moveUpAndDownStopAtTheEnds() {
        val e = editor(listOf(1, 2, 3))
        e.moveHymn(3, -1)
        assertEquals(listOf(1, 3, 2), e.playlist!!.hymnNumbers)
        e.moveHymn(1, -1)
        e.moveHymn(2, 1)
        assertEquals(listOf(1, 3, 2), e.playlist!!.hymnNumbers)
        assertEquals(listOf(HapticEvent.Selection), haptics)
    }

    @Test fun swipeRemovesAndThePickerToggles() {
        val e = editor(listOf(1, 2, 3))
        e.removeAt(1)
        assertEquals(listOf(1, 3), e.playlist!!.hymnNumbers)
        e.toggle(5)
        assertEquals(listOf(1, 3, 5), e.playlist!!.hymnNumbers)
        e.toggle(1)
        assertEquals(listOf(3, 5), e.playlist!!.hymnNumbers)
        assertEquals(listOf(HapticEvent.ToggleOff, HapticEvent.ToggleOn, HapticEvent.ToggleOff), haptics)
        assertEquals("2 hymns", e.countText)
    }

    @Test fun renameKeepsTheOldNameWhenBlank() {
        val e = editor(listOf(1))
        e.rename("   ")
        assertEquals("Sabbath", e.playlist!!.name)
        e.rename(" Vespers ")
        assertEquals("Vespers", e.playlist!!.name)
        assertEquals("1 hymn", e.countText)
    }

    @Test fun deleteStopsFollowingIt() {
        val e = editor(listOf(2, 3))
        assertEquals(2, e.play(hymnal)!!.number)
        assertEquals(e.playlistId, queue.activePlaylistId)
        e.delete()
        assertNull(e.playlist)
        assertNull(queue.activePlaylistId)
        assertEquals(HapticEvent.MediumImpact, haptics.last())
    }

    @Test fun playStartsAtTheTappedHymnSkippingOnesThisHymnalLacks() {
        val e = editor(listOf(9, 4, 5))
        assertTrue(e.canPlay(hymnal))
        assertEquals(4, e.play(hymnal)!!.number)
        assertEquals(5, e.play(hymnal, start = 2)!!.number)
        val missing = editor(listOf(8))
        assertFalse(missing.canPlay(hymnal))
        assertNull(missing.play(hymnal))
    }
}
