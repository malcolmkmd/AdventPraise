package com.mDev.AdventPraise.ui.whatsnew

import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.shortcuts.AppShortcut
import com.mDev.AdventPraise.ui.root.SplashPhase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** What's New shows once per version, after the splash (WhatsNewPresenter). */
class WhatsNewScheduleTest {
    @Test fun itWaitsForTheSplashThenPauses() {
        assertEquals(WhatsNewDecision.Wait, WhatsNewSchedule.decide("", "7.0", SplashPhase.Showing))
        assertEquals(WhatsNewDecision.Show(1_750), WhatsNewSchedule.decide("", "7.0", SplashPhase.Finished))
        // No splash in this tree: at once.
        assertEquals(WhatsNewDecision.Show(0), WhatsNewSchedule.decide("", "7.0", SplashPhase.None))
    }

    @Test fun seenThisVersionOffersTheTourInstead() {
        assertEquals(WhatsNewDecision.OfferTour, WhatsNewSchedule.decide("7.0", "7.0", SplashPhase.Finished))
        // A new major version shows again.
        assertEquals(WhatsNewDecision.Show(1_750), WhatsNewSchedule.decide("6.0", "7.0", SplashPhase.Finished))
    }

    @Test fun itShowsOncePerVersion() {
        val store = MemoryStore()
        val settings = AppSettings(store)
        assertTrue(settings.shouldShowWhatsNew(WHATS_NEW_VERSION))
        settings.markWhatsNewSeen(WHATS_NEW_VERSION)
        assertFalse(settings.shouldShowWhatsNew(WHATS_NEW_VERSION))
        // Kept under iOS's key, so it survives a relaunch.
        assertEquals("7.0", store.getString(AppSettings.WHATS_NEW))
        assertFalse(AppSettings(store).shouldShowWhatsNew(WHATS_NEW_VERSION))
        assertEquals(WhatsNewDecision.OfferTour, WhatsNewSchedule.decide(AppSettings(store).whatsNewLastSeen, WHATS_NEW_VERSION, SplashPhase.Finished))
    }

    @Test fun siriBecomesTheAppShortcuts() {
        val titles = WhatsNewAndroidFeatures.map { it.title }
        assertEquals(listOf("Worship mode", "Large print", "Every hymnal, free", "App shortcuts"), titles)
        assertFalse(WhatsNewAndroidFeatures.any { "Siri" in it.title || "Siri" in it.body })
    }

    @Test fun theShortcutLinksParse() {
        assertEquals(AppShortcut.OpenHymn, AppShortcut.parse("adventpraise://shortcut/open-hymn"))
        assertEquals(AppShortcut.HymnOfTheDay, AppShortcut.parse("adventpraise://shortcut/hymn-of-the-day"))
        assertEquals(AppShortcut.ChurchMode, AppShortcut.parse("adventpraise://shortcut/church-mode/"))
        // The widgets' links are the church area's.
        assertNull(AppShortcut.parse("adventpraise://present"))
        assertNull(AppShortcut.parse("adventpraise://hymn/12"))
        assertNull(AppShortcut.parse(null))
    }
}
