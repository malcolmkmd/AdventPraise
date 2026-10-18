// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.Passage
import com.mDev.AdventPraise.extras.PassageHymns
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS

/** Passages grouped by book, books in canonical order, filtered by [query] (ScriptureIndexPage.books). */
fun scriptureBooks(index: List<PassageHymns>, query: String): List<Pair<String, List<PassageHymns>>> {
    val q = query.trim()
    val filtered = if (q.isEmpty()) index else index.filter { it.passage.reference.contains(q, ignoreCase = true) }
    val groups = mutableListOf<Pair<String, MutableList<PassageHymns>>>()
    for (entry in filtered) {
        if (groups.lastOrNull()?.first == entry.passage.book) groups.last().second += entry
        else groups += entry.passage.book to mutableListOf(entry)
    }
    return groups
}

/** The Scripture index (ScriptureLinks): every linked passage, by book; each opens its hymns. A More page. */
@Composable
fun ScriptureIndexPage(services: AppServices, navigator: AppNavigator) {
    val hymnal = services.reader.hymnal ?: return
    val index = remember(hymnal.id) { services.catalogs.scripture.index(hymnal.id) }
    var query by rememberSaveable { mutableStateOf("") }
    ScriptureIndexContent(hymnal, index, query, { query = it }) { navigator.openPassage(it.id, it.reference) }
    AnalyticsScreenEffect(AnalyticsScreen.ScriptureIndex)
}

@Composable
fun ScriptureIndexContent(
    hymnal: Hymnal,
    index: List<PassageHymns>,
    query: String,
    onQueryChange: (String) -> Unit,
    onOpenPassage: (Passage) -> Unit,
) {
    val books = remember(index, query) { scriptureBooks(index, query) }
    DrawerPageLayout(Modifier.padding(vertical = DS.Space.m)) {
        DrawerSearchField("Book or reference", query, onQueryChange)
        if (books.isEmpty()) {
            DrawerNote(
                if (query.isEmpty()) "Passages haven’t been linked to hymns in ${hymnal.name} yet."
                else "No linked passage matches “$query”.",
            )
        }
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            books.forEach { (book, entries) ->
                ExtrasGroup(book) {
                    entries.forEachIndexed { i, entry ->
                        ExtrasRow(
                            title = entry.passage.reference,
                            icon = Icons.AutoMirrored.Rounded.MenuBook,
                            detail = hymnCount(entry.numbers.size),
                            isLast = i == entries.lastIndex,
                            onClick = { onOpenPassage(entry.passage) },
                        )
                    }
                }
            }
        }
    }
}
