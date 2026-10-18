// OWNER: shell
package com.mDev.AdventPraise.ui.about

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** About Advent Praise (AboutAppView): version, credits, links to the policy and terms. A More page. */
@Composable
fun AboutAppPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("About Advent Praise")
}
