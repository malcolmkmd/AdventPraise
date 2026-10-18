// OWNER: church
package com.mDev.AdventPraise.ui.playlists

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * New Playlist / Rename Playlist (playlistNamePrompt): a name field with Create or
 * Save. The root host draws the dialog card; this draws its title, field and
 * buttons. [onDismiss] closes it.
 */
@Composable
fun PlaylistNameDialog(services: AppServices, navigator: AppNavigator, playlistId: String?, onDismiss: () -> Unit) {
    PendingScreen(if (playlistId == null) "New Playlist" else "Rename Playlist")
}

/** Delete “name”? The hymns stay in the hymnal; only this playlist is removed. Inside the root's dialog card. */
@Composable
fun PlaylistDeleteDialog(services: AppServices, navigator: AppNavigator, playlistId: String, onDismiss: () -> Unit) {
    PendingScreen("Delete playlist")
}
