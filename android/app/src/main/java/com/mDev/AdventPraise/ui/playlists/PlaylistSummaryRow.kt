package com.mDev.AdventPraise.ui.playlists

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.dsGlass
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/** PlaylistSummaryRow's two backgrounds: the Lectern's library panel, or a plain list. */
enum class PlaylistRowStyle { Inset, Plain }

/** One choice in a playlist's touch-and-hold menu. */
internal class PlaylistMenuItem(val title: String, val icon: ImageVector, val destructive: Boolean = false, val action: () -> Unit)

/**
 * A playlist as a row (PlaylistSummaryRow): tap plays it, the pencil opens
 * the editor, touch and hold lifts it with a menu (Play, Edit Playlist,
 * Add Hymn N, Rename, Delete Playlist). TalkBack gets the same choices as
 * actions on one element.
 */
@Composable
fun PlaylistSummaryRow(
    services: AppServices,
    navigator: AppNavigator,
    playlistId: String,
    style: PlaylistRowStyle = PlaylistRowStyle.Inset,
) {
    val hymnal = services.reader.hymnal ?: return
    val list = services.playlists.playlist(hymnal.id, playlistId) ?: return
    val current = services.reader.hymn?.number
    val items = buildList {
        add(PlaylistMenuItem("Play", Icons.Rounded.PlayArrow) { PlaylistActions.play(services, list) })
        add(PlaylistMenuItem("Edit Playlist", Icons.Rounded.Edit) { services.reader.closeLectern(); navigator.openPlaylist(list.id) })
        if (current != null && current !in list.hymnNumbers) {
            add(PlaylistMenuItem("Add Hymn $current", Icons.Rounded.Add) { PlaylistActions.addCurrentHymn(services, list) })
        }
        add(PlaylistMenuItem("Rename", Icons.Rounded.DriveFileRenameOutline) { navigator.renamePlaylist(list.id) })
        add(PlaylistMenuItem("Delete Playlist", Icons.Rounded.Delete, destructive = true) { navigator.deletePlaylist(list.id) })
    }
    PlaylistSummaryRowContent(
        list = list,
        isActive = services.queue.activePlaylistId == list.id,
        style = style,
        menu = items,
        onPlay = { PlaylistActions.play(services, list) },
        onEdit = { services.reader.closeLectern(); navigator.openPlaylist(list.id) },
    )
}

/**
 * The library panel's Playlists tab body: every playlist of the open
 * hymnal, or the empty note; it hugs a short list and scrolls past 300 dp.
 * The panel's own New Playlist button goes below ([NewPlaylistButton]).
 */
@Composable
fun PlaylistsList(services: AppServices, navigator: AppNavigator, modifier: Modifier = Modifier) {
    val hymnal = services.reader.hymnal
    val lists = hymnal?.let { services.playlists.playlists(it.id) }.orEmpty()
    Column(
        modifier.heightIn(max = 300.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        lists.forEach { PlaylistSummaryRow(services, navigator, it.id) }
        if (lists.isEmpty()) EmptyNote("Build a set for Sabbath, choir practice or vespers. Tap New Playlist to start one with the open hymn.")
    }
}

/** The library panel's one button on the Playlists tab: a playlist that starts with the open hymn. */
@Composable
fun NewPlaylistButton(navigator: AppNavigator, modifier: Modifier = Modifier) {
    GlassButton("New Playlist", onClick = { navigator.newPlaylist() }, modifier = modifier, icon = Icons.Rounded.Add,
        kind = com.mDev.AdventPraise.ui.design.GlassButtonKind.Secondary, fullWidth = true)
}

@Composable
internal fun EmptyNote(text: String) {
    val p = LocalSurface.current
    Text(text, style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.m, vertical = DS.Space.l))
}

/** The row from plain values, with its touch-and-hold preview. */
@Composable
internal fun PlaylistSummaryRowContent(
    list: Playlist,
    isActive: Boolean,
    style: PlaylistRowStyle,
    menu: List<PlaylistMenuItem>,
    onPlay: () -> Unit,
    onEdit: () -> Unit,
) {
    var bounds by remember { mutableStateOf<Rect?>(null) }
    var lifted by remember { mutableStateOf(false) }
    val row = @Composable { m: Modifier, interactive: Boolean ->
        SummaryRow(list, isActive, style, m, interactive, onPlay, onEdit, onLongPress = {
            Haptics.play(HapticEvent.MediumImpact)
            lifted = true
        })
    }
    val countText = PlaylistEditorModel.countText(list.hymnNumbers.size)
    val numbers = list.hymnNumbers.joinToString(" · ")
    row(
        Modifier
            .onGloballyPositioned { bounds = it.boundsInWindow() }
            .clearAndSetSemantics {
                contentDescription = "${list.name}, $countText"
                stateDescription = if (isActive) "Playing" else numbers
                role = Role.Button
                onClick("Opens the first hymn. Next follows this playlist.") { onPlay(); true }
                customActions = menu.filter { it.title != "Play" }.map { item ->
                    CustomAccessibilityAction(if (item.title == "Edit Playlist") "Edit playlist" else if (item.title == "Delete Playlist") "Delete playlist" else item.title) { item.action(); true }
                }
            },
        true,
    )
    val anchor = bounds
    if (lifted && anchor != null) {
        Popup(
            popupPositionProvider = WindowOrigin,
            onDismissRequest = { lifted = false },
            properties = PopupProperties(focusable = true, clippingEnabled = false),
        ) {
            PlaylistContextPreview(anchor, row = { row(Modifier, false) }, items = menu, onDismiss = { lifted = false })
        }
    }
}

/** Places a popup at the window's origin, so it can cover the window and draw at window coordinates. */
private object WindowOrigin : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize) = IntOffset.Zero
}

/**
 * The touch-and-hold preview (iOS's context menu): the window dims, the row
 * lifts where it was, and the menu opens under it (over it near the bottom).
 */
@Composable
internal fun PlaylistContextPreview(anchor: Rect, row: @Composable () -> Unit, items: List<PlaylistMenuItem>, onDismiss: () -> Unit) {
    val p = LocalSurface.current
    val density = LocalDensity.current
    val reduceMotion = rememberReduceMotion()
    val appear = remember { Animatable(if (reduceMotion) 1f else 0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, DS.Motion.criticalSpring(0.3f)) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val heightPx = with(density) { maxHeight.toPx() }
        val menuWidth = 250.dp
        val menuHeightPx = with(density) { (DS.Size.hitTarget * items.size + 12.dp).toPx() }
        val below = anchor.bottom + menuHeightPx + with(density) { 24.dp.toPx() } < heightPx
        Box(
            Modifier.fillMaxSize()
                .graphicsLayer { alpha = appear.value }
                .background(Color.Black.copy(alpha = if (p.isDark) 0.45f else 0.22f))
                .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        )
        with(density) {
            Box(
                Modifier
                    .offset { IntOffset(anchor.left.toInt(), anchor.top.toInt()) }
                    .width(anchor.width.toDp())
                    .graphicsLayer {
                        val s = 1f + 0.03f * appear.value
                        scaleX = s; scaleY = s
                        shadowElevation = 16.dp.toPx() * appear.value
                        shape = dsShape(DS.Radius.tile); clip = true
                    }
                    .background(p.background),
            ) { row() }
            val menuTop = if (below) anchor.bottom + 8.dp.toPx() else anchor.top - 8.dp.toPx() - menuHeightPx
            val menuLeft = anchor.left.coerceAtMost(maxWidth.toPx() - menuWidth.toPx() - 8.dp.toPx()).coerceAtLeast(8.dp.toPx())
            Column(
                Modifier
                    .offset { IntOffset(menuLeft.toInt(), menuTop.toInt()) }
                    .width(menuWidth)
                    .graphicsLayer {
                        alpha = appear.value
                        val s = 0.9f + 0.1f * appear.value
                        scaleX = s; scaleY = s
                        transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, if (below) 0f else 1f)
                    }
                    .dsGlass(dsShape(DS.Radius.panel), DS.GlassDepth.Sheet),
            ) {
                items.forEachIndexed { i, item ->
                    if (i > 0) HorizontalDivider(color = p.foreground.copy(alpha = DS.Fill.hairline))
                    val color = if (item.destructive) DS.Palette.destructive else p.foreground
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget)
                            .clickable(role = Role.Button) { onDismiss(); item.action() }
                            .padding(horizontal = DS.Space.l),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(item.title, style = DS.Type.body, color = color, modifier = Modifier.weight(1f), maxLines = 1)
                        Icon(item.icon, null, tint = color, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun SummaryRow(
    list: Playlist,
    isActive: Boolean,
    style: PlaylistRowStyle,
    modifier: Modifier,
    interactive: Boolean,
    onPlay: () -> Unit,
    onEdit: () -> Unit,
    onLongPress: () -> Unit,
) {
    val p = LocalSurface.current
    val large = LocalDensity.current.fontScale >= 1.8f
    val interaction = remember { MutableInteractionSource() }
    val shape = dsShape(DS.Radius.tile)
    val surface = when (style) {
        PlaylistRowStyle.Inset -> Modifier
            .heightIn(min = DS.Size.row)
            .background(if (isActive) p.tint.copy(alpha = DS.Fill.tintActive) else p.primary(DS.Fill.row), shape)
            .border(1.dp, if (isActive) p.tint.copy(alpha = 0.35f) else Color.Transparent, shape)
            .padding(start = DS.Space.m, top = DS.Space.xxs, bottom = DS.Space.xxs)
        PlaylistRowStyle.Plain -> Modifier
    }
    Row(
        modifier.fillMaxWidth().then(surface),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Row(
            Modifier
                .weight(1f)
                .dsPress(interaction, interactive)
                .then(if (interactive) Modifier.combinedClickable(interaction, null, onLongClick = onLongPress, onClick = onPlay) else Modifier),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            if (style == PlaylistRowStyle.Inset && !large) {
                Box(
                    Modifier.size(DS.Size.numberTile).background(p.tint.copy(alpha = DS.Fill.tintSelected), dsShape(DS.Radius.badge)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(if (isActive) Icons.Rounded.PlayArrow else Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.tint, modifier = Modifier.size(20.dp))
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
                Text(list.name, style = DS.Type.rowTitle, color = p.foreground, maxLines = if (large) 3 else 1, overflow = TextOverflow.Ellipsis)
                Text(
                    if (list.hymnNumbers.isEmpty()) "No hymns yet" else list.hymnNumbers.joinToString(" · "),
                    style = DS.Type.caption, color = p.secondary, maxLines = if (large) 2 else 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Box(
            Modifier.size(DS.Size.hitTarget).then(if (interactive) Modifier.clickable(role = Role.Button, onClick = onEdit) else Modifier),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Rounded.Edit, "Edit playlist", tint = p.tint, modifier = Modifier.size(20.dp)) }
    }
}

/**
 * The tray's Playlist tile's choice (iOS's confirmation dialog): "Add hymn
 * N to" the playlists that don't have it yet, "Already in …", or New
 * Playlist…. Content for a dialog or sheet the reader shows; [onDismiss]
 * closes it.
 */
@Composable
fun AddToPlaylistChoices(services: AppServices, navigator: AppNavigator, onDismiss: () -> Unit) {
    val p = LocalSurface.current
    val hymnal = services.reader.hymnal ?: return
    val number = services.reader.hymn?.number ?: return
    val lists = services.playlists.playlists(hymnal.id)
    val already = lists.filter { number in it.hymnNumbers }.map { it.name }
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Text("Add hymn $number to", style = DS.Type.label, color = p.secondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        if (already.isNotEmpty()) {
            Text("Already in ${listPhrase(already)}.", style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        }
        lists.filter { number !in it.hymnNumbers }.forEach { list ->
            Choice(list.name) { PlaylistActions.addCurrentHymn(services, list); onDismiss() }
        }
        Choice("New Playlist…") { onDismiss(); services.reader.closeLectern(); navigator.newPlaylist() }
        Choice("Cancel", bold = true, onClick = onDismiss)
    }
}

@Composable
private fun Choice(title: String, bold: Boolean = false, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget + DS.Space.xs).background(p.primary(DS.Fill.row), dsShape(DS.Radius.key))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = if (bold) DS.Type.button else DS.Type.label.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Normal), color = p.tint)
    }
}

/** "A", "A and B", "A, B and C". */
internal fun listPhrase(names: List<String>): String = when (names.size) {
    0 -> ""
    1 -> names[0]
    else -> names.dropLast(1).joinToString(", ") + " and " + names.last()
}
