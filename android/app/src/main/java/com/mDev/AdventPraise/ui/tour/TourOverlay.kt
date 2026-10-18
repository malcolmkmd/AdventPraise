// OWNER: shell
package com.mDev.AdventPraise.ui.tour

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * The onboarding tour's spotlight over the reader (TourModel, TourOverlay,
 * TourRootHost): 8 steps. Drawn over everything but the sheets; [onFinish] ends it.
 */
@Composable
fun TourOverlay(services: AppServices, navigator: AppNavigator, source: String, onFinish: () -> Unit) {
}
