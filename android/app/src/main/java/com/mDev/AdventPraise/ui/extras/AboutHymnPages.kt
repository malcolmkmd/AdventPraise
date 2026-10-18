// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.PendingScreen
import com.mDev.AdventPraise.ui.root.AppNavigator

/*
 * The pages inside the About this hymn drawer (Extras/DrawerPages.swift, HymnStories.swift).
 * The drawer draws the bar with Back and the page title; these draw the page.
 */

/** The hymn's story (HymnStories). */
@Composable
fun HymnStoryPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Story")
}

/** Words and music: authors, composers, dates. */
@Composable
fun HymnCreditsPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Words and music")
}

@Composable
fun HymnSourcesPage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Sources")
}

/** The passages the hymn cites; each opens [PassageHymnsPage]. */
@Composable
fun HymnScripturePage(services: AppServices, navigator: AppNavigator) {
    PendingScreen("Scripture")
}

/** Hymns citing a passage (PassageHymnsPage), in the drawer or as a More page. */
@Composable
fun PassageHymnsPage(services: AppServices, navigator: AppNavigator, passageId: String, reference: String) {
    PendingScreen(reference)
}

/** A collection's hymns (CollectionHymnsPage), in the drawer or as a More page. */
@Composable
fun CollectionHymnsPage(services: AppServices, navigator: AppNavigator, collectionId: String, title: String) {
    PendingScreen(title)
}
