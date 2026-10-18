package com.mDev.AdventPraise.ui.root

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * What a debug launch asked for that the UI reads while it draws (iOS's
 * `DebugLaunch` statics). Only the debug build's `DebugLaunch` ever sets these;
 * in a release build they keep their defaults, so nothing here changes the app.
 */
object DebugOptions {
    /** `uiDebugNoSplash`: no launch splash. */
    var skipsSplash = false
    /** `uiDebugSplashSpeed`: the splash reveal's playback rate (0.05 to catch frames). */
    var splashSpeed = 1f
    /** `uiDebugChurchControls`: church mode's controls never auto-hide. */
    var keepsChurchControls = false
    /** `uiDebugExternal`: the worship display ("verse", "title" or "blank") drawn over the phone. */
    var external by mutableStateOf<String?>(null)
}
