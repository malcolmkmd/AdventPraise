// OWNER: shell
package com.mDev.AdventPraise.ui.more

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.PaywallContext
import com.mDev.AdventPraise.analytics.PaywallOutcome
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.ProPaywallRule
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.tour.TourHost
import com.mDev.AdventPraise.ui.whatsnew.WhatsNewLauncher
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull

/**
 * The shell's part of the root, mounted once over the presentation host:
 * What's New once per version, the tour's spotlight, and the paywall's
 * analytics. It also carries the first milestone's model fields into the
 * navigator (`reader.showPaywall`, `reader.document`, `Screen.More`), so gates written
 * against ReaderModel (church mode's TV, the player) open the stacked paywall.
 */
@Composable
fun ShellLayer(services: AppServices, navigator: AppNavigator) {
    val reader = services.reader
    val store = services.store

    // ReaderModel.showPaywall → the paywall in the stack. Pro never sees it (ProPaywallRule).
    LaunchedEffect(Unit) {
        snapshotFlow { reader.paywall }.filterNotNull().collect { feature ->
            val context = reader.paywallContext
            reader.paywall = null
            if (ProPaywallRule.presents(feature, true, store.entitlements)) navigator.openPaywall(feature, context)
        }
    }
    // The first milestone's `reader.screen = Screen.More` (the tray's More tile) → More's sheet.
    LaunchedEffect(Unit) {
        snapshotFlow { reader.screen == Screen.More }.collect { more ->
            if (more) { reader.screen = Screen.Reader; navigator.openMore() }
        }
    }
    // ReaderModel.document → the Terms or the Privacy Policy as More's pages.
    LaunchedEffect(Unit) {
        snapshotFlow { reader.document }.filterNotNull().collect { document ->
            reader.document = null
            navigator.navigate(if (document == LegalDocument.Terms) Destination.Terms else Destination.Privacy)
        }
    }
    // paywall_viewed when it shows, paywall_dismissed with how it ended when it goes.
    LaunchedEffect(Unit) {
        snapshotFlow { navigator.stack.lastOrNull { it is Destination.Paywall } as Destination.Paywall? }
            .distinctUntilChanged()
            .collect { current ->
                val viewed = PaywallSession.viewed
                if (current != null && viewed == null) {
                    if (!store.isPro) {
                        PaywallSession.viewed = current
                        Analytics.track(AnalyticsEvent.PaywallViewed(current.proFeature, current.paywallContext))
                        Analytics.screen(AnalyticsScreen.Paywall)
                    }
                } else if (current == null && viewed != null) {
                    PaywallSession.viewed = null
                    val feature = viewed.proFeature
                    Analytics.track(AnalyticsEvent.PaywallDismissed(feature, viewed.paywallContext,
                        if (store.unlocks(feature)) PaywallOutcome.Unlocked else PaywallOutcome.Closed))
                }
            }
    }

    WhatsNewLauncher(services, navigator)
    TourHost(services, navigator)
}

/** The paywall `paywall_viewed` was sent for, until `paywall_dismissed`. Outlives the activity. */
private object PaywallSession {
    var viewed: Destination.Paywall? = null
}

private val Destination.Paywall.proFeature: ProFeature
    get() = ProFeature.entries.firstOrNull { it.analyticsName == feature } ?: ProFeature.Support

private val Destination.Paywall.paywallContext: PaywallContext
    get() = PaywallContext.entries.firstOrNull { it.key == context } ?: PaywallContext.Reader
