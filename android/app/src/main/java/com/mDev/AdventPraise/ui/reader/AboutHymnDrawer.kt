// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * The root of the About this hymn drawer (AboutHymnDrawer.swift / AboutHymnView):
 * rows that push its pages with `navigator.navigate(Destination.HymnStory)` and so on.
 * The root host draws the drawer; this draws its root content.
 */
@Composable
fun AboutHymnRoot(services: AppServices, navigator: AppNavigator, source: String) {
    PendingScreen("About this hymn")
}
