package com.mDev.AdventPraise.church.display

import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchSession
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The second display: TV connected at once; the worship display up with Pro and an activity, else mirroring. */
@OptIn(ExperimentalCoroutinesApi::class)
class TvOutputTest {
    private class FakeDisplays : DisplaySource {
        var now = emptyList<TvRoute>()
        var listener: (() -> Unit)? = null
        override fun displays() = now
        override fun listen(onChange: () -> Unit): () -> Unit { listener = onChange; return { listener = null } }
        fun plug(vararg routes: TvRoute) { now = routes.toList(); listener?.invoke() }
    }

    private class FakeWindow(var canShow: Boolean = true) : WorshipWindow {
        val log = mutableListOf<String>()
        override fun show(displayId: String): Boolean { log += "show $displayId"; return canShow }
        override fun dismiss() { log += "dismiss" }
    }

    private val hdmi = TvRoute("2", "HDMI", TvRouteKind.SecondDisplay)
    private val miracast = TvRoute("5", "Living room", TvRouteKind.SecondDisplay)

    @Test fun theWorshipDisplayNeedsADisplayProAndAHost() {
        val window = FakeWindow()
        val m = SecondDisplayMachine(window)
        m.hostChanged(true)
        m.displaysChanged(listOf(hdmi))
        assertEquals(hdmi, m.state.connected)
        assertFalse("without Pro Android mirrors", m.state.showsWorshipDisplay)
        assertTrue(window.log.isEmpty())
        m.proChanged(true)
        assertTrue("buying Pro puts it up at once", m.state.showsWorshipDisplay)
        assertEquals(listOf("show 2"), window.log)
        m.proChanged(false)
        assertFalse("losing Pro takes it down", m.state.showsWorshipDisplay)
        assertEquals("dismiss", window.log.last())
    }

    @Test fun theHostGoingAndANewHostRebuildTheWindow() {
        val window = FakeWindow()
        val m = SecondDisplayMachine(window)
        m.proChanged(true)
        m.displaysChanged(listOf(hdmi))
        assertNull(m.shownOn)
        m.hostChanged(true, isNewHost = true)
        assertEquals("2", m.shownOn)
        m.hostChanged(false)
        assertNull(m.shownOn)
        assertEquals(hdmi, m.state.connected)
        m.hostChanged(true, isNewHost = true)
        m.hostChanged(true, isNewHost = true)
        assertEquals(listOf("show 2", "dismiss", "show 2", "dismiss", "show 2"), window.log)
    }

    @Test fun unpluggingAndSwitchingDisplays() {
        val window = FakeWindow()
        val m = SecondDisplayMachine(window)
        m.hostChanged(true); m.proChanged(true)
        m.displaysChanged(listOf(miracast))
        m.displaysChanged(listOf(hdmi, miracast))
        assertEquals("2", m.shownOn)
        m.displaysChanged(emptyList())
        assertNull(m.state.connected)
        assertNull(m.shownOn)
        assertEquals(listOf("show 5", "dismiss", "show 2", "dismiss"), window.log)
    }

    @Test fun aWindowThatCantShowLeavesTheTvMirroring() {
        val m = SecondDisplayMachine(FakeWindow(canShow = false))
        m.hostChanged(true); m.proChanged(true); m.displaysChanged(listOf(hdmi))
        assertEquals(hdmi, m.state.connected)
        assertFalse(m.state.showsWorshipDisplay)
    }

    @Test fun theOutputsTellTheSessionATvIsConnected() = runTest(UnconfinedTestDispatcher()) {
        val session = ChurchSession(object : ChurchHost {
            override fun goToNextHymn() = false
            override fun showPaywall(feature: ProFeature) = Unit
        }, clock = { 0L })
        val displays = FakeDisplays()
        val window = FakeWindow()
        val isPro = MutableStateFlow(false)
        val hosts = null
        val output = PresentationTvOutput(displays, isPro, backgroundScope, window, hosts)
        val tv = TvOutputs(session, backgroundScope, listOf(output))
        tv.start()
        assertFalse(session.current.isExternalScreenConnected)
        displays.plug(hdmi)
        assertTrue(session.current.isExternalScreenConnected)
        assertEquals(listOf(hdmi), tv.state.value.routes)
        assertFalse(session.current.isOnExternalScreen)
        displays.plug()
        assertFalse(session.current.isExternalScreenConnected)
        assertNull(tv.state.value.connected)
        tv.stop()
        assertNull(displays.listener)
    }

    @Test fun mergingPutsTheFirstConnectedTvFirst() {
        val cast = TvRoute("cast:1", "Chromecast", TvRouteKind.Cast)
        val merged = TvOutputs.merge(listOf(
            TvOutputState(routes = listOf(hdmi), connected = null),
            TvOutputState(routes = listOf(cast), connected = cast, showsWorshipDisplay = true),
        ))
        assertEquals(listOf(hdmi, cast), merged.routes)
        assertEquals(cast, merged.connected)
        assertTrue(merged.showsWorshipDisplay)
        assertEquals(TvOutputState(), TvOutputs.merge(emptyList()))
    }

    @Test fun theBannerShowsOnlyWithoutProAndTheDisplayWins() {
        assertNull(ScreenMirroring.bannerRoute(isPro = true, isCaptured = true, hasExternalDisplay = true))
        assertEquals(com.mDev.AdventPraise.analytics.MirroringRoute.ExternalDisplay,
            ScreenMirroring.bannerRoute(isPro = false, isCaptured = true, hasExternalDisplay = true))
        assertEquals(com.mDev.AdventPraise.analytics.MirroringRoute.Capture,
            ScreenMirroring.bannerRoute(isPro = false, isCaptured = true, hasExternalDisplay = false))
        assertNull(ScreenMirroring.bannerRoute(isPro = false, isCaptured = false, hasExternalDisplay = false))
        val events = mutableListOf<Any>()
        val m = ScreenMirroring(null) { events += it }
        m.bannerShown(com.mDev.AdventPraise.analytics.MirroringRoute.Capture, inChurchMode = true)
        m.bannerShown(com.mDev.AdventPraise.analytics.MirroringRoute.Capture, inChurchMode = true)
        assertEquals("mirroring_detected once per session", 1, events.size)
    }
}
