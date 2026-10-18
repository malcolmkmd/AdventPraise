package com.mDev.AdventPraise.ui.root

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.more.MoreScreen
import com.mDev.AdventPraise.ui.more.ShellLayer
import com.mDev.AdventPraise.ui.reader.ReaderScreen
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.VesperTheme

/**
 * The whole app (RootView): the reader on the person's reading surface, and over
 * it everything the navigator presents, each the way iOS presents it. The splash
 * covers it once on launch. Back closes what is open, one thing at a time, then
 * leaves the app.
 *
 * Layers, bottom to top: the reader (or the first milestone's hymn list), the
 * navigator's stack (sheets, covers, drawers, dialogs), then the shell's layer:
 * What's New's launcher and the tour's spotlight, over every sheet.
 */
@Composable
fun AdventPraiseRoot(services: AppServices, splash: Boolean = true) {
    val model = services.reader
    val store = services.store
    val navigator = services.navigator
    val barRequests = remember { SystemBarRequests() }
    VesperTheme(services.settings.surface) {
        val p = LocalSurface.current
        ApplySystemBars(barRequests, surfaceIsDark = p.isDark)
        CompositionLocalProvider(
            LocalAppNavigator provides navigator,
            LocalSystemBarRequests provides barRequests,
        ) {
            SplashReveal(enabled = splash) {
                LaunchedEffect(Unit) { Analytics.screen("reader") }
                Box(Modifier.fillMaxSize().background(p.background)) {
                    when (model.screen) {
                        Screen.Reader -> ReaderScreen(services)
                        Screen.More -> MoreScreen(services)
                    }
                    // The reader's own chrome closes first: below the stack's handlers.
                    BackHandler(
                        enabled = navigator.stack.isEmpty() && model.paywall == null && model.document == null &&
                            (model.screen != Screen.Reader || model.isMenuOpen || model.lectern != LecternState.Collapsed || model.isFocused),
                    ) {
                        when {
                            model.screen != Screen.Reader -> model.screen = Screen.Reader
                            model.isMenuOpen -> model.closeMenu()
                            model.lectern != LecternState.Collapsed -> model.closeLectern()
                            else -> model.isFocused = false
                        }
                    }
                    PresentationHost(services, navigator)
                    // What's New, the tour's spotlight (over every sheet) and the paywall's analytics.
                    ShellLayer(services, navigator)
                }
            }
        }

        store.message?.let { text ->
            AlertDialog(
                onDismissRequest = { store.message = null },
                confirmButton = { TextButton(onClick = { store.message = null }) { Text("OK") } },
                title = { Text("Purchases") },
                text = { Text(text) },
            )
        }
    }
}
