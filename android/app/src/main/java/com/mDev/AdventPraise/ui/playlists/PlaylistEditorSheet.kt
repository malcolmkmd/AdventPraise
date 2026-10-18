// OWNER: church
package com.mDev.AdventPraise.ui.playlists

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddCircleOutline
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.RemoveCircle
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.GlassButtonKind
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.NumberTile
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/**
 * One playlist (PlaylistEditorView): hymn numbers and titles in order,
 * drag to reorder (touch and hold, or Edit's handles), swipe left to
 * remove, rename and delete from the title menu. Add Hymns pushes a picker
 * that finds hymns by number, title or words. Play and Add Hymns float at
 * the bottom. Tapping a hymn plays the list from there.
 */
@Composable
fun PlaylistEditorSheet(services: AppServices, navigator: AppNavigator, playlistId: String) {
    val reader = services.reader
    val model = remember(playlistId) { PlaylistEditorModel(services.playlists, services.queue, { reader.hymnal?.id }, playlistId) }
    val hymnal = reader.hymnal
    val list = model.playlist
    val close = { navigator.dismiss(Destination.PlaylistEditor(playlistId)) }
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.PlaylistEditor) }
    // After the very first playlist's editor closes, the library opens on Playlists.
    DisposableEffect(Unit) {
        onDispose {
            if (PlaylistReveal.pending && navigator.stack.none { it is Destination.PlaylistEditor }) {
                PlaylistReveal.pending = false
                PlaylistReveal.opensPlaylistsTab = true
                reader.openLectern(LecternState.Library)
            }
        }
    }
    val activeHymn = if (services.queue.activePlaylistId == playlistId) reader.hymn?.number else null
    PlaylistEditorContent(
        list = list,
        hymnal = hymnal,
        openNumber = activeHymn,
        canPlay = model.canPlay(hymnal),
        onDone = close,
        onPlay = { start -> list?.let { PlaylistActions.play(services, it, start) }; close() },
        onRename = { navigator.renamePlaylist(playlistId) },
        onDelete = { navigator.deletePlaylist(playlistId) },
        onMove = model::move,
        onMoveHymn = model::moveHymn,
        onRemoveAt = model::removeAt,
        onToggle = model::toggle,
    )
}

/** The editor from plain values (the screenshot tests draw it too). */
@Composable
internal fun PlaylistEditorContent(
    list: Playlist?,
    hymnal: Hymnal?,
    openNumber: Int?,
    canPlay: Boolean,
    onDone: () -> Unit,
    onPlay: (Int) -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    onMove: (Int, Int) -> Unit,
    onMoveHymn: (Int, Int) -> Unit,
    onRemoveAt: (Int) -> Unit,
    onToggle: (Int) -> Unit,
    initialPicking: Boolean = false,
) {
    var picking by rememberSaveable { mutableStateOf(initialPicking) }
    var editing by rememberSaveable { mutableStateOf(false) }
    val reduceMotion = rememberReduceMotion()
    BackHandler(enabled = picking) { picking = false }
    if (list == null) {
        Column(Modifier.fillMaxSize()) {
            EditorBar(title = null, leading = "Done" to onDone)
            Deleted()
        }
        return
    }
    AnimatedContent(
        picking,
        transitionSpec = {
            if (reduceMotion) fadeIn(DS.Motion.reduced()) togetherWith fadeOut(DS.Motion.reduced())
            else if (targetState) (slideInHorizontally { it } + fadeIn()) togetherWith (slideOutHorizontally { -it / 3 } + fadeOut())
            else (slideInHorizontally { -it / 3 } + fadeIn()) togetherWith (slideOutHorizontally { it } + fadeOut())
        },
        label = "playlist-pages",
    ) { showsPicker ->
        if (showsPicker) {
            PlaylistHymnPicker(list, hymnal, onBack = { picking = false }, onToggle = onToggle)
        } else {
            Column(Modifier.fillMaxSize()) {
                EditorBar(
                    title = list.name,
                    leading = "Done" to onDone,
                    editing = editing,
                    onEdit = { editing = !editing; Haptics.play(HapticEvent.Selection) },
                    onRename = onRename,
                    onDelete = onDelete,
                )
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    HymnList(list, hymnal, openNumber, editing, onPlay, onMove, onMoveHymn, onRemoveAt)
                    FloatingControls(canPlay, Modifier.align(Alignment.BottomCenter), onPlay = { onPlay(0) }, onAdd = { picking = true })
                }
            }
        }
    }
}

/** Done · the playlist's name · Edit and the options menu (Rename, Delete Playlist). */
@Composable
private fun EditorBar(
    title: String?,
    leading: Pair<String, () -> Unit>,
    editing: Boolean = false,
    onEdit: (() -> Unit)? = null,
    onRename: (() -> Unit)? = null,
    onDelete: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
) {
    val p = LocalSurface.current
    var menu by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).padding(horizontal = DS.Space.xs)) {
        if (onBack != null) {
            Row(
                Modifier.align(Alignment.CenterStart).heightIn(min = DS.Size.hitTarget).clip(dsShape(DS.Radius.badge))
                    .clickable(role = Role.Button, onClick = onBack).padding(horizontal = DS.Space.xs)
                    .semantics { contentDescription = "Back" },
                verticalAlignment = Alignment.CenterVertically,
            ) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, null, tint = p.tint) }
        } else {
            TextButton(leading.first, Modifier.align(Alignment.CenterStart), onClick = leading.second)
        }
        if (title != null) {
            Text(
                title, style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold), color = p.foreground, maxLines = 1,
                overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 112.dp).semantics { heading() },
            )
        }
        if (onEdit != null) {
            Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically) {
                TextButton(if (editing) "Done" else "Edit", bold = editing, onClick = onEdit)
                Box {
                    Box(
                        Modifier.size(DS.Size.hitTarget).clip(dsShape(DS.Radius.capsule))
                            .clickable(role = Role.Button) { menu = true }
                            .semantics { contentDescription = "Playlist options" },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.MoreHoriz, null, tint = p.tint) }
                    DropdownMenu(menu, onDismissRequest = { menu = false }, containerColor = p.elevated) {
                        DropdownMenuItem(
                            text = { Text("Rename", style = DS.Type.body, color = p.foreground) },
                            trailingIcon = { Icon(Icons.Rounded.Edit, null, tint = p.foreground) },
                            onClick = { menu = false; onRename?.invoke() },
                        )
                        DropdownMenuItem(
                            text = { Text("Delete Playlist", style = DS.Type.body, color = DS.Palette.destructive) },
                            trailingIcon = { Icon(Icons.Rounded.Delete, null, tint = DS.Palette.destructive) },
                            onClick = { menu = false; onDelete?.invoke() },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TextButton(label: String, modifier: Modifier = Modifier, bold: Boolean = false, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        modifier.heightIn(min = DS.Size.hitTarget).clip(dsShape(DS.Radius.capsule))
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = DS.Space.m),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = DS.Type.label.copy(fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal), color = p.tint)
    }
}

/** "Playlist deleted" (ContentUnavailableView). */
@Composable
private fun Deleted() {
    val p = LocalSurface.current
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.secondary, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(DS.Space.m))
        Text("Playlist deleted", style = DS.Type.sheetTitle, color = p.foreground)
    }
}

/**
 * The hymns as an inset-grouped section: "3 hymns" above, the hint below.
 * Touch and hold a row to drag it; in Edit, the handles drag at once and
 * the minus removes. A swipe left removes too.
 */
@Composable
private fun HymnList(
    list: Playlist,
    hymnal: Hymnal?,
    openNumber: Int?,
    editing: Boolean,
    onPlay: (Int) -> Unit,
    onMove: (Int, Int) -> Unit,
    onMoveHymn: (Int, Int) -> Unit,
    onRemoveAt: (Int) -> Unit,
) {
    val p = LocalSurface.current
    val density = LocalDensity.current
    val order = remember(list.hymnNumbers) { list.hymnNumbers.toMutableStateList() }
    var dragged by remember { mutableStateOf<Int?>(null) }
    var dragFrom by remember { mutableStateOf(0) }
    var offset by remember { mutableFloatStateOf(0f) }
    val heights = remember { mutableStateMapOf<Int, Int>() }

    fun dragBy(number: Int, dy: Float) {
        offset += dy
        val i = order.indexOf(number)
        if (offset > 0 && i < order.lastIndex) {
            val h = heights[order[i + 1]] ?: return
            if (offset > h / 2f) { order.add(i + 1, order.removeAt(i)); offset -= h; Haptics.play(HapticEvent.Selection) }
        } else if (offset < 0 && i > 0) {
            val h = heights[order[i - 1]] ?: return
            if (-offset > h / 2f) { order.add(i - 1, order.removeAt(i)); offset += h; Haptics.play(HapticEvent.Selection) }
        }
    }
    fun drop(number: Int) {
        val to = order.indexOf(number)
        dragged = null
        offset = 0f
        if (to != dragFrom) onMove(dragFrom, to)
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(start = DS.Space.l, end = DS.Space.l, top = DS.Space.s, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        Text(PlaylistEditorModel.countText(list.hymnNumbers.size), style = DS.Type.detail, color = p.secondary,
            modifier = Modifier.padding(horizontal = DS.Space.l).semantics { heading() })
        if (order.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().clip(dsShape(DS.Radius.tile)).background(p.elevated)) {
                order.forEachIndexed { index, number ->
                    key(number) {
                        val isDragged = dragged == number
                        val dragModifier = Modifier.pointerInput(number, editing) {
                            val start = { dragged = number; dragFrom = order.indexOf(number); Haptics.play(HapticEvent.MediumImpact) }
                            if (editing) {
                                detectDragGestures(onDragStart = { start() }, onDragEnd = { drop(number) }, onDragCancel = { drop(number) }) { change, amount ->
                                    change.consume(); dragBy(number, amount.y)
                                }
                            } else {
                                detectDragGesturesAfterLongPress(onDragStart = { start() }, onDragEnd = { drop(number) }, onDragCancel = { drop(number) }) { change, amount ->
                                    change.consume(); dragBy(number, amount.y)
                                }
                            }
                        }
                        Box(
                            Modifier
                                .zIndex(if (isDragged) 1f else 0f)
                                .graphicsLayer {
                                    translationY = if (isDragged) offset else 0f
                                    shadowElevation = if (isDragged) with(density) { 8.dp.toPx() } else 0f
                                    scaleX = if (isDragged) 1.02f else 1f
                                    scaleY = if (isDragged) 1.02f else 1f
                                }
                                .onSizeChanged { heights[number] = it.height },
                        ) { Column {
                            if (index > 0 && !isDragged) {
                                HorizontalDivider(Modifier.padding(start = DS.Space.l + DS.Size.numberTile + DS.Space.m),
                                    color = p.foreground.copy(alpha = DS.Fill.stroke))
                            }
                            PlaylistHymnRow(
                                number = number,
                                title = hymnal?.hymn(number)?.title,
                                isOpen = openNumber == number,
                                editing = editing,
                                count = order.size,
                                index = index,
                                rowModifier = if (editing) Modifier else dragModifier,
                                handleModifier = if (editing) dragModifier else Modifier,
                                onClick = { onPlay(index) },
                                onRemove = { onRemoveAt(index) },
                                onMoveUp = { onMoveHymn(number, -1) },
                                onMoveDown = { onMoveHymn(number, 1) },
                            )
                        } }
                    }
                }
            }
        }
        Text(
            if (list.hymnNumbers.isEmpty()) "Add hymns by number, title or words. You can also add the hymn you're reading from the Playlist tile in the hymn tray."
            else "Drag to reorder. Swipe left to remove a hymn.",
            style = DS.Type.detail, color = p.secondary, modifier = Modifier.padding(horizontal = DS.Space.l),
        )
    }
}

/** One hymn: the number tile (tint when it's the one open), the title, a check when open. */
@Composable
private fun PlaylistHymnRow(
    number: Int,
    title: String?,
    isOpen: Boolean,
    editing: Boolean,
    count: Int,
    index: Int,
    rowModifier: Modifier,
    handleModifier: Modifier,
    onClick: () -> Unit,
    onRemove: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    val p = LocalSurface.current
    val large = LocalDensity.current.fontScale >= 1.8f
    val swipe = rememberSwipeToDismissBoxState(confirmValueChange = { value ->
        if (value == SwipeToDismissBoxValue.EndToStart) { onRemove(); true } else false
    })
    val description = "Hymn $number, ${title ?: "not in this hymnal"}"
    SwipeToDismissBox(
        swipe,
        enableDismissFromStartToEnd = false,
        gesturesEnabled = !editing,
        backgroundContent = {
            Box(Modifier.fillMaxSize().background(DS.Palette.destructive).padding(horizontal = DS.Space.l), contentAlignment = Alignment.CenterEnd) {
                Text("Delete", style = DS.Type.label, color = Color.White)
            }
        },
    ) {
        Row(
            rowModifier
                .fillMaxWidth()
                .heightIn(min = DS.Size.hitTarget + DS.Space.s)
                .background(p.elevated)
                .clickable(enabled = title != null && !editing, onClick = onClick)
                .clearAndSetSemantics {
                    contentDescription = description
                    role = Role.Button
                    if (isOpen) stateDescription = "Now open"
                    selected = isOpen
                    if (title == null) disabled()
                    else onClick("Opens this hymn and follows the playlist from here.") { onClick(); true }
                    customActions = buildList {
                        if (index > 0) add(CustomAccessibilityAction("Move up") { onMoveUp(); true })
                        if (index < count - 1) add(CustomAccessibilityAction("Move down") { onMoveDown(); true })
                        add(CustomAccessibilityAction("Remove from playlist") { onRemove(); true })
                    }
                }
                .padding(horizontal = DS.Space.l, vertical = DS.Space.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            if (editing) {
                Icon(Icons.Rounded.RemoveCircle, "Remove", tint = DS.Palette.destructive,
                    modifier = Modifier.size(24.dp).clip(dsShape(DS.Radius.badge)).clickable(role = Role.Button, onClick = onRemove))
            }
            NumberTile(number, tint = if (isOpen) p.tint else p.brass)
            Text(
                title ?: "Not in this hymnal", style = DS.Type.rowTitle, color = if (title == null) p.secondary else p.foreground,
                maxLines = if (large) 4 else 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
            )
            if (isOpen) Icon(Icons.Rounded.Check, null, tint = p.tint, modifier = Modifier.size(16.dp))
            if (editing) Icon(Icons.Rounded.DragHandle, "Reorder", tint = p.secondary, modifier = handleModifier.size(DS.Size.hitTarget).padding(10.dp))
        }
    }
}

/** Play and Add Hymns, side by side (stacked at the largest text sizes so neither label truncates). */
@Composable
private fun FloatingControls(canPlay: Boolean, modifier: Modifier, onPlay: () -> Unit, onAdd: () -> Unit) {
    val stacks = LocalDensity.current.fontScale >= 1.8f
    val play = @Composable { m: Modifier ->
        GlassButton("Play", onClick = onPlay, modifier = m, icon = Icons.Rounded.PlayArrow, kind = GlassButtonKind.Primary,
            fullWidth = true, enabled = canPlay)
    }
    val add = @Composable { m: Modifier ->
        GlassButton("Add Hymns", onClick = onAdd, modifier = m, icon = Icons.Rounded.Add, kind = GlassButtonKind.Secondary, fullWidth = true)
    }
    Box(modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars), contentAlignment = Alignment.Center) {
        if (stacks) {
            Column(
                Modifier.widthIn(max = DS.Space.lecternMaxWidth).padding(horizontal = DS.Space.l, vertical = DS.Space.s),
                verticalArrangement = Arrangement.spacedBy(DS.Space.s),
            ) { play(Modifier); add(Modifier) }
        } else {
            Row(
                Modifier.widthIn(max = DS.Space.lecternMaxWidth).padding(horizontal = DS.Space.l, vertical = DS.Space.s),
                horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
            ) { play(Modifier.weight(1f)); add(Modifier.weight(1f)) }
        }
    }
}

// MARK: - Picker

/**
 * Add Hymns (PlaylistHymnPicker): find hymns by number, title or words and
 * add or remove them. A bare number puts that hymn first.
 */
@Composable
private fun PlaylistHymnPicker(list: Playlist, hymnal: Hymnal?, onBack: () -> Unit, onToggle: (Int) -> Unit) {
    val p = LocalSurface.current
    var query by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.PlaylistHymnPicker) }
    val results = remember(query, hymnal) { results(hymnal, query) }
    Column(Modifier.fillMaxSize().imePadding()) {
        EditorBar(title = "Add Hymns", leading = "" to onBack, onBack = onBack)
        // The search field, always showing.
        Row(
            Modifier.padding(horizontal = DS.Space.l, vertical = DS.Space.xs).fillMaxWidth()
                .clip(dsShape(DS.Radius.badge)).background(p.primary(DS.Fill.stroke)).padding(horizontal = DS.Space.s),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            Icon(Icons.Rounded.Search, null, tint = p.secondary, modifier = Modifier.size(18.dp))
            val style = DS.Type.body.copy(color = p.foreground)
            BasicTextField(
                query, { query = it }, singleLine = true, textStyle = style, cursorBrush = SolidColor(p.tint),
                modifier = Modifier.weight(1f).padding(vertical = DS.Space.s).semantics { contentDescription = "Number, title or words" },
                decorationBox = { inner ->
                    Box { if (query.isEmpty()) Text("Number, title or words", style = style.copy(color = p.secondary)); inner() }
                },
            )
            if (query.isNotEmpty()) {
                Icon(Icons.Rounded.Close, "Clear", tint = p.secondary,
                    modifier = Modifier.size(18.dp).clickable(role = Role.Button) { query = "" })
            }
        }
        if (results.isEmpty()) {
            Column(Modifier.fillMaxSize().padding(DS.Space.l), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Rounded.Search, null, tint = p.secondary, modifier = Modifier.size(44.dp))
                Spacer(Modifier.height(DS.Space.m))
                Text("No Results for “${query.trim()}”", style = DS.Type.sheetTitle, color = p.foreground, textAlign = TextAlign.Center)
                Text("Check the spelling or try a new search.", style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = DS.Space.l, vertical = DS.Space.xs)) {
                items(results, key = { it.number }) { hymn ->
                    PickerRow(hymn, hymn.number in list.hymnNumbers) { onToggle(hymn.number) }
                }
            }
        }
    }
}

private fun results(hymnal: Hymnal?, query: String): List<Hymn> {
    hymnal ?: return emptyList()
    val trimmed = query.trim()
    if (trimmed.isEmpty()) return hymnal.hymns
    val hits = hymnal.search(trimmed, inLyrics = true).map { it.hymn }.toMutableList()
    trimmed.toIntOrNull()?.let(hymnal::hymn)?.let { exact ->
        hits.removeAll { it.number == exact.number }
        hits.add(0, exact)
    }
    return hits
}

@Composable
private fun PickerRow(hymn: Hymn, isIn: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget + DS.Space.s)
            .clickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Hymn ${hymn.number}, ${hymn.title}"
                role = Role.Button
                selected = isIn
                stateDescription = if (isIn) "In playlist" else ""
                onClick(if (isIn) "Removes it from the playlist." else "Adds it to the end of the playlist.") { onClick(); true }
            }
            .padding(vertical = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        NumberTile(hymn.number)
        Text(hymn.title, style = DS.Type.rowTitle, color = p.foreground, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Crossfade(isIn, animationSpec = DS.Motion.quick(), label = "picker-mark") { inList ->
            Icon(
                if (inList) Icons.Rounded.CheckCircle else Icons.Rounded.AddCircleOutline, null,
                tint = if (inList) p.tint else p.secondary, modifier = Modifier.size(24.dp),
            )
        }
    }
}

