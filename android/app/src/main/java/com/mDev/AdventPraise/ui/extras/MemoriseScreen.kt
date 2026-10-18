// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/** Memorise a verse and its word-chip game (MemoryGameView, MemoryRound). A sheet with Done. */
@Composable
fun MemoriseScreen(services: AppServices, navigator: AppNavigator, source: String) {
    PendingScreen("Memorise a verse")
}
