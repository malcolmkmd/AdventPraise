// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Backspace
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Tag
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HymnRowItem
import com.mDev.AdventPraise.ui.design.rememberHaptic
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.delay

/**
 * The Lectern (ReaderToolbar on iOS): one floating capsule at the bottom,
 * under the thumb. The row is the spine: play, the hymn (opens the hymn
 * tray), jump (number pad and word search) and library (favourites).
 * Panels unfold upward out of the same surface.
 */
@Composable
fun Lectern(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val shape = RoundedCornerShape(if (model.lectern == LecternState.Collapsed) DS.Radius.dock else DS.Radius.panel)
    Box(
        Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .imePadding()
            .padding(horizontal = DS.Space.l)
            .padding(bottom = DS.Space.m),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Surface(
            shape = shape,
            color = p.elevated,
            shadowElevation = 10.dp,
            tonalElevation = 0.dp,
            modifier = Modifier
                .widthIn(max = DS.Space.lecternMaxWidth)
                .fillMaxWidth()
                .border(1.dp, p.foreground.copy(alpha = DS.Fill.hairline), shape),
        ) {
            Column {
                AnimatedVisibility(
                    visible = model.lectern != LecternState.Collapsed,
                    enter = expandVertically(expandFrom = Alignment.Bottom) + fadeIn(),
                    exit = shrinkVertically(shrinkTowards = Alignment.Bottom) + fadeOut(),
                ) {
                    AnimatedContent(
                        targetState = model.lectern,
                        transitionSpec = { fadeIn() togetherWith fadeOut() },
                        label = "lectern-panel",
                    ) { state ->
                        Box(Modifier.padding(start = DS.Space.panel, end = DS.Space.panel, top = DS.Space.panel)) {
                            when (state) {
                                LecternState.Hymn -> HymnTray(services)
                                LecternState.Pad -> NumberPadPanel(services)
                                LecternState.Search -> SearchPanel(services)
                                LecternState.Library -> LibraryPanel(services)
                                LecternState.Collapsed -> Box(Modifier.height(1.dp))
                            }
                        }
                    }
                }
                LecternRow(services)
            }
        }
    }
}

@Composable
private fun LecternRow(services: AppServices) {
    val model = services.reader
    val store = services.store
    val player = services.player
    val freePlays = services.freePlays
    val p = LocalSurface.current
    val haptic = rememberHaptic(services.settings.haptics)
    val hymnal = model.hymnal
    val hymn = model.hymn
    Row(
        Modifier.fillMaxWidth().height(DS.Size.lecternRow).padding(horizontal = DS.Space.s),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        if (hymnal != null && hymn != null && hymn.hasAccompaniment) {
            val playing = player.isPlayingHymn(hymnal.id, hymn)
            val locked = !store.isPro && freePlays.isUsedUp && !player.isLoaded(hymnal.id, hymn)
            Box(
                Modifier
                    .size(DS.Size.hitTarget)
                    .clip(CircleShape)
                    .background(p.tint)
                    .clickable {
                        haptic()
                        when {
                            playing -> player.pause()
                            player.isLoaded(hymnal.id, hymn) -> player.resume()
                            locked -> {
                                Analytics.track(AnalyticsEvent.PlayLimitPaywallShown(hymn.number))
                                model.showPaywall(ProFeature.Player)
                            }
                            else -> {
                                if (player.start(hymnal.id, hymn) && !store.isPro) {
                                    freePlays.spend()
                                    Analytics.track(AnalyticsEvent.FreePlayUsed(hymn.number, freePlays.remaining))
                                }
                            }
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                    contentDescription = if (playing) "Pause" else "Play",
                    tint = p.onTint,
                )
                if (locked) {
                    Icon(Icons.Rounded.Lock, contentDescription = "Pro", tint = p.onTint,
                        modifier = Modifier.align(Alignment.BottomEnd).padding(4.dp).size(11.dp))
                }
            }
        }
        // The hymn: opens the hymn tray.
        Row(
            Modifier
                .weight(1f)
                .height(DS.Size.hitTarget)
                .clip(RoundedCornerShape(DS.Radius.capsule))
                .background(if (model.lectern == LecternState.Hymn) p.tint.copy(alpha = 0.10f) else Color.Transparent)
                .clickable { haptic(); model.openLectern(LecternState.Hymn) }
                .padding(horizontal = DS.Space.s),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
        ) {
            if (hymn != null) {
                Text(hymn.number.toString(), style = DS.Type.numeral, color = p.brass)
                Column(Modifier.weight(1f)) {
                    Text(hymn.title, style = DS.Type.rowTitle, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(
                        if (player.isPlaying && hymnal != null && player.isLoaded(hymnal.id, hymn)) "Playing" else hymnal?.name.orEmpty(),
                        style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        LecternButton(Icons.Rounded.Tag, "Go to hymn number",
            isOn = model.lectern == LecternState.Pad || model.lectern == LecternState.Search) {
            haptic()
            if (model.lectern == LecternState.Pad || model.lectern == LecternState.Search) model.closeLectern()
            else model.openLectern(LecternState.Pad)
        }
        LecternButton(Icons.Rounded.BookmarkBorder, "Library", isOn = model.lectern == LecternState.Library) {
            haptic()
            if (model.lectern == LecternState.Library) model.closeLectern() else model.openLectern(LecternState.Library)
        }
    }
}

@Composable
private fun LecternButton(icon: ImageVector, label: String, isOn: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier
            .size(DS.Size.hitTarget)
            .clip(CircleShape)
            .background(if (isOn) p.tint.copy(alpha = 0.10f) else Color.Transparent)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = if (isOn) p.tint else p.foreground)
    }
}

// MARK: - Hymn tray

@Composable
private fun HymnTray(services: AppServices) {
    val model = services.reader
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            TrayTile(
                if (model.isFavourite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                if (model.isFavourite) "Saved" else "Save",
                isOn = model.isFavourite,
                modifier = Modifier.weight(1f),
            ) { model.toggleFavourite() }
            TrayTile(Icons.AutoMirrored.Rounded.List, "All hymns", modifier = Modifier.weight(1f)) {
                model.closeLectern()
                model.screen = Screen.Hymns
            }
            TrayTile(Icons.Rounded.MoreHoriz, "More", modifier = Modifier.weight(1f)) {
                model.closeLectern()
                model.screen = Screen.More
            }
        }
    }
}

@Composable
private fun TrayTile(icon: ImageVector, label: String, modifier: Modifier = Modifier, isOn: Boolean = false, onClick: () -> Unit) {
    val p = LocalSurface.current
    Column(
        modifier
            .clip(RoundedCornerShape(DS.Radius.tile))
            .background(if (isOn) p.brass.copy(alpha = DS.Fill.tintOn) else p.foreground.copy(alpha = DS.Fill.inset))
            .clickable(onClick = onClick)
            .padding(vertical = DS.Space.m),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.xxs),
    ) {
        Icon(icon, contentDescription = null, tint = if (isOn) p.brass else p.foreground)
        Text(label, style = DS.Type.caption, color = p.foreground)
    }
}

// MARK: - Number pad

@Composable
private fun NumberPadPanel(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val haptic = rememberHaptic(services.settings.haptics)
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        // The readout: the number typed and the title it resolves to.
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(DS.Radius.tile))
                .background(p.foreground.copy(alpha = DS.Fill.inset)).padding(DS.Space.m),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Text(model.digits.ifEmpty { "—" }, style = DS.Type.padReadout, color = p.brass)
            val preview = model.previewHymn
            Text(
                when {
                    model.digits.isEmpty() -> "Type a hymn number"
                    preview != null -> preview.title
                    else -> "No hymn ${model.digits}"
                },
                style = DS.Type.rowTitle, color = if (preview != null) p.foreground else p.secondary,
                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
            )
        }
        if (model.recents.isNotEmpty() && model.digits.isEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
                Eyebrow("Recent", p.secondary)
                model.recents.forEach { n ->
                    Text(
                        n.toString(), style = DS.Type.numeral, color = p.brass,
                        modifier = Modifier.clip(RoundedCornerShape(DS.Radius.chip))
                            .background(p.brass.copy(alpha = DS.Fill.tintSelected))
                            .clickable { haptic(); model.open(n, "numpad") }
                            .padding(horizontal = DS.Space.m, vertical = DS.Space.xxs),
                    )
                }
            }
        }
        val keys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "Go")
        keys.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                row.forEach { key ->
                    PadKey(key, Modifier.weight(1f), enabled = key != "Go" || model.previewHymn != null) {
                        haptic()
                        when (key) {
                            "⌫" -> model.backspace()
                            "Go" -> model.openPreview()
                            else -> model.push(key.first())
                        }
                    }
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(DS.Radius.key)).clickable { model.openLectern(LecternState.Search) }
                .padding(vertical = DS.Space.s),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Rounded.Search, contentDescription = null, tint = p.tint, modifier = Modifier.size(18.dp))
            Text("  Search words", style = DS.Type.label, color = p.tint)
        }
    }
}

@Composable
private fun PadKey(key: String, modifier: Modifier, enabled: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    val isGo = key == "Go"
    Box(
        modifier
            .height(DS.Size.padKey)
            .clip(RoundedCornerShape(DS.Radius.key))
            .background(if (isGo) p.tint.copy(alpha = if (enabled) 1f else DS.Fill.disabled) else p.foreground.copy(alpha = DS.Fill.inset))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        when (key) {
            "⌫" -> Icon(Icons.AutoMirrored.Rounded.Backspace, contentDescription = "Delete", tint = p.foreground)
            "Go" -> Text("Go", style = DS.Type.button, color = p.onTint)
            else -> Text(key, style = DS.Type.padDigit, color = p.foreground)
        }
    }
}

// MARK: - Search

@Composable
private fun SearchPanel(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val focus = remember { FocusRequester() }
    val hits = model.searchHits()
    val scope = if (model.searchLyrics) "lyrics" else "titles"
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    // Once typing pauses: how long the query was and what it found, never the words.
    LaunchedEffect(model.query, model.searchLyrics) {
        val trimmed = model.query.trim()
        if (trimmed.isEmpty()) return@LaunchedEffect
        delay(1500)
        Analytics.track(AnalyticsEvent.SearchPerformed("lectern", scope, trimmed.length, hits.size, trimmed.toIntOrNull() != null))
    }
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        OutlinedTextField(
            value = model.query,
            onValueChange = { model.query = it },
            placeholder = { Text("Number, title or words") },
            leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
            singleLine = true,
            shape = RoundedCornerShape(DS.Radius.tile),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {
                hits.firstOrNull()?.let { model.open(it.hymn.number, "search") }
            }),
            modifier = Modifier.fillMaxWidth().focusRequester(focus),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            ScopeChip("Lyrics", model.searchLyrics) { model.searchLyrics = true }
            ScopeChip("Titles", !model.searchLyrics) { model.searchLyrics = false }
        }
        LazyColumn(Modifier.heightIn(max = 300.dp)) {
            itemsIndexed(hits) { index, hit ->
                HymnRowItem(hit.hymn, isCurrent = hit.hymn.number == model.hymn?.number,
                    isFavourite = model.isFavouriteNumber(hit.hymn.number), snippet = hit.snippet) {
                    Analytics.track(AnalyticsEvent.SearchResultOpened("lectern", scope, index + 1))
                    model.open(hit.hymn.number, "search")
                }
            }
        }
        if (model.query.trim().length >= 2 && hits.isEmpty()) {
            Text("No hymns match “${model.query.trim()}”.", style = DS.Type.detail, color = p.secondary,
                modifier = Modifier.padding(DS.Space.s))
        }
    }
}

@Composable
fun ScopeChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Text(
        label,
        style = DS.Type.label,
        color = if (selected) p.tint else p.secondary,
        modifier = Modifier
            .clip(RoundedCornerShape(DS.Radius.chip))
            .background(if (selected) p.tint.copy(alpha = DS.Fill.tintSelected) else p.foreground.copy(alpha = DS.Fill.inset))
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
    )
}

// MARK: - Library

@Composable
private fun LibraryPanel(services: AppServices) {
    val model: ReaderModel = services.reader
    val p = LocalSurface.current
    val favourites = model.favouriteHymns
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Text("Favourites", style = DS.Type.panelTitle, color = p.foreground, modifier = Modifier.padding(start = DS.Space.s))
        if (favourites.isEmpty()) {
            Text("Save a hymn from the hymn tray and it appears here.", style = DS.Type.detail, color = p.secondary,
                modifier = Modifier.padding(DS.Space.s))
        } else {
            LazyColumn(Modifier.heightIn(max = 300.dp)) {
                items(favourites, key = { it.number }) { hymn ->
                    HymnRowItem(hymn, isCurrent = hymn.number == model.hymn?.number, isFavourite = true) {
                        model.open(hymn.number, "favourites")
                    }
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(DS.Radius.key))
                .clickable { model.closeLectern(); model.screen = Screen.Hymns }.padding(vertical = DS.Space.s),
            horizontalArrangement = Arrangement.Center,
        ) {
            Text("All hymns", style = DS.Type.label, color = p.tint)
        }
    }
}
