package com.mDev.AdventPraise.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.legal.LegalScreen
import com.mDev.AdventPraise.ui.library.HymnListScreen
import com.mDev.AdventPraise.ui.paywall.PaywallScreen
import com.mDev.AdventPraise.ui.reader.ReaderScreen
import com.mDev.AdventPraise.ui.settings.MoreScreen
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.VesperTheme

/** The whole app, drawn on the person's reading surface. */
@Composable
fun AdventPraiseRoot(services: AppServices) {
    val model = services.reader
    val store = services.store
    VesperTheme(services.settings.surface) {
        val p = LocalSurface.current
        SystemBars(dark = p.isDark)
        LaunchedEffect(Unit) { Analytics.screen("reader") }

        Box(Modifier.fillMaxSize().background(p.background)) {
            when (model.screen) {
                Screen.Reader -> ReaderScreen(services)
                Screen.Hymns -> HymnListScreen(services)
                Screen.More -> MoreScreen(services)
            }
            PaywallLayer(services)
            DocumentLayer(services)
        }

        // Back: closes what is open, one thing at a time, then leaves the app.
        BackHandler(enabled = model.paywall == null && model.document == null &&
            (model.screen != Screen.Reader || model.isMenuOpen || model.lectern != LecternState.Collapsed || model.isFocused)) {
            when {
                model.screen != Screen.Reader -> { model.screen = Screen.Reader }
                model.isMenuOpen -> { model.closeMenu() }
                model.lectern != LecternState.Collapsed -> { model.closeLectern() }
                else -> { model.isFocused = false }
            }
        }

        store.message?.let { text ->
            AlertDialog(
                onDismissRequest = { store.message = null },
                confirmButton = { TextButton(onClick = { store.message = null }) { Text("OK") } },
                text = { Text(text) },
            )
        }
    }
}

/** The paywall over everything; paywall_viewed / paywall_dismissed as on iOS. */
@Composable
private fun PaywallLayer(services: AppServices) {
    val model = services.reader
    val store = services.store
    // Kept while the sheet slides away, so its copy doesn't change under it.
    var shown by remember { mutableStateOf(ProFeature.Player) }
    var viewed by remember { mutableStateOf<ProFeature?>(null) }
    val open = model.paywall
    val feature = open ?: shown
    SideEffect { if (open != null) shown = open }

    LaunchedEffect(open) {
        val v = viewed
        if (open != null && v == null) {
            viewed = open
            Analytics.track(AnalyticsEvent.PaywallViewed(open.analyticsName, model.paywallContext))
            Analytics.screen("paywall")
        } else if (open == null && v != null) {
            viewed = null
            Analytics.track(AnalyticsEvent.PaywallDismissed(v.analyticsName, model.paywallContext,
                if (store.isPro) "unlocked" else "closed"))
        }
    }
    // Pro closes any gate.
    LaunchedEffect(store.isPro) {
        if (store.isPro && model.paywall != null && model.paywall != ProFeature.Support) model.paywall = null
    }

    AnimatedVisibility(
        visible = open != null,
        enter = slideInVertically { it } + fadeIn(),
        exit = slideOutVertically { it } + fadeOut(),
    ) {
        PaywallScreen(services, feature) { model.paywall = null }
    }
    BackHandler(enabled = open != null) { model.paywall = null }
}

/** The Terms or the Privacy Policy, over everything (the paywall links to both). */
@Composable
private fun DocumentLayer(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    var shown by remember { mutableStateOf(LegalDocument.Terms) }
    val open = model.document
    val document = open ?: shown
    SideEffect { if (open != null) shown = open }
    AnimatedVisibility(
        visible = open != null,
        enter = slideInVertically { it } + fadeIn(),
        exit = slideOutVertically { it } + fadeOut(),
    ) {
        Box(Modifier.fillMaxSize().background(p.background)) {
            LegalScreen(document) { model.document = null }
        }
    }
    BackHandler(enabled = open != null) { model.document = null }
}

@Composable
private fun SystemBars(dark: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    SideEffect {
        val window = view.context.findActivity()?.window ?: return@SideEffect
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
}
