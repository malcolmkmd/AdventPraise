package com.mDev.AdventPraise.reader

import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.HymnalSource
import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReaderHistory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The reader's view model on the iOS app's own hymnals: swiping between hymns,
 * following a playlist or plan, recents, favourites, the number pad and
 * switching hymnal (keeping the hymn through the SDA Hymnal cross-reference).
 */
class ReaderModelTest {
    private val events = mutableListOf<AnalyticsEvent>()
    private lateinit var store: MemoryStore

    @Before fun setUp() {
        store = MemoryStore()
        Analytics.testSink = { events += it }
    }

    @After fun tearDown() {
        Analytics.testSink = null
    }

    private fun model(vararg saved: Pair<String, Any>): ReaderModel {
        saved.forEach { (k, v) -> store.values[k] = v }
        val book = PlaylistBook(store)
        // Unconfined: loading happens before start() returns.
        return ReaderModel(catalogs, ReaderHistory(store), HymnQueue(book), book,
            CoroutineScope(Dispatchers.Unconfined), Dispatchers.Unconfined).also { it.start() }
    }

    private fun opened(): List<Map<String, Any>> = events.filter { it.name == "hymn_opened" }.map { it.properties }

    @Test fun opensTheLastHymnReadInTheSavedHymnal() {
        val m = model(ReaderHistory.KEY_HYMNAL to "shona", ReaderHistory.KEY_LAST_HYMN to 42)
        assertEquals("shona", m.hymnal?.id)
        assertEquals(42, m.hymn?.number)
        val fresh = ReaderModelTest().apply { setUp() }.model()
        assertEquals("english", fresh.hymnal?.id)
        assertEquals(1, fresh.hymn?.number)
    }

    @Test fun swipeNeighboursAreTheNextAndPreviousNumbers() {
        val m = model()
        assertTrue(m.open(10, HymnSource.Numpad))
        assertEquals(11, m.upcomingHymn?.number)
        assertEquals(9, m.precedingHymn?.number)
        assertEquals(11, m.goToNext(HymnSource.Swipe)?.number)
        assertEquals("swipe", opened().last()["source"])
        assertEquals(10, m.goToPrevious(HymnSource.Swipe)?.number)
        // Either end of the hymnal: nothing further that way.
        m.open(1, HymnSource.Numpad)
        assertNull(m.precedingHymn)
        assertNull(m.goToPrevious(HymnSource.Swipe))
        m.open(300, HymnSource.Numpad)
        assertNull(m.upcomingHymn)
        assertNull(m.goToNext(HymnSource.Swipe))
        assertEquals(300, m.hymn?.number)
    }

    @Test fun recentsKeepTheLastThreePerNumbering() {
        val m = model()
        listOf(5, 6, 7, 5, 8).forEach { m.open(it, HymnSource.Numpad) }
        assertEquals(listOf(8, 5, 7), m.recents)
        assertEquals(8, store.getInt(ReaderHistory.KEY_LAST_HYMN))
        // The SDA Hymnal keeps its own.
        m.switchHymnal(catalogs.sdah!!, HymnalSource.Translation)
        assertEquals("sdah", m.hymnal?.id)
        assertFalse(m.recents.contains(5))
        m.open(100, HymnSource.Numpad)
        assertEquals(100, store.getInt("reader.lastHymn.sdah"))
        assertEquals(8, store.getInt(ReaderHistory.KEY_LAST_HYMN))
    }

    @Test fun aPlaylistRunsInTheReaderUntilAHymnIsOpenedAnotherWay() {
        val m = model()
        val list = m.playlistBook.create("english", "Sabbath", 5).playlist
        listOf(3, 9).forEach { m.playlistBook.add("english", list.id, it) }
        var started: Int? = null
        m.onPlaylistStarted = { started = it.number }
        m.play(m.playlist(list.id)!!)
        assertEquals(5, m.hymn?.number)
        assertEquals(5, started)
        assertEquals("Sabbath · 1 of 3", m.playlistProgress)
        // Swiping follows the playlist, not the numbers.
        assertEquals(3, m.upcomingHymn?.number)
        assertEquals(3, m.goToNext(HymnSource.Swipe)?.number)
        assertEquals(5, m.precedingHymn?.number)
        assertEquals(9, m.goToNext(HymnSource.Swipe)?.number)
        assertEquals("Sabbath · 3 of 3", m.playlistProgress)
        // A finished playlist carries on by number.
        assertEquals(10, m.goToNext(HymnSource.Swipe)?.number)
        assertNull(m.activePlaylistId)
        // Opening by number leaves the playlist.
        m.play(m.playlist(list.id)!!, start = 1)
        assertEquals(3, m.hymn?.number)
        m.open(20, HymnSource.Numpad)
        assertNull(m.activePlaylistId)
        assertNull(m.playlistProgress)
        assertEquals(21, m.upcomingHymn?.number)
        assertEquals("playlist", opened().first { it["hymn_number"] == 5 }["source"])
    }

    @Test fun aServicePlanEndsAtItsLastHymn() {
        val m = model()
        assertTrue(m.play(listOf(12, 400, 7), "Sabbath morning", HymnSource.ServicePlan))
        assertEquals(12, m.hymn?.number)
        assertEquals(7, m.upcomingHymn?.number)
        assertEquals(7, m.goToNext(HymnSource.Swipe)?.number)
        assertNull(m.goToNext(HymnSource.Swipe))
        assertEquals(7, m.hymn?.number)
        assertFalse(m.play(listOf(999), "None", HymnSource.ServicePlan))
    }

    @Test fun switchingHymnalKeepsTheHymn() {
        val m = model()
        m.open(100, HymnSource.Numpad)
        // A translation: the same number.
        m.switchHymnal(catalogs.hymnal("shona")!!, HymnalSource.Translation)
        assertEquals("shona", m.hymnal?.id)
        assertEquals(100, m.hymn?.number)
        assertEquals("shona", store.getString(ReaderHistory.KEY_HYMNAL))
        assertEquals(
            mapOf("from_hymnal" to "english", "to_hymnal" to "shona", "source" to "translation"),
            events.last { it.name == "hymnal_switched" }.properties.filterKeys { it in setOf("from_hymnal", "to_hymnal", "source") },
        )
        // The switch itself sends no hymn_opened.
        assertTrue(opened().none { it["hymnal"] == "shona" })
        // Across to the SDA Hymnal: the cross-referenced hymn (CIS 1 is SDAH 368).
        m.switchHymnal(catalogs.hymnal("english")!!)
        m.open(1, HymnSource.Numpad)
        assertEquals(368, m.numberIn(catalogs.sdah!!))
        m.switchHymnal(catalogs.sdah!!)
        assertEquals(368, m.hymn?.number)
        // And back.
        m.switchHymnal(catalogs.hymnal("english")!!)
        assertEquals(1, m.hymn?.number)
    }

    @Test fun aHymnWithoutAMatchOpensTheLastOneReadThere() {
        val m = model()
        m.open(77, HymnSource.Numpad)
        m.switchHymnal(catalogs.sdah!!)
        m.open(1, HymnSource.Numpad) // SDAH 1 is not in Christ In Song
        assertNull(m.numberIn(catalogs.defaultHymnal))
        m.switchHymnal(catalogs.defaultHymnal)
        assertEquals(77, m.hymn?.number) // the last hymn read in Christ In Song's numbering
    }

    @Test fun aSwitchLeavesTheRunningPlaylist() {
        val m = model()
        val list = m.playlistBook.create("english", "P", 4).playlist
        m.play(list)
        m.switchHymnal(catalogs.hymnal("zulu")!!)
        assertNull(m.activePlaylistId)
    }

    @Test fun favouritesArePerHymnal() {
        val m = model()
        m.open(30, HymnSource.Numpad)
        m.toggleFavourite()
        assertTrue(m.isFavourite)
        assertTrue(m.addFavourite(12))
        assertFalse("no such hymn", m.addFavourite(301))
        assertEquals(listOf(12, 30), m.favouriteNumbers)
        m.switchHymnal(catalogs.hymnal("shona")!!)
        assertFalse(m.isFavourite)
        assertTrue(m.favouriteNumbers.isEmpty())
    }

    @Test fun theNumberPadRefusesNumbersPastTheEnd() {
        val m = model()
        m.openLectern(LecternState.Pad)
        assertTrue(m.proposeDigits("3"))
        assertTrue(m.proposeDigits("30"))
        assertFalse(m.proposeDigits("301"))
        assertEquals("30", m.digits)
        assertTrue(m.proposeDigits("3"))
        assertEquals("Hymn 3", "Hymn ${m.previewHymn?.number}")
        assertTrue(m.openPreview())
        assertEquals(3, m.hymn?.number)
        assertEquals(LecternState.Collapsed, m.lectern)
    }

    @Test fun oneThingOpenAtATime() {
        val m = model()
        m.openLectern(LecternState.Library)
        m.openMenu(ReaderMenuPanel.Text)
        assertEquals(LecternState.Collapsed, m.lectern)
        assertEquals(ReaderMenuPanel.Text, m.menuPanel)
        m.toggleMenuPanel(ReaderMenuPanel.Text)
        assertNull(m.menuPanel)
        assertTrue(m.isMenuOpen)
        m.toggleFocus()
        assertFalse(m.isMenuOpen)
        m.toggleFocus()
        assertTrue(m.isFocused)
        m.openLectern(LecternState.Hymn)
        assertFalse(m.isFocused)
    }

    @Test fun aLinkOpensTheHymnInItsOwnHymnal() {
        val m = model()
        m.openLink(368, "sdah")
        assertEquals("sdah", m.hymnal?.id)
        assertEquals(368, m.hymn?.number)
        m.openLink(5, null)
        assertEquals(5, m.hymn?.number)
    }

    companion object {
        private val catalogs by lazy { Catalogs(DirectoryAssets.iosResources()) }
    }
}
