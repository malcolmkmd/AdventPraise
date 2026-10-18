package com.mDev.AdventPraise.reader

import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReaderHistory
import com.mDev.AdventPraise.ui.reader.ReaderMenuRules
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The sheet music button beside the globe shows only for a hymn that has
 * sheet music in the hymnal being read, and never while the menu is open
 * (ReaderSheetMusicButtonTests on iOS).
 */
class ReaderSheetMusicButtonTest {
    private val catalogs = Catalogs(DirectoryAssets.iosResources())

    private fun model(): ReaderModel {
        val store = MemoryStore(mapOf(ReaderHistory.KEY_HYMNAL to "english", ReaderHistory.KEY_LAST_HYMN to 1))
        val book = PlaylistBook(store)
        return ReaderModel(catalogs, ReaderHistory(store), HymnQueue(book), book,
            CoroutineScope(Dispatchers.Unconfined), Dispatchers.Unconfined).also { it.start() }
    }

    private fun shows(m: ReaderModel) = ReaderMenuRules.showsSheetMusicButton(m.hasSheetMusic, m.isMenuOpen)

    @Test fun theButtonFollowsTheHymnOnScreen() {
        val m = model()
        assertTrue(m.hymn?.number == 1 && shows(m))                 // CIS 1 has a score
        m.openMenu()
        assertFalse("hidden while the menu is open", shows(m))
        m.closeMenu()
        assertTrue(m.open(4, HymnSource.Numpad))
        assertFalse(shows(m))                                        // CIS 4 has none
        assertTrue(m.open(1, HymnSource.Numpad))

        // SDA Hymnal: 368 is CIS 1's public domain tune, so it has the score.
        m.switchHymnal(catalogs.sdah!!)
        assertTrue(m.hymn?.number == 368 && shows(m))
        assertTrue(m.open(489, HymnSource.Numpad))
        assertFalse(shows(m))                                        // another tune than CIS 59
        assertTrue(m.open(1, HymnSource.Numpad))
        assertFalse(shows(m))                                        // not in Christ In Song
    }

    @Test fun everyHymnAgreesWithTheCatalogue() {
        for (info in catalogs.hymnals) {
            val hymnal = catalogs.load(info) ?: continue
            val withMusic = hymnal.hymns.count { catalogs.hasSheetMusic(info.id, it.number) }
            if (info.id == "english") assertEquals(catalogs.sheetMusic.count("english"), withMusic)
            if (info.id != "english" && info.id != "sdah") assertEquals(info.id, 0, withMusic)
        }
    }
}
