// OWNER: music
package com.mDev.AdventPraise.ui.sheetmusic

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * The open hymn's sheet music on the whole screen (SheetMusicView): the packs in
 * assets (sheet-music-manifest.json), AndroidSVG, the sync timings, the Pro gate.
 * The root host draws the full-screen cover; [onClose] closes it.
 */
@Composable
fun SheetMusicScreen(services: AppServices, navigator: AppNavigator, source: String, onClose: () -> Unit) {
    PendingScreen("Sheet music")
}
