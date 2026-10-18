package com.mDev.AdventPraise.ui.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HymnRowItem
import com.mDev.AdventPraise.ui.design.SectionTitle
import com.mDev.AdventPraise.ui.reader.ScopeChip
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.delay

/**
 * Every hymn in the open hymnal, with search by number, title or words
 * (the iPad sidebar's list on iOS): favourites first, then the hymnal in
 * order. Opening one goes back to the reader.
 */
@Composable
fun HymnListScreen(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val hymnal = model.hymnal
    var query by rememberSaveable { mutableStateOf("") }
    val hits = remember(query, hymnal, model.searchLyrics) { model.searchHits(query) }
    val searching = query.trim().isNotEmpty()
    val scope = if (model.searchLyrics) "lyrics" else "titles"

    LaunchedEffect(Unit) { Analytics.screen("library") }
    LaunchedEffect(query, model.searchLyrics) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return@LaunchedEffect
        delay(1500)
        Analytics.track(AnalyticsEvent.SearchPerformed("sidebar", scope, trimmed.length, hits.size, trimmed.toIntOrNull() != null))
    }

    fun open(number: Int, source: String) {
        if (model.open(number, source)) model.screen = Screen.Reader
    }

    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars).imePadding()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = DS.Space.s, vertical = DS.Space.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(DS.Size.hitTarget).clip(CircleShape).clickable { model.screen = Screen.Reader },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back to the hymn", tint = p.foreground)
            }
            Column(Modifier.weight(1f).padding(start = DS.Space.xs)) {
                Text(hymnal?.name.orEmpty(), style = DS.Type.sheetTitle, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Eyebrow("${hymnal?.info?.language.orEmpty()} · ${hymnal?.hymns?.size ?: 0} hymns", p.secondary)
            }
        }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Number, title or words") },
            leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
            trailingIcon = {
                if (query.isNotEmpty()) {
                    Box(Modifier.size(DS.Size.hitTarget).clip(CircleShape).clickable { query = "" }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Close, contentDescription = "Clear")
                    }
                }
            },
            singleLine = true,
            shape = RoundedCornerShape(DS.Radius.tile),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.l),
        )
        if (searching) {
            Row(Modifier.padding(horizontal = DS.Space.l, vertical = DS.Space.s), horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                ScopeChip("Lyrics", model.searchLyrics) { model.searchLyrics = true }
                ScopeChip("Titles", !model.searchLyrics) { model.searchLyrics = false }
            }
        }
        val favourites = model.favouriteHymns
        LazyColumn(
            Modifier.fillMaxWidth().weight(1f),
            contentPadding = PaddingValues(
                start = DS.Space.m, end = DS.Space.m, bottom = 24.dp,
            ),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (searching) {
                itemsIndexed(hits) { index, hit ->
                    Box(Modifier.widthIn(max = DS.Space.readingMeasure)) {
                        HymnRowItem(hit.hymn, hit.hymn.number == model.hymn?.number,
                            model.isFavouriteNumber(hit.hymn.number), hit.snippet) {
                            Analytics.track(AnalyticsEvent.SearchResultOpened("sidebar", scope, index + 1))
                            open(hit.hymn.number, "search")
                        }
                    }
                }
                if (hits.isEmpty() && query.trim().length >= 2) {
                    item { Text("No hymns match “${query.trim()}”.", style = DS.Type.detail, color = p.secondary, modifier = Modifier.padding(DS.Space.l)) }
                }
            } else {
                if (favourites.isNotEmpty()) {
                    item { Box(Modifier.widthIn(max = DS.Space.readingMeasure).fillMaxWidth()) { SectionTitle("Favourites") } }
                    items(favourites, key = { "fav-${it.number}" }) { hymn ->
                        Box(Modifier.widthIn(max = DS.Space.readingMeasure)) {
                            HymnRowItem(hymn, hymn.number == model.hymn?.number, true) { open(hymn.number, "favourites") }
                        }
                    }
                }
                item { Box(Modifier.widthIn(max = DS.Space.readingMeasure).fillMaxWidth()) { SectionTitle("Hymns") } }
                itemsIndexed(hymnal?.hymns.orEmpty()) { _, hymn ->
                    Box(Modifier.widthIn(max = DS.Space.readingMeasure)) {
                        HymnRowItem(hymn, hymn.number == model.hymn?.number, model.isFavouriteNumber(hymn.number)) {
                            open(hymn.number, "sidebar")
                        }
                    }
                }
            }
            item { Box(Modifier.windowInsetsPadding(WindowInsets.navigationBars)) }
        }
    }
}
