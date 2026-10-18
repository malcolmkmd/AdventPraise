// OWNER: music
package com.mDev.AdventPraise.ui.pitchpipe

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** The pitch pipe (PitchPipeView): the hymn's starting notes. A More page or a drawer page. */
@Composable
fun PitchPipeScreen(services: AppServices, navigator: AppNavigator, hymnNumber: Int?) {
    PendingScreen("Pitch pipe")
}
