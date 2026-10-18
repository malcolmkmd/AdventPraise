// OWNER: reader
package com.mDev.AdventPraise.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.SearchScope
import com.mDev.AdventPraise.analytics.SearchSurface
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.ui.design.HymnRow
import com.mDev.AdventPraise.ui.design.HymnRowStyle
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.reader.LibraryPlaylistRow
import com.mDev.AdventPraise.ui.reader.summary
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.delay

/**
 * Every hymn in the open hymnal as a full screen (the hymn list destination):
 * the hymn list beside the reader on wide windows, given a bar with Done.
 */
@Composable
fun HymnListScreen(services: AppServices) {
    val navigator = LocalAppNavigator.current
    val p = LocalSurface.current
    Column(Modifier.fillMaxSize().background(p.background).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).padding(horizontal = DS.Space.xs)) {
            Box(
                Modifier
                    .align(Alignment.CenterEnd)
                    .heightIn(min = DS.Size.hitTarget)
                    .clip(dsShape(DS.Radius.capsule))
                    .clickable(role = Role.Button) { navigator.dismiss(Destination.HymnList) }
                    .padding(horizontal = DS.Space.m),
                contentAlignment = Alignment.Center,
            ) { Text("Done", style = DS.Type.label, color = p.tint) }
        }
        HymnSidebar(services, Modifier.weight(1f), onOpened = { navigator.dismiss(Destination.HymnList) })
    }
}

/**
 * The hymn list beside the reader (HymnSidebar, iPad): search by number,
 * title or words; favourites and playlists first (hidden while searching),
 * where Pro and the tips live, then every hymn. The hymnal's name heads it,
 * with its Hymnals button.
 */
@Composable
fun HymnSidebar(services: AppServices, modifier: Modifier = Modifier, onOpened: () -> Unit = {}) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val p = LocalSurface.current
    val hymnal = model.hymnal ?: return
    var query by rememberSaveable { mutableStateOf("") }
    val searching = query.isNotBlank()
    val favouriteNumbers = model.favouriteNumbers
    val favourites = favouriteNumbers.toSet()
    val hymns: List<Hymn> = if (searching) hymnal.search(query, inLyrics = true).map { it.hymn } else hymnal.hymns

    // Once typing pauses: how long the query was and what it found, never the words.
    LaunchedEffect(query) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return@LaunchedEffect
        delay(1500)
        Analytics.track(AnalyticsEvent.SearchPerformed(SearchSurface.Sidebar, SearchScope.Lyrics, trimmed.length, hymns.size, trimmed.toIntOrNull() != null))
    }

    fun open(hymn: Hymn, rank: Int?) {
        if (rank != null) Analytics.track(AnalyticsEvent.SearchResultOpened(SearchSurface.Sidebar, SearchScope.Lyrics, rank + 1))
        if (model.open(hymn.number, if (searching) HymnSource.Search else HymnSource.Sidebar)) onOpened()
    }

    Column(modifier.background(p.background)) {
        Row(
            Modifier.fillMaxWidth().padding(start = DS.Space.l, end = DS.Space.xs, top = DS.Space.s),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(hymnal.name, style = DS.Type.display.copy(fontSize = DS.Type.sheetTitle.fontSize, lineHeight = DS.Type.sheetTitle.lineHeight),
                color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).semantics { heading() })
            Box(
                Modifier
                    .size(DS.Size.hitTarget)
                    .clip(dsShape(DS.Radius.capsule))
                    .clickable(role = Role.Button) { navigator.openHymnals() }
                    .clearAndSetSemantics { contentDescription = "Choose hymnal"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Language, null, tint = p.tint) }
        }
        SearchField(query, onChange = { query = it }, Modifier.padding(horizontal = DS.Space.m, vertical = DS.Space.s))
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = DS.Space.s, end = DS.Space.s, bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + DS.Space.l),
        ) {
            // Favourites and playlists first: below the full hymn list they were hundreds of rows down.
            if (!searching && favouriteNumbers.isNotEmpty()) {
                section("Favourites")
                items(favouriteNumbers.mapNotNull(hymnal::hymn), key = { "f${it.number}" }) { hymn ->
                    HymnRow(hymn.summary, onClick = { if (model.open(hymn.number, HymnSource.Favourites)) onOpened() }, isFavourite = true,
                        isCurrent = hymn.number == model.hymn?.number, style = HymnRowStyle.Plain, showsChevron = false)
                }
            }
            // Shown even when empty so New Playlist stays reachable.
            if (!searching) {
                section("Playlists")
                items(model.playlists, key = { "p${it.id}" }) { list ->
                    Box(Modifier.padding(horizontal = DS.Space.s)) { LibraryPlaylistRow(model, navigator, list, inset = false) }
                }
                item(key = "new") { SidebarButton("New Playlist", Icons.Rounded.Add) { model.newPlaylist(); navigator.newPlaylist() } }
                // Where Pro and the tips live on wide windows, beside More's rows.
                section("Advent Praise")
                item(key = "pro") { SidebarButton("Advent Praise Pro", Icons.Rounded.AutoAwesome) { navigator.openPaywall(ProFeature.Support, "reader") } }
                item(key = "support") { SidebarButton("Support Advent Praise", Icons.Rounded.FavoriteBorder) { navigator.openSupport() } }
            }
            section("Hymns")
            itemsIndexed(hymns, key = { _, h -> "h${h.number}" }) { rank, hymn ->
                HymnRow(hymn.summary, onClick = { open(hymn, if (searching) rank else null) },
                    isFavourite = hymn.number in favourites, isCurrent = hymn.number == model.hymn?.number,
                    style = HymnRowStyle.Plain, showsChevron = false)
            }
        }
    }
}

private fun LazyListScope.section(title: String) {
    item(key = "section-$title") {
        val p = LocalSurface.current
        Text(title, style = DS.Type.label, color = p.secondary,
            modifier = Modifier.padding(start = DS.Space.s, top = DS.Space.l, bottom = DS.Space.xs).semantics { heading() })
    }
}

@Composable
private fun SidebarButton(title: String, icon: ImageVector, onClick: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .clip(dsShape(DS.Radius.tile))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = DS.Space.s),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Icon(icon, null, tint = p.tint, modifier = Modifier.size(20.dp))
        Text(title, style = DS.Type.label, color = p.tint)
    }
}

/** "Number, title or words" (the sidebar's `.searchable`). */
@Composable
private fun SearchField(query: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 40.dp)
            .background(p.primary(DS.Fill.inset), dsShape(DS.Radius.key))
            .padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Icon(Icons.Rounded.Search, null, tint = p.secondary, modifier = Modifier.size(18.dp))
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (query.isEmpty()) Text("Number, title or words", style = DS.Type.body, color = p.secondary, maxLines = 1)
            BasicTextField(
                query, onChange, singleLine = true,
                textStyle = DS.Type.body.copy(color = p.foreground),
                cursorBrush = SolidColor(p.tint),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Search hymns" },
            )
        }
    }
}
