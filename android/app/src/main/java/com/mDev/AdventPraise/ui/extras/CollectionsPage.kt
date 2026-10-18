// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.HymnCollection
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS

/**
 * The SDA Hymnal's sections (CollectionsView, HymnCollections): Worship, Gospel…
 * A More page. Each pushes its hymns in the current hymnal.
 */
@Composable
fun CollectionsPage(services: AppServices, navigator: AppNavigator) {
    val hymnal = services.reader.hymnal ?: return
    val all = services.catalogs.collections.all
    val available = remember(hymnal.id) { services.catalogs.collections.available(hymnal.id) }
    CollectionsContent(hymnal, available, loaded = all.isNotEmpty()) { navigator.openCollection(it.id, it.title) }
    AnalyticsScreenEffect(AnalyticsScreen.Collections)
}

@Composable
fun CollectionsContent(hymnal: Hymnal, collections: List<HymnCollection>, loaded: Boolean, onOpen: (HymnCollection) -> Unit) {
    DrawerPageLayout(Modifier.padding(vertical = DS.Space.m)) {
        if (collections.isEmpty()) {
            DrawerNote(
                if (!loaded) "Collections couldn’t be loaded."
                else "Collections follow the sections of the SDA Hymnal. They’re available for the SDA Hymnal and for Christ In Song in its languages, not for ${hymnal.name}.",
            )
        } else {
            ExtrasGroup {
                collections.forEachIndexed { i, collection ->
                    ExtrasRow(
                        title = collection.title,
                        icon = extrasIcon(collection.symbol),
                        detail = hymnCount(collection.numbers(hymnal.id).size),
                        isLast = i == collections.lastIndex,
                        onClick = { onOpen(collection) },
                    )
                }
            }
            DrawerNote("The sections of the Seventh-day Adventist Hymnal (1985). Hymns are placed by their SDA Hymnal number; hymns that aren’t in the SDA Hymnal aren’t in a section.")
        }
    }
}
