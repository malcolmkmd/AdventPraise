// OWNER: church
package com.mDev.AdventPraise.ui.church

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * Church mode (ChurchModeView + WorshipModeControls): one verse at a time, big and
 * high contrast, the queue, the TV (Presentation display and Google Cast). Pro-gated
 * TV. The root host draws the full-screen cover; [onClose] leaves church mode.
 */
@Composable
fun ChurchModeScreen(services: AppServices, navigator: AppNavigator, source: String, onClose: () -> Unit) {
    PendingScreen("Church mode")
}

/** The queue inside church mode (ChurchQueueList). */
@Composable
fun ChurchQueueList(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Queue")
}
