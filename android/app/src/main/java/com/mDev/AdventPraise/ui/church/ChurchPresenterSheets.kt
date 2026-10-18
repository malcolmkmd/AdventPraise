// OWNER: church
package com.mDev.AdventPraise.ui.church

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** A notice on the worship display (ChurchAnnouncementSheet). */
@Composable
fun ChurchAnnouncementSheet(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Announcement")
}

/** A picture on the worship display (ChurchImageSheet). */
@Composable
fun ChurchImageSheet(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Image")
}

/** How to put the words on a TV (ScreenMirroringHelpSheet): Cast and second displays. */
@Composable
fun ScreenMirroringHelpSheet(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Show on a TV")
}
