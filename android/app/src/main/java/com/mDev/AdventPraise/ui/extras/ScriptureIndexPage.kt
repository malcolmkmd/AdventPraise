// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** The Scripture index (ScriptureLinks): passages, each opening its hymns. A More page. */
@Composable
fun ScriptureIndexPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Scripture index")
}
