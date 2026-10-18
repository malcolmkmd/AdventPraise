// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** Collections (CollectionsView, HymnCollections): Worship, Gospel… A More page. */
@Composable
fun CollectionsPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Collections")
}
