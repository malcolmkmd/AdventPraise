package com.mDev.AdventPraise.ui.root

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.mDev.AdventPraise.ui.design.findActivity

/** Requests for dark (light-icon) or light system bars; the latest one wins. */
class SystemBarRequests {
    internal val requests = mutableStateListOf<Pair<Any, Boolean>>()
}

val LocalSystemBarRequests = staticCompositionLocalOf { SystemBarRequests() }

/**
 * Asks for system bars drawn for a dark ([dark] true: light icons) or light ground
 * while this is in the composition. Church mode, sheet music on black and the
 * Stage call it; the reading surface decides otherwise.
 */
@Composable
fun SystemBarsAppearance(dark: Boolean) {
    val requests = LocalSystemBarRequests.current
    val token = remember { Any() }
    DisposableEffect(dark) {
        requests.requests += token to dark
        onDispose { requests.requests.removeAll { it.first === token } }
    }
}

/** Applies the latest request, else the surface's own appearance (edge-to-edge, transparent bars). */
@Composable
internal fun ApplySystemBars(requests: SystemBarRequests, surfaceIsDark: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    val dark = requests.requests.lastOrNull()?.second ?: surfaceIsDark
    SideEffect {
        val window = view.context.findActivity()?.window ?: return@SideEffect
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
}
