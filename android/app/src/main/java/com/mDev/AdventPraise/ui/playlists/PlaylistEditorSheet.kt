// OWNER: church
package com.mDev.AdventPraise.ui.playlists

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** A playlist's editor (PlaylistEditorView): reorder, remove, add by number, Play. A sheet. */
@Composable
fun PlaylistEditorSheet(services: AppServices, navigator: AppNavigator, playlistId: String) {
    PendingScreen("Playlist")
}

/** A playlist as a row, with its touch-and-hold menu (PlaylistSummaryRow). */
@Composable
fun PlaylistSummaryRow(services: AppServices, navigator: AppNavigator, playlistId: String) {
    PendingScreen("Playlist")
}
