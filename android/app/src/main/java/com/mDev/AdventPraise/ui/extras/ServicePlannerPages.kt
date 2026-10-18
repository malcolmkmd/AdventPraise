// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** The service planner (ServicePlannerView): saved plans. A More page. */
@Composable
fun ServicePlannerPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Service planner")
}

/** One service plan: its hymns, roles and date; Start runs it in church mode. A More page. */
@Composable
fun ServicePlanPage(services: AppServices, navigator: AppNavigator, planId: String) {
    PendingScreen("Service plan")
}
