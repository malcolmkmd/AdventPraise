// OWNER: music
package com.mDev.AdventPraise.ui.player

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/**
 * The accompaniment's controls in the Lectern (LecternPlayer.swift): play, tempo,
 * scrubbing, verse following. The reader's Lectern places it; nothing draws it yet.
 */
@Composable
fun LecternPlayer(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Player")
}
