// OWNER: shell
package com.mDev.AdventPraise.ui.whatsnew

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Church
import androidx.compose.material.icons.rounded.FormatSize
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.WhatsNewAction
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.AdventDrawerStyle
import com.mDev.AdventPraise.ui.design.DrawerDetent
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.WhatsNewActions
import com.mDev.AdventPraise.ui.design.WhatsNewFeature
import com.mDev.AdventPraise.ui.design.WhatsNewPage
import com.mDev.AdventPraise.ui.design.stageBackground
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.root.LocalSplashPhase
import com.mDev.AdventPraise.ui.root.SplashPhase
import com.mDev.AdventPraise.ui.theme.DS
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged

/*
 * What's New in the drawer (WhatsNewSheet.swift's WhatsNewPresenter): once per
 * major version, after the launch splash and a 1.75 s pause so the app is seen
 * first. `whats_new_viewed` when it shows, `whats_new_dismissed` with the
 * button that closed it (or `dismissed` for a drag or Back) when it goes, and
 * then the onboarding tour is offered once. An existing user who has already
 * seen it gets the tour offered at launch instead.
 */

/** The major version What's New belongs to (iOS's `whatsNewDrawer(version: "7.0")`). */
const val WHATS_NEW_VERSION = "7.0"

/** Always the Stage: dark whatever the reading surface, fitted then large. */
val WhatsNewDrawerStyle = AdventDrawerStyle(
    detents = listOf(DrawerDetent.Fitted, DrawerDetent.Large),
    dimming = 0.5f,
    surface = ReadingSurface.Black,
    background = { stageBackground(0.92f) },
    actionScrim = DS.Palette.stage,
)

/**
 * The 7.0 feature set as iOS ships it, with iOS's "Ask Siri" told the Android
 * way: the app shortcuts on a long-press of the icon (res/xml/shortcuts.xml).
 */
val WhatsNewAndroidFeatures: List<WhatsNewFeature> = WhatsNewFeature.advent7.take(3) + WhatsNewFeature(
    Icons.Rounded.TouchApp, "App shortcuts",
    "Touch and hold the Advent Praise icon to open a hymn, Hymn of the Day or church mode.",
)

/** What the launcher should do now (the `.task(id: splash)` decision in WhatsNewPresenter). */
sealed interface WhatsNewDecision {
    /** The splash is still up. */
    data object Wait : WhatsNewDecision
    /** Already seen this version: the tour is offered once instead. */
    data object OfferTour : WhatsNewDecision
    /** Show it after [delayMs] (the pause after the splash; none without one). */
    data class Show(val delayMs: Long) : WhatsNewDecision
}

object WhatsNewSchedule {
    const val PAUSE_AFTER_SPLASH_MS = 1_750L

    fun decide(lastSeen: String, version: String, splash: SplashPhase): WhatsNewDecision = when {
        splash == SplashPhase.Showing -> WhatsNewDecision.Wait
        lastSeen == version -> WhatsNewDecision.OfferTour
        splash == SplashPhase.Finished -> WhatsNewDecision.Show(PAUSE_AFTER_SPLASH_MS)
        else -> WhatsNewDecision.Show(0)
    }
}

/** Which button closed What's New, for `whats_new_dismissed`; null if it was dragged away. */
private object WhatsNewSession {
    var action: WhatsNewAction? = null
}

/**
 * Shows What's New once per version, tracks it, and offers the tour when it
 * closes. Mounted once in the root, inside the splash.
 */
@Composable
fun WhatsNewLauncher(services: AppServices, navigator: AppNavigator, version: String = WHATS_NEW_VERSION) {
    val splash = LocalSplashPhase.current
    val settings = services.appSettings
    val tour = services.tour
    LaunchedEffect(splash) {
        if (navigator.stack.any { it is Destination.WhatsNew }) return@LaunchedEffect
        when (val decision = WhatsNewSchedule.decide(settings.whatsNewLastSeen, version, splash)) {
            WhatsNewDecision.Wait -> Unit
            WhatsNewDecision.OfferTour -> tour.offerOnLaunch()
            is WhatsNewDecision.Show -> {
                if (decision.delayMs > 0) delay(decision.delayMs)
                if (!settings.shouldShowWhatsNew(version) || navigator.stack.any { it is Destination.WhatsNew }) return@LaunchedEffect
                WhatsNewSession.action = null
                navigator.navigate(Destination.WhatsNew(version))
                Analytics.track(AnalyticsEvent.WhatsNewViewed(version))
                Analytics.screen(AnalyticsScreen.WhatsNew)
            }
        }
    }
    // Closed, however: seen, tracked, and the tour follows once. After Try
    // Worship Mode it waits for church mode to close (TourHost).
    LaunchedEffect(Unit) {
        var wasShown = navigator.stack.any { it is Destination.WhatsNew }
        snapshotFlow { navigator.stack.any { it is Destination.WhatsNew } }.distinctUntilChanged().collect { shown ->
            if (wasShown && !shown) {
                settings.markWhatsNewSeen(version)
                Analytics.track(AnalyticsEvent.WhatsNewDismissed(version, WhatsNewSession.action ?: WhatsNewAction.Dismissed))
                WhatsNewSession.action = null
                tour.offerAfterWhatsNew()
            }
            wasShown = shown
        }
    }
}

/** The scrolling page. */
@Composable
fun WhatsNewContent(services: AppServices, navigator: AppNavigator) {
    WhatsNewPage(WhatsNewAndroidFeatures)
}

/** The pinned buttons: Try Worship Mode (church mode, felt) and Continue. */
@Composable
fun WhatsNewDrawerActions(services: AppServices, navigator: AppNavigator, onClose: () -> Unit) {
    WhatsNewActions(
        onPrimary = {
            // Only the primary action is felt: it leads somewhere (church mode).
            Haptics.play(HapticEvent.MediumImpact)
            WhatsNewSession.action = WhatsNewAction.Primary
            onClose()
            navigator.openChurchMode("whats_new")
        },
        onContinue = {
            WhatsNewSession.action = WhatsNewAction.Continue
            onClose()
        },
    )
}
