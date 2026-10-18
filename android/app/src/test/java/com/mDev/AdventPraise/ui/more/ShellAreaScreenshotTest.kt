package com.mDev.AdventPraise.ui.more

import android.app.Application
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dialpad
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.analytics.TourSource
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.billing.FakePurchasesClient
import com.mDev.AdventPraise.billing.PreviewPurchasesClient
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.WhatsNewSheet
import com.mDev.AdventPraise.ui.legal.HYMN_CONTENT_SECTION
import com.mDev.AdventPraise.ui.legal.LegalPage
import com.mDev.AdventPraise.ui.paywall.LocalStillMotion
import com.mDev.AdventPraise.ui.paywall.PaywallContent
import com.mDev.AdventPraise.ui.support.SupportContent
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.VesperTheme
import com.mDev.AdventPraise.ui.tour.TourModel
import com.mDev.AdventPraise.ui.tour.TourSpotlight
import com.mDev.AdventPraise.ui.tour.TourTarget
import com.mDev.AdventPraise.ui.tour.TourTargets
import com.mDev.AdventPraise.ui.tour.tourTarget
import com.mDev.AdventPraise.ui.whatsnew.WhatsNewAndroidFeatures
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * JVM screenshots of the shell area: More (free and subscriber), the Pro
 * paywall (with its trial, and when the price couldn't load), Support, the
 * Terms at "Hymn content and ownership", the tour's first stage and What's
 * New, on paper (light) and black (dark). The scenery is still: the settled
 * end state. `./gradlew recordRoborazziDebug --tests '*ShellAreaScreenshotTest'`.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi", application = Application::class)
class ShellAreaScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun shot(name: String, surface: ReadingSurface, content: @Composable () -> Unit) {
        compose.setContent {
            VesperTheme(surface) {
                CompositionLocalProvider(LocalStillMotion provides true) {
                    Box(Modifier.fillMaxSize().background(LocalSurface.current.background)) { content() }
                }
            }
        }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("src/test/screenshots/shell_${name}_${if (surface.isDark) "dark" else "light"}.png")
    }

    private fun store(client: com.mDev.AdventPraise.billing.PurchasesClient = PreviewPurchasesClient(), forced: Entitlements? = null) =
        PurchaseStore(client, CoroutineScope(Dispatchers.Unconfined), forced = forced).apply {
            start()
            runBlocking { loadStorefront() }
        }

    // More

    private fun more(name: String, surface: ReadingSurface, entitlements: Entitlements, freePlaysLeft: Int) = shot(name, surface) {
        MoreContent(
            entitlements = entitlements, freePlaysLeft = freePlaysLeft,
            repeatChorus = false, onRepeatChorus = {}, haptics = true, onHaptics = {},
            sharesUsage = true, onSharesUsage = {}, pitchDetail = "D4", showsFeatureBoard = false, actions = MoreActions(),
        )
    }

    @Test fun moreFreeLight() = more("more_free", ReadingSurface.Paper, Entitlements.none, 3)
    @Test fun moreFreeDark() = more("more_free", ReadingSurface.Black, Entitlements.none, 3)
    @Test fun moreSubscriberLight() = more("more_subscriber", ReadingSurface.Paper, Entitlements(setOf("pro"), setOf("ap_pro_annual")), 5)
    @Test fun moreSubscriberDark() = more("more_subscriber", ReadingSurface.Black, Entitlements(setOf("pro"), setOf("ap_pro_annual")), 5)

    // The paywall

    private fun paywall(name: String, surface: ReadingSurface, store: PurchaseStore) = shot(name, surface) {
        PaywallContent(store, ProFeature.Player, onClose = {}, onPurchase = {})
    }

    @Test fun paywallTrialLight() = paywall("paywall_trial", ReadingSurface.Paper, store())
    @Test fun paywallTrialDark() = paywall("paywall_trial", ReadingSurface.Black, store())
    @Test fun paywallPriceFailedLight() = paywall("paywall_price_failed", ReadingSurface.Paper, store(FakePurchasesClient().apply { offering = null }))
    @Test fun paywallPriceFailedDark() = paywall("paywall_price_failed", ReadingSurface.Black, store(FakePurchasesClient().apply { offering = null }))

    // Support

    @Test fun supportLight() = shot("support", ReadingSurface.Paper) { SupportContent(store(), onClose = {}, onTip = {}) }
    @Test fun supportDark() = shot("support", ReadingSurface.Black) { SupportContent(store(), onClose = {}, onTip = {}) }

    // Terms, at the shared hymn content section

    @Test fun termsLight() = shot("terms_hymn_content", ReadingSurface.Paper) { LegalPage(LegalDocument.Terms, startAt = HYMN_CONTENT_SECTION) }
    @Test fun termsDark() = shot("terms_hymn_content", ReadingSurface.Black) { LegalPage(LegalDocument.Terms, startAt = HYMN_CONTENT_SECTION) }

    // The tour's first stage, over a stand-in for the Lectern

    private fun tour(surface: ReadingSurface) {
        TourTargets.clear()
        val tour = TourModel(AppSettings(MemoryStore()), track = {}, haptic = {})
        tour.start(TourSource.Debug)
        shot("tour_first_stage", surface) {
            val p = LocalSurface.current
            Text("Watchman Blow The Gospel Trumpet", style = DS.Type.hymnTitle, color = p.foreground,
                modifier = Modifier.padding(start = DS.Space.gutter, top = 96.dp, end = DS.Space.gutter))
            Box(Modifier.fillMaxSize().navigationBarsPadding().padding(DS.Space.l), contentAlignment = Alignment.BottomStart) {
                Box(
                    Modifier.fillMaxWidth().background(p.elevated, CircleShape).padding(DS.Space.xs),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Box(Modifier.size(52.dp).tourTarget(TourTarget.Jump).background(p.tint.copy(alpha = 0.14f), CircleShape),
                        contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Dialpad, null, tint = p.tint)
                    }
                }
            }
            val inset = with(LocalDensity.current) { DS.Space.s.toPx() }
            TourSpotlight(tour, tour.stage!!, TourTargets[TourTarget.Jump]?.inflate(inset))
        }
    }

    @Test fun tourLight() = tour(ReadingSurface.Paper)
    @Test fun tourDark() = tour(ReadingSurface.Black)

    // What's New (always the Stage)

    @Test fun whatsNewLight() = shot("whats_new", ReadingSurface.Paper) { WhatsNewSheet({}, {}, features = WhatsNewAndroidFeatures) }
    @Test fun whatsNewDark() = shot("whats_new", ReadingSurface.Black) { WhatsNewSheet({}, {}, features = WhatsNewAndroidFeatures) }
}
