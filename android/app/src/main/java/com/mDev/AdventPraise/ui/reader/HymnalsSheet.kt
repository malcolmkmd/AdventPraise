// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** All hymnals with purchase state, as a sheet (HymnalStorePicker; iPad sidebar's Hymnals). */
@Composable
fun HymnalsSheet(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Hymnals")
}
