// OWNER: shell
package com.mDev.AdventPraise.ui.more

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** Vote on features (FeatureBoard), when a board is configured. A sheet over More. */
@Composable
fun FeatureBoardSheet(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Vote on features")
}
