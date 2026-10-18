package com.mDev.AdventPraise.ui.tour

import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.TourSource
import com.mDev.AdventPraise.billing.FreePlays
import com.mDev.AdventPraise.billing.StoreFreePlayStorage
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.MemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The tour's reducer (TourModel.swift): what each signal and Next does, stage by stage. */
class TourModelTest {
    private val events = mutableListOf<AnalyticsEvent>()
    private val actions = mutableListOf<TourAction>()
    private val settings = AppSettings(MemoryStore())
    private val tour = TourModel(settings, track = { events += it }, haptic = {}).apply { perform = { actions += it } }

    private fun at(step: TourStep, stage: Int) = assertEquals(TourPhase.Running(step, stage), tour.phase)
    private val names get() = events.map { it.name }

    @Test fun theWholeTourByDoing() {
        tour.start(TourSource.WhatsNew)
        assertEquals(listOf(TourAction.ResetChrome), actions)
        assertTrue(tour.isActive)
        // 1 · Number pad: open it, back out, open again, go.
        at(TourStep.NumberPad, 0)
        assertEquals(listOf(TourTarget.Jump), tour.stage!!.targets)
        tour.observe(TourSignal.Lectern(LecternState.Pad)); at(TourStep.NumberPad, 1)
        tour.observe(TourSignal.Lectern(LecternState.Collapsed)); at(TourStep.NumberPad, 0)
        tour.observe(TourSignal.Lectern(LecternState.Pad))
        tour.observe(TourSignal.HymnChanged)
        // 2 · Swipe: the whole page takes touches; a swipe or Next moves on.
        at(TourStep.Swipe, 0)
        assertFalse(tour.stage!!.blocksTouches)
        tour.observe(TourSignal.HymnChanged)
        // 3 · The tray; Next closes it.
        at(TourStep.Tray, 0)
        tour.observe(TourSignal.Lectern(LecternState.Hymn)); at(TourStep.Tray, 1)
        tour.advance()
        assertEquals(TourAction.CloseLectern, actions.last())
        // 4 · The globe: closing the menu completes it.
        at(TourStep.Globe, 0)
        tour.observe(TourSignal.MenuOpen(true)); at(TourStep.Globe, 1)
        tour.observe(TourSignal.MenuOpen(false))
        // 5 · The piano; Next stops it.
        at(TourStep.Player, 0)
        tour.observe(TourSignal.Playing(true)); at(TourStep.Player, 1)
        tour.advance()
        assertEquals(TourAction.StopPlayer, actions.last())
        // 6 · Memorise: the sheet hides the card until it closes.
        at(TourStep.Memorise, 0)
        tour.observe(TourSignal.Lectern(LecternState.Hymn)); at(TourStep.Memorise, 1)
        tour.observe(TourSignal.MemoriseOpen(true)); at(TourStep.Memorise, 2)
        assertTrue(tour.stage!!.isHidden)
        tour.observe(TourSignal.MemoriseOpen(false))
        // 7 · Church mode and its actions; Next leaves church mode, which completes it.
        at(TourStep.Church, 0)
        tour.observe(TourSignal.ChurchOpen(true)); at(TourStep.Church, 2)
        assertEquals(TourArea.Church, tour.stage!!.area)
        tour.observe(TourSignal.ChurchActionsOpen(true)); at(TourStep.Church, 3)
        tour.observe(TourSignal.ChurchActionsOpen(false)); at(TourStep.Church, 4)
        tour.advance()
        assertEquals(TourAction.LeaveChurchMode, actions.last())
        at(TourStep.Church, 4)
        tour.observe(TourSignal.ChurchOpen(false))
        // 8 · Pro and Support, in More; Next on Support closes More, which ends the steps.
        at(TourStep.Pro, 0)
        tour.observe(TourSignal.Lectern(LecternState.Hymn)); at(TourStep.Pro, 1)
        assertEquals(listOf(TourTarget.MoreTile), tour.stage!!.targets)
        tour.observe(TourSignal.MoreOpen(true)); at(TourStep.Pro, 2)
        assertEquals(TourArea.More, tour.stage!!.area)
        assertEquals(listOf(TourTarget.ProCard), tour.stage!!.targets)
        tour.advance(); at(TourStep.Pro, 3)
        assertEquals(listOf(TourTarget.SupportRow), tour.stage!!.targets)
        tour.advance()
        assertEquals(TourAction.CloseMore, actions.last())
        tour.observe(TourSignal.MoreOpen(false))
        assertEquals(TourPhase.Finale, tour.phase)
        assertEquals("You’re all set", tour.stage!!.title)
        // Done.
        tour.advance()
        assertEquals(TourPhase.Idle, tour.phase)
        assertFalse(tour.isActive)
        assertTrue(settings.tourSeen)
        assertEquals("tour_started", names.first())
        assertEquals(8, names.count { it == "tour_step_completed" })
        assertEquals(mapOf("completed" to true, "last_step" to 8), events.last().properties)
    }

    @Test fun signalsForOtherStagesAreIgnored() {
        tour.start(TourSource.More)
        tour.observe(TourSignal.MenuOpen(true))
        tour.observe(TourSignal.ChurchOpen(true))
        tour.observe(TourSignal.Lectern(LecternState.Hymn))
        at(TourStep.NumberPad, 0)
        // Nothing runs while it is idle.
        tour.skip()
        tour.observe(TourSignal.HymnChanged)
        assertEquals(TourPhase.Idle, tour.phase)
    }

    @Test fun aHymnWithoutAPianoExplainsInstead() {
        tour.context = tour.context.copy(hasAccompaniment = false)
        tour.start(TourSource.Debug, at = TourStep.Player)
        assertTrue(tour.stage!!.showsNext)
        assertTrue(tour.stage!!.targets.isEmpty())
        tour.observe(TourSignal.Playing(true))
        at(TourStep.Player, 0)
        tour.advance()
        at(TourStep.Memorise, 0)
    }

    @Test fun skipEndsItForGood() {
        tour.start(TourSource.WhatsNew, at = TourStep.Globe)
        tour.skip()
        assertEquals(TourPhase.Idle, tour.phase)
        assertTrue(settings.tourSeen)
        assertEquals(mapOf("completed" to false, "last_step" to 4), events.last().properties)
        // It won't come back after What's New.
        tour.offerAfterWhatsNew()
        assertNull(tour.pending)
    }

    @Test fun whatsNewOffersItOnceAndItStartsWhenClear() {
        tour.offerAfterWhatsNew()
        assertEquals(TourSource.WhatsNew, tour.pending)
        tour.startPending()
        assertNull(tour.pending)
        at(TourStep.NumberPad, 0)
        // Already running: no second offer.
        tour.offerAfterWhatsNew()
        assertNull(tour.pending)
    }

    @Test fun theLegacyCompletedKeyIsHonoured() {
        val old = AppSettings(MemoryStore(mapOf(AppSettings.TOUR_LEGACY to true)))
        val t = TourModel(old, track = {}, haptic = {})
        t.offerOnLaunch()
        assertNull(t.pending)
    }

    @Test fun nothingPlayedOnTheTourCounts() {
        val plays = FreePlays(listOf(StoreFreePlayStorage(MemoryStore())))
        tour.onActiveChanged = { plays.isTourActive = it }
        tour.start(TourSource.More)
        assertEquals(5, plays.spend())
        assertEquals(0, plays.used)
        tour.skip()
        assertEquals(4, plays.spend())
    }
}
