package com.mDev.AdventPraise.data

import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.settings.MemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Playlist mutations and following a playlist or queue (ReaderModel's playlist section on iOS). */
class PlaylistsTest {
    private fun hymn(n: Int) = Hymn(n, "Hymn $n", emptyList(), listOf(Block.Verse(1, listOf("line $n"))), null)
    /** Numbers 1…10 without 4. */
    private val hymnal = Hymnal(HymnalInfo("english", "Christ In Song", "English", 9, 10), "Chorus", (1..10).filter { it != 4 }.map(::hymn))

    @Test fun createRenameAddRemoveAndPersist() {
        val store = MemoryStore()
        val book = PlaylistBook(store)
        assertEquals("Playlist 1", book.nextName("english"))
        val created = book.create("english", "  ", firstHymn = 3)
        assertTrue(created.isFirstEver)
        assertEquals("Playlist 1", created.playlist.name)
        assertEquals(listOf(3), created.playlist.hymnNumbers)
        val id = created.playlist.id
        assertTrue(book.add("english", id, 5))
        assertFalse("a playlist holds each hymn once", book.add("english", id, 5))
        book.rename("english", id, " Sabbath ")
        book.rename("english", id, "   ")
        assertEquals("Sabbath", book.playlist("english", id)?.name)
        assertTrue(book.remove("english", id, 3))
        assertEquals(listOf(5), book.playlist("english", id)?.hymnNumbers)
        // Per hymnal.
        assertTrue(book.playlists("shona").isEmpty())
        assertFalse(book.create("english", "Second", 1).isFirstEver)
        // Saved as iOS saves it, and read back.
        val reread = PlaylistBook(store)
        assertEquals(book.byHymnal, reread.byHymnal)
        assertTrue(store.getString(PlaylistBook.KEY_PLAYLISTS)!!.contains("\"hymnNumbers\":[5]"))
        // Deleting the last playlist of a hymnal removes the hymnal's entry.
        book.playlists("english").forEach { book.delete("english", it.id) }
        assertTrue(book.byHymnal.isEmpty())
        assertFalse("the first playlist is only revealed once", book.create("english", "", 1).isFirstEver)
    }

    @Test fun namesSkipThoseInUse() {
        val book = PlaylistBook(MemoryStore())
        book.create("english", "Playlist 2", 1)
        assertEquals("Playlist 3", book.nextName("english"))
    }

    @Test fun reorderingAsSwiftUIMovesRows() {
        assertEquals(listOf(2, 3, 1, 4), PlaylistBook.moved(listOf(1, 2, 3, 4), setOf(0), 3))
        assertEquals(listOf(4, 1, 2, 3), PlaylistBook.moved(listOf(1, 2, 3, 4), setOf(3), 0))
        assertEquals(listOf(2, 1, 3, 4), PlaylistBook.moved(listOf(1, 2, 3, 4), setOf(1), 0))
        assertEquals(listOf(3, 1, 2, 4), PlaylistBook.moved(listOf(1, 2, 3, 4), setOf(2), 0))
        assertEquals(listOf(2, 1, 3, 4), PlaylistBook.moved(listOf(1, 2, 3, 4), setOf(0), 2))
        val book = PlaylistBook(MemoryStore())
        val id = book.create("english", "P", 1).playlist.id
        listOf(2, 3).forEach { book.add("english", id, it) }
        assertTrue(book.moveHymn("english", id, 3, -1))
        assertEquals(listOf(1, 3, 2), book.playlist("english", id)?.hymnNumbers)
        assertFalse(book.moveHymn("english", id, 1, -1))
        book.removeAt("english", id, setOf(0, 2))
        assertEquals(listOf(3), book.playlist("english", id)?.hymnNumbers)
    }

    @Test fun aPlaylistRunsInOrderSkippingHymnsTheHymnalLacks() {
        val book = PlaylistBook(MemoryStore())
        val id = book.create("english", "Sabbath", 2).playlist.id
        listOf(4, 7, 9).forEach { book.add("english", id, it) }   // 4 isn't in this hymnal
        val queue = HymnQueue(book)
        val list = book.playlist("english", id)!!
        assertTrue(queue.canPlay(list, hymnal))
        var hymn = queue.play(list, hymnal)!!
        assertEquals(2, hymn.number)
        assertEquals("Sabbath · 1 of 4", queue.progress(hymnal, hymn))
        assertEquals(7, queue.upcomingHymn(hymnal, hymn)?.number)
        hymn = queue.goToNext(hymnal, hymn)!!
        assertEquals(7, hymn.number)
        assertEquals("Sabbath · 3 of 4", queue.progress(hymnal, hymn))
        assertEquals(2, queue.precedingHymn(hymnal, hymn)?.number)
        val running = queue.runningQueue(hymnal, hymn)!!
        assertEquals(2, running.current)
        assertEquals(3, running.next)
        hymn = queue.advance(hymnal, hymn)!!
        assertEquals(9, hymn.number)
        // The end of the playlist: advance stops, Next carries on by number.
        assertNull(queue.advance(hymnal, hymn))
        assertNull(queue.activePlaylistId)
        assertEquals(10, queue.goToNext(hymnal, hymn)?.number)
    }

    @Test fun previousGoesBackThroughThePlaylistThenLeavesIt() {
        val book = PlaylistBook(MemoryStore())
        val id = book.create("english", "P", 5).playlist.id
        book.add("english", id, 2)
        val queue = HymnQueue(book)
        var hymn = queue.play(book.playlist("english", id)!!, hymnal, start = 1)!!
        assertEquals(2, hymn.number)
        hymn = queue.goToPrevious(hymnal, hymn)!!
        assertEquals(5, hymn.number)
        assertEquals(id, queue.activePlaylistId)
        hymn = queue.goToPrevious(hymnal, hymn)!!
        assertEquals(3, hymn.number)   // 4 is missing, so the hymnal's previous is 3
        assertNull(queue.activePlaylistId)
    }

    @Test fun editingARunningPlaylistFollowsTheOpenHymn() {
        val book = PlaylistBook(MemoryStore())
        val id = book.create("english", "P", 1).playlist.id
        listOf(2, 3, 5).forEach { book.add("english", id, it) }
        val queue = HymnQueue(book)
        var hymn = queue.play(book.playlist("english", id)!!, hymnal)!!
        hymn = queue.goToNext(hymnal, hymn)!!
        assertEquals(2, hymn.number)
        // 2 is removed while open: next carries on from where it was.
        book.remove("english", id, 2)
        assertNull(queue.progress(hymnal, hymn))
        assertEquals(3, queue.upcomingHymn(hymnal, hymn)?.number)
        assertEquals(1, queue.precedingHymn(hymnal, hymn)?.number)
        // Deleting it stops following.
        book.delete("english", id)
        queue.onDeleted(id)
        assertNull(queue.runningQueue(hymnal, hymn))
    }

    @Test fun aServicePlanQueueStopsAfterItsLastHymn() {
        val queue = HymnQueue(PlaylistBook(MemoryStore()))
        assertNull(queue.play(listOf(4, 40), "Plan", HymnSource.ServicePlan, hymnal))
        var hymn = queue.play(listOf(4, 6, 6, 8), "Sabbath morning", HymnSource.ServicePlan, hymnal)!!
        assertEquals(6, hymn.number)
        val running = queue.runningQueue(hymnal, hymn)!!
        assertEquals("Sabbath morning", running.name)
        assertEquals(1, running.current)
        assertEquals(2, running.next)
        assertEquals(2, running.index(6))   // the next time after the open hymn
        hymn = queue.goToNext(hymnal, hymn)!!
        assertEquals(6, hymn.number)
        hymn = queue.goToNext(hymnal, hymn)!!
        assertEquals(8, hymn.number)
        assertNull("a finished plan ends there", queue.goToNext(hymnal, hymn))
        assertFalse(queue.isRunning)
    }

    @Test fun jumpingInTheQueue() {
        val queue = HymnQueue(PlaylistBook(MemoryStore()))
        val first = queue.play(listOf(1, 2, 3), "Plan", HymnSource.ServicePlan, hymnal)!!
        val (target, source) = queue.jump(2, hymnal, first)!!
        assertEquals(3, target.number)
        assertEquals(HymnSource.ServicePlan, source)
        assertNull(queue.jump(9, hymnal, target))
        queue.stop()
        assertNull(queue.jump(0, hymnal, target))
        assertEquals(5, queue.nextHymn(hymnal, target)?.number)
    }
}
