// OWNER: shell
package com.mDev.AdventPraise.ui.support

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** Support Advent Praise: the tips, in the paywall's chrome (SupportView). A sheet. */
@Composable
fun SupportScreen(services: AppServices, navigator: AppNavigator, onClose: () -> Unit) {
    PendingScreen("Support Advent Praise")
}

/** Thanks for a tip (TipThankYouSheet). */
@Composable
fun TipThanksSheet(services: AppServices, navigator: AppNavigator, tipId: String, onClose: () -> Unit) {
    PendingScreen("Thank you")
}
