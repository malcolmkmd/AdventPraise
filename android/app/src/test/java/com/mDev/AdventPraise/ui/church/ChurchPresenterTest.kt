package com.mDev.AdventPraise.ui.church

import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchRemoteAction
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.church.notification.ChurchNotifier
import com.mDev.AdventPraise.church.notification.ChurchRemoteReceiver
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.ui.design.HapticEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Church mode's presenter on top of ChurchSession: haptics, Pro gating, Blank, next hymn, the end. */
class ChurchPresenterTest {
    private fun hymn(n: Int) = Hymn(n, "Hymn $n", emptyList(),
        listOf(Block.Verse(1, listOf("one")), Block.Chorus(listOf("refrain")), Block.Verse(2, listOf("two"))), null)

    private inner class Fixture(isPro: Boolean, last: Int = 2) : ChurchHost {
        var number = 1
        val paywalls = mutableListOf<ProFeature>()
        val haptics = mutableListOf<HapticEvent>()
        var closed = 0
        val session = ChurchSession(this, clock = { 0L })
        val settings = ReadingSettings(MemoryStore())
        val appSettings = AppSettings(MemoryStore())
        val presenter = ChurchPresenter(session, settings, appSettings, { paywalls += it }, { closed++ }) { haptics += it }
        private val lastHymn = last

        init {
            session.follow(hymn(1), "english", "Christ In Song", "Chorus", lastHymn > 1)
            session.setPro(isPro)
            session.start(ChurchModeSource.Tray)
        }

        override fun goToNextHymn(): Boolean {
            if (number >= lastHymn) return false
            number++
            session.follow(hymn(number), "english", "Christ In Song", "Chorus", number < lastHymn)
            return true
        }

        override fun showPaywall(feature: ProFeature) { paywalls += feature }
    }

    @Test fun versesTurnWithALightTapAndTheFirstIsTheLimit() {
        val f = Fixture(isPro = true)
        f.presenter.previous()
        f.presenter.advance()
        f.presenter.previous()
        assertEquals(listOf(HapticEvent.Limit, HapticEvent.LightImpact, HapticEvent.LightImpact), f.haptics)
        assertEquals(0, f.session.current.index)
    }

    @Test fun pastTheLastVerseComesTheNextHymnThenTheEnd() {
        val f = Fixture(isPro = true, last = 2)
        // Sung as verse 1, chorus, verse 2, chorus.
        repeat(3) { f.presenter.advance() }
        f.presenter.advance()
        assertEquals(2, f.session.current.hymn?.number)
        assertEquals(0, f.session.current.index)
        assertEquals(HapticEvent.PageTurn, f.haptics.last())
        repeat(3) { f.presenter.advance() }
        assertEquals(0, f.closed)
        f.presenter.advance()
        assertEquals("past the last verse of the last hymn church mode closes", 1, f.closed)
    }

    @Test fun blankEndsWhenAVerseTurns() {
        val f = Fixture(isPro = true)
        f.presenter.toggleBlank()
        assertTrue(f.session.current.isBlanked)
        assertEquals(HapticEvent.ToggleOn, f.haptics.last())
        // The first verse is the limit: the screen stays blank, as on iOS.
        f.presenter.previous()
        assertTrue(f.session.current.isBlanked)
        f.presenter.advance()
        assertFalse(f.session.current.isBlanked)
        f.presenter.toggleBlank()
        f.presenter.previous()
        assertFalse(f.session.current.isBlanked)
    }

    @Test fun theRemotesNextHymnStartsAtTheTopOrIsTheLimit() {
        val f = Fixture(isPro = true, last = 2)
        f.presenter.advance()
        f.presenter.toggleBlank()
        f.presenter.nextHymnFromRemote()
        assertEquals(2, f.session.current.hymn?.number)
        assertEquals(0, f.session.current.index)
        assertFalse(f.session.current.isBlanked)
        assertEquals(HapticEvent.PageTurn, f.haptics.last())
        f.presenter.nextHymnFromRemote()
        assertEquals(HapticEvent.Limit, f.haptics.last())
        assertEquals(0, f.closed)
    }

    @Test fun presenterActionsAndTheTvAreProWithoutItThePaywall() {
        val f = Fixture(isPro = false)
        var ran = false
        f.presenter.presenterAction { ran = true }
        f.presenter.tvLocked()
        assertFalse(ran)
        assertEquals(listOf(ProFeature.AirPlay, ProFeature.AirPlay), f.paywalls)
        f.session.setPro(true)
        f.presenter.presenterAction { ran = true }
        assertTrue(ran)
    }

    @Test fun announcementsArePutUpRememberedAndClearedAroundAPicture() {
        val f = Fixture(isPro = true)
        f.presenter.showAnnouncement("  Potluck after the service ")
        assertEquals("Potluck after the service", f.session.current.announcement)
        assertEquals(listOf("Potluck after the service"), f.appSettings.announcementRecents)
        f.presenter.showImage("ABC")
        f.presenter.clearImage()
        assertNull(f.session.current.image)
        assertEquals("the announcement stays up", "Potluck after the service", f.session.current.announcement)
        f.presenter.clearAnnouncement()
        assertFalse(f.session.current.isShowingSpecial)
        f.appSettings.removeAnnouncement("Potluck after the service")
        assertTrue(f.appSettings.announcementRecents.isEmpty())
    }

    @Test fun textSizeStepsAndStopsAtTheLimits() {
        val f = Fixture(isPro = true)
        assertTrue(f.presenter.changeTextSize(1))
        assertEquals(48f, f.settings.worshipPointSize)
        repeat(3) { f.presenter.changeTextSize(1) }
        assertEquals(HapticEvent.Limit, f.haptics.last())
        f.presenter.resetTextSize()
        assertEquals(ReadingSettings.DEFAULT_WORSHIP_POINT_SIZE, f.settings.worshipPointSize)
        assertEquals(42f * 1.2f * 1.2f, lyricSize(42f, largePrint = true, fontScale = 2f), 0.01f)
        assertEquals(96f, lyricSize(80f, largePrint = true, fontScale = 2f), 0.01f)
    }

    @Test fun theNotificationShowsOnlyWhilePresentingWithPro() {
        val f = Fixture(isPro = true)
        val content = ChurchNotifier.content(f.session.current)!!
        assertEquals("1 · Hymn 1", ChurchNotifier.title(content))
        assertEquals("Verse 1 of 2", ChurchNotifier.text(content))
        f.session.setExternalScreen(true)
        assertEquals("Verse 1 of 2 · On TV", ChurchNotifier.text(ChurchNotifier.content(f.session.current)!!))
        f.session.setPro(false)
        assertNull(ChurchNotifier.content(f.session.current))
        f.session.setPro(true)
        f.session.stop()
        assertNull(ChurchNotifier.content(f.session.current))
    }

    @Test fun remoteButtonsAfterTheAppWasGoneFindNothingToPresent() {
        val f = Fixture(isPro = true)
        assertEquals(ChurchRemoteReceiver.Route.Perform, ChurchRemoteReceiver.route(f.session, ChurchRemoteAction.Next))
        f.session.stop()
        assertEquals(ChurchRemoteReceiver.Route.Stale, ChurchRemoteReceiver.route(f.session, ChurchRemoteAction.Next))
        assertEquals(ChurchRemoteReceiver.Route.Perform, ChurchRemoteReceiver.route(f.session, ChurchRemoteAction.NextHymn))
        f.session.setPro(false)
        assertEquals("without Pro the session opens the paywall", ChurchRemoteReceiver.Route.Perform,
            ChurchRemoteReceiver.route(f.session, ChurchRemoteAction.Blank))
    }
}
