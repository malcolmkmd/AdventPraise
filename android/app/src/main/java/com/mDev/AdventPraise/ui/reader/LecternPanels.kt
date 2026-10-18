// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.PlaylistAdd
import androidx.compose.material.icons.automirrored.rounded.PlaylistAddCheck
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.FilterNone
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.SearchScope
import com.mDev.AdventPraise.analytics.SearchSurface
import com.mDev.AdventPraise.analytics.ToolSource
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.data.SearchHit
import com.mDev.AdventPraise.extras.ExtraSheet
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.LibraryTab
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.ui.extras.andList
import com.mDev.AdventPraise.ui.design.DSHymnSummary
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.GlassButtonKind
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.HymnNumberPad
import com.mDev.AdventPraise.ui.design.HymnRow
import com.mDev.AdventPraise.ui.design.HymnRowStyle
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.delay

/*
 * The panels that unfold out of the Lectern (LecternPanels.swift): the hymn
 * tray, the number pad, word search and the library (favourites and
 * playlists). They sit inside the Lectern's glass, so nothing in here draws
 * glass of its own. More opens in its own sheet.
 */

/** A hymn as a list row needs it (designSummary). */
val Hymn.summary: DSHymnSummary get() = DSHymnSummary(number, title, blocks.firstOrNull()?.lines?.firstOrNull())

/** Sends the screen once when it appears (`.analyticsScreen(_:)`). */
@Composable
internal fun ScreenEffect(screen: AnalyticsScreen) {
    LaunchedEffect(screen) { Analytics.screen(screen) }
}

// MARK: - Hymn tray

/**
 * What you do with the hymn on screen, one tap from the open tray: church
 * mode, Memorise, add to a playlist, save and More. Play is in the row below;
 * translation, theme and text are in the reader menu at the top, and sheet
 * music is the button beside it (when the hymn has some).
 */
@Composable
fun LecternHymnTray(services: AppServices) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val p = LocalSurface.current
    val number = model.hymn?.number ?: return
    val lists = model.playlists
    val inAny = lists.any { number in it.hymnNumbers }
    var choosing by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = DS.Space.panel, end = DS.Space.panel, top = DS.Space.panel, bottom = DS.Space.xs),
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        TrayTile("Church", Icons.Rounded.FilterNone, isOn = false, onColor = p.tint, Modifier.weight(1f),
            hint = "Shows one verse at a time, large, for singing together") {
            model.closeLectern()
            navigator.openChurchMode("tray")
        }
        TrayTile("Memorise", Icons.Rounded.Psychology, isOn = false, onColor = p.tint, Modifier.weight(1f),
            hint = "Learn a verse of this hymn by filling in its words") {
            model.closeLectern()
            Analytics.track(AnalyticsEvent.ToolOpened(ExtraSheet.Memory, ToolSource.Tray))
            navigator.openMemorise("tray")
        }
        TrayTile(
            "Playlist", if (inAny) Icons.AutoMirrored.Rounded.PlaylistAddCheck else Icons.AutoMirrored.Rounded.PlaylistAdd,
            isOn = inAny, onColor = p.tint, Modifier.weight(1f),
            spoken = "Add to playlist", value = if (inAny) "In a playlist" else null,
        ) {
            if (lists.isEmpty()) newPlaylist(model, navigator) else choosing = true
        }
        TrayTile(if (model.isFavourite) "Saved" else "Save", if (model.isFavourite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
            isOn = model.isFavourite, onColor = p.brass, Modifier.weight(1f)) { model.toggleFavourite() }
        TrayTile("More", Icons.Rounded.MoreHoriz, isOn = false, onColor = p.tint, Modifier.weight(1f)) {
            model.closeLectern()
            navigator.openMore()
        }
    }
    if (choosing) AddToPlaylistDialog(model, navigator, number, lists) { choosing = false }
}

private fun newPlaylist(model: ReaderModel, navigator: AppNavigator) {
    model.newPlaylist()
    navigator.newPlaylist()
}

/** "Add hymn N to": the playlists without it, then New Playlist… (the tile's confirmation dialog). */
@Composable
private fun AddToPlaylistDialog(model: ReaderModel, navigator: AppNavigator, number: Int, lists: List<Playlist>, onDismiss: () -> Unit) {
    val p = LocalSurface.current
    val already = lists.filter { number in it.hymnNumbers }.map { it.name }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add hymn $number to", style = DS.Type.label, color = p.foreground) },
        text = {
            Column {
                if (already.isNotEmpty()) {
                    Text("Already in ${andList(already)}.", style = DS.Type.detail, color = p.secondary, modifier = Modifier.padding(bottom = DS.Space.s))
                }
                lists.filter { number !in it.hymnNumbers }.forEach { list ->
                    DialogChoice(list.name) { model.addCurrentHymn(list); onDismiss() }
                }
                DialogChoice("New Playlist…") { onDismiss(); newPlaylist(model, navigator) }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = p.tint) } },
        containerColor = p.elevated,
    )
}

@Composable
private fun DialogChoice(title: String, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).clip(dsShape(DS.Radius.key)).clickable(onClick = onClick)
            .padding(horizontal = DS.Space.s),
        contentAlignment = Alignment.CenterStart,
    ) { Text(title, style = DS.Type.label, color = p.tint) }
}

/** A tray tile: its glyph over a short caption; the whole 72 dp tile takes the tap. */
@Composable
private fun TrayTile(
    label: String,
    icon: ImageVector,
    isOn: Boolean,
    onColor: Color,
    modifier: Modifier = Modifier,
    spoken: String = label,
    value: String? = null,
    hint: String? = null,
    onClick: () -> Unit,
) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val color = if (isOn) onColor else p.foreground
    Column(
        modifier
            .heightIn(min = 72.dp)
            .dsPress(interaction)
            .clip(dsShape(DS.Radius.tile))
            .background(if (isOn) onColor.copy(alpha = DS.Fill.tintOn) else p.primary(DS.Fill.inset))
            .clickable(interaction, null, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = if (hint != null) "$spoken. $hint" else spoken
                role = Role.Button
                selected = isOn
                value?.let { stateDescription = it }
            }
            .padding(horizontal = DS.Space.xxs, vertical = DS.Space.s),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs, Alignment.CenterVertically),
    ) {
        Box(Modifier.height(26.dp), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
        }
        Text(label, style = DS.Type.eyebrowBase, color = color, maxLines = 1, softWrap = false, overflow = TextOverflow.Clip)
    }
}

// MARK: - Number pad

@Composable
fun LecternNumberPad(services: AppServices) {
    val model = services.reader
    val hymnal = model.hymnal ?: return
    ScreenEffect(AnalyticsScreen.NumberPad)
    HymnNumberPad(
        digits = model.digits,
        onDigitsChange = { model.proposeDigits(it) },
        title = { hymnal.hymn(it)?.title },
        onGo = { model.openPreview() },
        recents = model.recents.mapNotNull { n -> hymnal.hymn(n)?.let { DSHymnSummary(n, it.title) } },
        isStandalone = false,
        onSearchInstead = { model.openLectern(LecternState.Search) },
    )
}

// MARK: - Word search

@Composable
fun LecternSearchPanel(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val focus = remember { FocusRequester() }
    val hits = model.searchHits()
    val scope = if (model.searchLyrics) SearchScope.Lyrics else SearchScope.Titles
    ScreenEffect(AnalyticsScreen.Search)
    // The panel exists only while search is open, so focus follows it.
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    // Once typing pauses: how long the query was and what it found, never the words.
    LaunchedEffect(model.searchLyrics, model.query) {
        val trimmed = model.query.trim()
        if (trimmed.isEmpty()) return@LaunchedEffect
        delay(1500)
        Analytics.track(AnalyticsEvent.SearchPerformed(SearchSurface.Lectern, scope, trimmed.length, model.searchHits().size, trimmed.toIntOrNull() != null))
    }
    fun open(hit: SearchHit, rank: Int) {
        Analytics.track(AnalyticsEvent.SearchResultOpened(SearchSurface.Lectern, scope, rank + 1))
        model.show(hit.hymn, source = HymnSource.Search)
    }
    Column(Modifier.fillMaxWidth().padding(DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier
                    .weight(1f)
                    .heightIn(min = DS.Size.hitTarget)
                    .background(p.primary(DS.Fill.inset), dsShape(DS.Radius.tile))
                    .padding(horizontal = DS.Space.m),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
            ) {
                Icon(Icons.Rounded.Search, null, tint = p.secondary, modifier = Modifier.size(20.dp))
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (model.query.isEmpty()) Text("Words in a title or lyric", style = DS.Type.body, color = p.secondary, maxLines = 1)
                    BasicTextField(
                        value = model.query,
                        onValueChange = { model.query = it },
                        singleLine = true,
                        textStyle = DS.Type.body.copy(color = p.foreground),
                        cursorBrush = SolidColor(p.tint),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false,
                            keyboardType = KeyboardType.Text, imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(onSearch = { hits.firstOrNull()?.let { open(it, 0) } }),
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focus)
                            .semantics { contentDescription = "Search words in a title or lyric" },
                    )
                }
            }
            // The padding and fill are in the key, so the whole key takes the tap.
            val interaction = remember { MutableInteractionSource() }
            Box(
                Modifier
                    .heightIn(min = DS.Size.hitTarget)
                    .dsPress(interaction)
                    .clip(dsShape(DS.Radius.tile))
                    .background(p.primary(DS.Fill.inset))
                    .clickable(interaction, null, role = Role.Button) { model.openLectern(LecternState.Pad) }
                    .clearAndSetSemantics { contentDescription = "Enter a number instead"; role = Role.Button }
                    .padding(horizontal = DS.Space.m),
                contentAlignment = Alignment.Center,
            ) { Text("123", style = DS.Type.button, color = p.foreground) }
        }
        Row(Modifier.padding(horizontal = DS.Space.xxs), verticalAlignment = Alignment.CenterVertically) {
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                ScopeChip("Lyrics", model.searchLyrics) { model.searchLyrics = true }
                ScopeChip("Titles", !model.searchLyrics) { model.searchLyrics = false }
            }
            Spacer(Modifier.weight(1f))
            Text(if (hits.isEmpty()) "" else "${hits.size} hymn${if (hits.size == 1) "" else "s"}", style = DS.Type.caption, color = p.secondary)
        }
        FittingScroll(260.dp) {
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                hits.take(40).forEachIndexed { rank, hit ->
                    HymnRow(
                        hit.hymn.summary, onClick = { open(hit, rank) }, snippet = hit.snippet, highlight = model.query,
                        isFavourite = model.isFavouriteNumber(hit.hymn.number), isCurrent = hit.hymn.number == model.hymn?.number,
                        style = HymnRowStyle.Inset,
                    )
                }
            }
        }
    }
}

/** A 32 dp chip with a 44 dp tall hit area (ScopeChip). */
@Composable
fun ScopeChip(title: String, isOn: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    val shape = RoundedCornerShape(50)
    Box(
        Modifier
            .heightIn(min = DS.Size.hitTarget)
            .clickable(remember { MutableInteractionSource() }, null, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = title; role = Role.Button; selected = isOn },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            style = DS.Type.caption.copy(fontWeight = if (isOn) FontWeight.Bold else FontWeight.SemiBold),
            color = if (isOn) p.tint else p.secondary,
            modifier = Modifier
                .heightIn(min = 32.dp)
                .background(if (isOn) p.tint.copy(alpha = DS.Fill.tintSelected) else Color.Transparent, shape)
                .border(1.dp, if (isOn) Color.Transparent else p.primary(DS.Fill.stroke), shape)
                .padding(horizontal = DS.Space.m, vertical = 8.dp),
        )
    }
}

/** Hugs short content; scrolls once it outgrows [maxHeight] (DSFittingScroll). */
@Composable
fun FittingScroll(maxHeight: Dp, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxWidth().heightIn(max = maxHeight).verticalScroll(rememberScrollState())) { content() }
}

// MARK: - Library

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun LecternLibraryPanel(services: AppServices) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val hymnal = model.hymnal ?: return
    val p = LocalSurface.current
    var adding by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    // The number typed into Add hymn that the hymnal doesn't have.
    var missing by remember { mutableStateOf<Int?>(null) }
    ScreenEffect(AnalyticsScreen.Library)
    Column(Modifier.fillMaxWidth().padding(DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget)) {
            LibraryTab.entries.forEachIndexed { i, tab ->
                SegmentedButton(
                    selected = model.libraryTab == tab,
                    onClick = { if (model.libraryTab != tab) { model.libraryTab = tab; Haptics.play(HapticEvent.Selection) } },
                    shape = SegmentedButtonDefaults.itemShape(i, LibraryTab.entries.size),
                    icon = {},
                ) { Text(tab.label, maxLines = 1) }
            }
        }
        when (model.libraryTab) {
            LibraryTab.Favourites -> FittingScroll(300.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    model.favouriteNumbers.forEach { n ->
                        val hymn = hymnal.hymn(n) ?: return@forEach
                        HymnRow(hymn.summary, onClick = { model.show(hymn, source = HymnSource.Favourites) }, isFavourite = true,
                            isCurrent = hymn.number == model.hymn?.number, style = HymnRowStyle.Inset)
                    }
                    if (model.favouriteNumbers.isEmpty()) EmptyNote("Star a hymn while you read, or add one by number, to keep it here.")
                }
            }
            LibraryTab.Playlists -> FittingScroll(300.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    model.playlists.forEach { list -> LibraryPlaylistRow(model, navigator, list) }
                    if (model.playlists.isEmpty()) {
                        EmptyNote("Build a set for Sabbath, choir practice or vespers. Tap New Playlist to start one with the open hymn.")
                    }
                }
            }
        }
        // Below the list, which scrolls on its own, so it stays put at the panel's foot.
        when (model.libraryTab) {
            LibraryTab.Favourites -> GlassButton("Add hymn", { draft = ""; adding = true }, icon = Icons.Rounded.Add,
                kind = GlassButtonKind.Primary, fullWidth = true)
            LibraryTab.Playlists -> GlassButton("New Playlist", { newPlaylist(model, navigator) }, icon = Icons.Rounded.Add,
                kind = GlassButtonKind.Primary, fullWidth = true)
        }
    }
    if (adding) {
        AlertDialog(
            onDismissRequest = { adding = false },
            title = { Text("Add Hymn") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
                    Text("Type a number from ${hymnal.name} to keep it in Favourites.", style = DS.Type.detail, color = p.secondary)
                    OutlinedTextField(
                        draft, { draft = it.filter(Char::isDigit).take(4) },
                        placeholder = { Text("Hymn number") }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    adding = false
                    val number = draft.toIntOrNull() ?: return@TextButton
                    if (!model.addFavourite(number)) { Haptics.play(HapticEvent.Limit); missing = number }
                }) { Text("Add", color = p.tint) }
            },
            dismissButton = { TextButton(onClick = { adding = false }) { Text("Cancel", color = p.tint) } },
            containerColor = p.elevated,
        )
    }
    missing?.let { n ->
        AlertDialog(
            onDismissRequest = { missing = null },
            title = { Text("No Hymn $n") },
            text = {
                Text("${hymnal.name} has hymns 1 to ${maxOf(hymnal.info.maxNumber, 1)}. Check the number and try again.",
                    style = DS.Type.detail, color = p.secondary)
            },
            confirmButton = { TextButton(onClick = { missing = null; draft = ""; adding = true }) { Text("Try Again", color = p.tint) } },
            dismissButton = { TextButton(onClick = { missing = null }) { Text("Cancel", color = p.tint) } },
            containerColor = p.elevated,
        )
    }
}

@Composable
private fun EmptyNote(text: String) {
    Text(text, style = DS.Type.caption, color = LocalSurface.current.secondary, modifier = Modifier.fillMaxWidth())
}

/**
 * One playlist in the library (PlaylistSummaryRow, inset): tap plays it; the
 * pencil opens the editor; touch and hold for play, edit, add, rename and
 * delete. TalkBack gets the same choices as actions on one element.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun LibraryPlaylistRow(model: ReaderModel, navigator: AppNavigator, list: Playlist, inset: Boolean = true) {
    val p = LocalSurface.current
    val isActive = model.activePlaylistId == list.id
    val count = if (list.hymnNumbers.size == 1) "1 hymn" else "${list.hymnNumbers.size} hymns"
    val numbers = list.hymnNumbers.joinToString(" · ")
    val current = model.hymn?.number
    var menu by remember { mutableStateOf(false) }
    val shape = dsShape(DS.Radius.tile)
    val actions = buildList {
        add(CustomAccessibilityAction("Edit playlist") { navigator.openPlaylist(list.id); true })
        if (current != null) add(CustomAccessibilityAction("Add hymn $current") { model.addCurrentHymn(list); true })
        add(CustomAccessibilityAction("Rename") { navigator.renamePlaylist(list.id); true })
        add(CustomAccessibilityAction("Delete playlist") { navigator.deletePlaylist(list.id); true })
    }
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = DS.Size.row)
                .then(
                    if (inset) Modifier
                        .background(if (isActive) p.tint.copy(alpha = DS.Fill.tintActive) else p.primary(DS.Fill.row), shape)
                        .border(1.dp, if (isActive) p.tint.copy(alpha = 0.35f) else Color.Transparent, shape)
                    else Modifier,
                )
                .clip(shape)
                .padding(start = if (inset) DS.Space.m else 0.dp, top = DS.Space.xxs, bottom = DS.Space.xxs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
        ) {
            Row(
                Modifier
                    .weight(1f)
                    .combinedClickable(onClick = { model.play(list) }, onLongClick = { menu = true })
                    .clearAndSetSemantics {
                        contentDescription = "${list.name}, $count"
                        stateDescription = if (isActive) "Playing" else numbers
                        role = Role.Button
                        customActions = actions
                    },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
            ) {
                if (inset) {
                    Box(
                        Modifier.size(DS.Size.numberTile).background(p.tint.copy(alpha = DS.Fill.tintSelected), dsShape(DS.Radius.badge)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(if (isActive) Icons.Rounded.PlayArrow else Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.tint,
                            modifier = Modifier.size(20.dp))
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
                    Text(list.name, style = DS.Type.rowTitle, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(if (list.hymnNumbers.isEmpty()) "No hymns yet" else numbers, style = DS.Type.caption, color = p.secondary,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Box(
                Modifier
                    .size(DS.Size.hitTarget)
                    .clickable(role = Role.Button) { navigator.openPlaylist(list.id) }
                    .clearAndSetSemantics { contentDescription = "Edit playlist"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Edit, null, tint = p.tint, modifier = Modifier.size(20.dp)) }
        }
        DropdownMenu(menu, onDismissRequest = { menu = false }, containerColor = p.elevated) {
            DropdownMenuItem({ Text("Play") }, onClick = { menu = false; model.play(list) },
                leadingIcon = { Icon(Icons.Rounded.PlayArrow, null) })
            DropdownMenuItem({ Text("Edit Playlist") }, onClick = { menu = false; navigator.openPlaylist(list.id) },
                leadingIcon = { Icon(Icons.Rounded.Edit, null) })
            if (current != null && current !in list.hymnNumbers) {
                DropdownMenuItem({ Text("Add Hymn $current") }, onClick = { menu = false; model.addCurrentHymn(list) },
                    leadingIcon = { Icon(Icons.Rounded.Add, null) })
            }
            DropdownMenuItem({ Text("Rename") }, onClick = { menu = false; navigator.renamePlaylist(list.id) },
                leadingIcon = { Icon(Icons.Rounded.TextFields, null) })
            DropdownMenuItem({ Text("Delete Playlist", color = DS.Palette.destructive) }, onClick = { menu = false; navigator.deletePlaylist(list.id) },
                leadingIcon = { Icon(Icons.Rounded.Delete, null, tint = DS.Palette.destructive) })
        }
    }
}
