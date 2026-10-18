package com.mDev.AdventPraise.settings

import com.mDev.AdventPraise.data.Numbering
import com.mDev.AdventPraise.data.SheetMusicViewMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReadingSettingsTest {
    @Test fun defaultsAreIOSs() {
        val s = ReadingSettings(MemoryStore())
        assertEquals(ReadingSurface.Paper, s.surface)
        assertEquals(19f, s.pointSize)
        assertTrue(s.isDefaultSize)
        assertEquals(42f, s.worshipPointSize)
        assertTrue(s.haptics)
        assertFalse(s.repeatChorus)
    }

    @Test fun theSnapshotRoundTripsUnderTheIOSKey() {
        val store = MemoryStore()
        val s = ReadingSettings(store)
        s.updateSurface(ReadingSurface.Sepia)
        s.updateFont(ReadingFont.Sans)
        s.updateLineSpacing(LineSpacing.Relaxed)
        s.updateCentered(true)
        s.updateRepeatChorus(true)
        s.updateLargePrint(true)
        s.updateStep(4)
        s.updateHaptics(false)
        val again = ReadingSettings(store)
        assertEquals(ReadingSurface.Sepia, again.surface)
        assertEquals(ReadingFont.Sans, again.font)
        assertEquals(LineSpacing.Relaxed, again.lineSpacing)
        assertTrue(again.centered && again.repeatChorus && again.largePrint)
        assertEquals(40f, again.pointSize)
        assertFalse(again.haptics)
        val json = store.getString("reading.settings.v1")!!
        assertTrue(json.contains("\"environment\":\"sepia\"") && json.contains("\"sizeIndex\":4"))
    }

    @Test fun readsASnapshotWrittenByIOS() {
        val store = MemoryStore(mapOf("reading.settings.v1" to
            """{"sizeIndex":1,"lineSpacing":"compact","centered":false,"font":"serif","environment":"black","largePrint":false,"pointSize":20.5,"worshipPointSize":56}"""))
        val s = ReadingSettings(store)
        assertEquals(ReadingSurface.Black, s.surface)
        assertEquals(LineSpacing.Compact, s.lineSpacing)
        assertEquals(20.5f, s.pointSize)
        assertEquals(56f, s.worshipPointSize)
    }

    @Test fun pinchKeepsASizeBetweenTheStepsUntilTheSliderMoves() {
        val s = ReadingSettings(MemoryStore())
        s.pinch(22.4f)
        assertEquals(22.4f, s.pointSize)
        assertEquals(3, s.step)
        s.pinch(99f)
        assertEquals(32f, s.pointSize)
        s.updateStep(1)
        assertNull(s.pinchedPointSize)
        assertEquals(18f, s.pointSize)
        s.pinch(30f)
        s.updateLargePrint(true)
        assertNull("changing the scale drops a pinched size", s.pinchedPointSize)
        s.resetSize()
        assertTrue(s.isDefaultSize)
    }

    @Test fun churchModeStepsThroughTheWorshipSizes() {
        val s = ReadingSettings(MemoryStore())
        assertTrue(s.stepWorshipText(1))
        assertEquals(48f, s.worshipPointSize)
        s.updateWorshipPointSize(50f)
        assertEquals(56f, s.worshipStepTarget(1))
        assertEquals(48f, s.worshipStepTarget(-1))
        s.updateWorshipPointSize(64f)
        assertFalse(s.stepWorshipText(1))
        s.updateWorshipPointSize(5f)
        assertEquals(30f, s.worshipPointSize)
        s.resetWorshipSize()
        assertTrue(s.isDefaultWorshipSize)
    }
}

class ReaderHistoryTest {
    @Test fun lastHymnAndRecentsArePerNumbering() {
        val store = MemoryStore()
        val h = ReaderHistory(store)
        assertNull(h.lastHymn(Numbering.ChristInSong))
        h.recordOpened(Numbering.ChristInSong, 1)
        h.recordOpened(Numbering.ChristInSong, 2)
        h.recordOpened(Numbering.ChristInSong, 3)
        assertEquals(listOf(1, 3, 2), h.recordOpened(Numbering.ChristInSong, 1))
        h.recordOpened(Numbering.ChristInSong, 9)
        assertEquals(listOf(9, 1, 3), h.recents(Numbering.ChristInSong))
        h.recordOpened(Numbering.Sdah, 100)
        assertEquals(9, h.lastHymn(Numbering.ChristInSong))
        assertEquals(100, store.getInt("reader.lastHymn.sdah"))
        assertEquals(listOf(100), ReaderHistory(store).recents(Numbering.Sdah))
        h.setHymnal("sdah")
        assertEquals("sdah", ReaderHistory(store).hymnalId)
    }

    @Test fun favouritesArePerHymnal() {
        val store = MemoryStore()
        val h = ReaderHistory(store)
        assertTrue(h.toggleFavourite("english", 12))
        h.addFavourite("english", 3)
        h.addFavourite("shona", 12)
        assertEquals(listOf(3, 12), h.favouriteNumbers("english"))
        assertFalse(h.toggleFavourite("english", 12))
        assertEquals(setOf("english#3", "shona#12"), ReaderHistory(store).favourites)
    }
}

class AppSettingsTest {
    @Test fun keptUnderTheIOSKeys() {
        val store = MemoryStore(mapOf("tour.completed" to true))
        val s = AppSettings(store)
        assertTrue("7.0.1's key is honoured", s.tourSeen)
        assertTrue(s.shouldShowWhatsNew("7.1"))
        s.markWhatsNewSeen("7.1")
        assertFalse(AppSettings(store).shouldShowWhatsNew("7.1"))
        s.updateSheetMusicViewMode(SheetMusicViewMode.System)
        s.updateTempo(PlaybackTempo.Slow)
        val again = AppSettings(store)
        assertEquals(SheetMusicViewMode.System, again.sheetMusicViewMode)
        assertEquals(PlaybackTempo.Slow, again.tempo)
        assertEquals("system", store.getString("sheetMusic.viewMode"))
        assertEquals("slow", store.getString("player.tempo"))
    }

    @Test fun announcementsKeepTheLastSixWithoutRepeats() {
        val s = AppSettings(MemoryStore())
        (1..7).forEach { s.addAnnouncement("m$it") }
        assertEquals(listOf("m7", "m6", "m5", "m4", "m3", "m2"), s.announcementRecents)
        assertEquals(listOf("m4", "m7", "m6", "m5", "m3", "m2"), s.addAnnouncement("m4"))
    }
}
