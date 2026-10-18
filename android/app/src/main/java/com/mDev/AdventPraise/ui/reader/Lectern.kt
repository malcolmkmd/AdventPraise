// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.OnGlass
import com.mDev.AdventPraise.ui.design.dsGlass
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.player.LecternPlayer
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.tour.TourTarget
import com.mDev.AdventPraise.ui.tour.tourTarget
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/** Which of the row's buttons owns the open panel (ReaderToolbarPanel). */
enum class ReaderToolbarPanel { None, Hymn, Jump, Library }

private fun LecternState.toolbarPanel(): ReaderToolbarPanel = when (this) {
    LecternState.Collapsed -> ReaderToolbarPanel.None
    LecternState.Pad, LecternState.Search -> ReaderToolbarPanel.Jump
    LecternState.Library -> ReaderToolbarPanel.Library
    LecternState.Hymn -> ReaderToolbarPanel.Hymn
}

/**
 * The Lectern (LecternView): the reader's ReaderToolbar, wired to the model,
 * the accompaniment, the free plays and the panels. The transport sits on the
 * row, collapsed or under the hymn tray, so opening the tray from the title
 * never hides or reveals the player; the pad, search and library take its
 * place while they're open. On wide windows the library button shows or
 * hides the hymn list beside the reader.
 */
@Composable
fun Lectern(services: AppServices, wide: Boolean, modifier: Modifier = Modifier) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val player = services.player
    val store = services.store
    val freePlays = services.freePlays
    val hymnal = model.hymnal
    val hymn = model.hymn ?: return
    // The player has this hymn (and not the same number in another hymnal).
    val isPlayersHymn = hymnal != null && player.isLoaded(hymnal.id, hymn)
    val isPlaying = isPlayersHymn && player.isPlaying
    // Play opens the paywall: the lock on the button.
    val playIsLocked = !isPlayersHymn && !store.isPlayerUnlocked && freePlays.locksNewPlay
    val progress = model.playlistProgress
    val status = when {
        // The transport above shows the verse; the row just says what's going on.
        isPlayersHymn -> if (isPlaying) "Playing · piano" else "Paused · piano"
        progress != null -> progress
        !hymn.hasAccompaniment -> hymnal?.name.orEmpty()
        // A quiet word before the last free play (alone: the row is too short for more).
        !store.isPlayerUnlocked && !freePlays.isTourActive && freePlays.allowance.isLastPlay -> "1 free play left"
        else -> "${hymnal?.name.orEmpty()} · piano ready"
    }

    fun playTapped() {
        if (hymnal == null) return
        val starting = !isPlaying
        when {
            isPlaying -> player.pause()
            isPlayersHymn -> player.resume()
            playIsLocked -> {
                // Free plays used up: the paywall instead, so no play haptic.
                Analytics.track(AnalyticsEvent.PlayLimitPaywallShown(hymn.number))
                navigator.openPaywall(ProFeature.Player, "reader")
                return
            }
            else -> {
                if (!player.start(hymnal.id, hymn)) return
                if (!store.isPlayerUnlocked && !freePlays.isTourActive) {
                    Analytics.track(AnalyticsEvent.FreePlayUsed(hymn.number, freePlays.spend()))
                }
            }
        }
        Haptics.play(HapticEvent.toggle(starting))
    }

    val lectern = model.lectern
    val jumpFamily = lectern == LecternState.Pad || lectern == LecternState.Search
    ReaderToolbar(
        number = hymn.number,
        title = hymn.title,
        status = status,
        isPlaying = isPlaying,
        hasAccompaniment = hymn.hasAccompaniment,
        playIsLocked = playIsLocked,
        openPanel = lectern.toolbarPanel(),
        libraryIsOn = if (wide) model.isSidebarVisible else null,
        onPlay = ::playTapped,
        // The title only opens the tray: tapping it again leaves the tray as it is.
        onHymn = { if (model.lectern != LecternState.Hymn) model.openLectern(LecternState.Hymn) },
        onJump = { if (jumpFamily) model.closeLectern() else model.openLectern(LecternState.Pad) },
        onLibrary = {
            when {
                wide -> model.isSidebarVisible = !model.isSidebarVisible
                model.lectern == LecternState.Library -> model.closeLectern()
                else -> model.openLectern(LecternState.Library)
            }
        },
        onDismiss = { model.closeLectern() },
        onExpand = { if (model.lectern == LecternState.Collapsed) model.openLectern(LecternState.Hymn) },
        panelKey = lectern,
        modifier = modifier,
    ) { state ->
        when (state) {
            LecternState.Collapsed -> Unit
            LecternState.Hymn -> LecternHymnTray(services)
            LecternState.Pad -> LecternNumberPad(services)
            LecternState.Search -> LecternSearchPanel(services)
            LecternState.Library -> LecternLibraryPanel(services)
        }
        AnimatedVisibility(isPlayersHymn && (state == LecternState.Collapsed || state == LecternState.Hymn), enter = fadeIn(), exit = fadeOut()) {
            Box(Modifier.tourTarget(TourTarget.Transport)) { LecternPlayer(services, navigator) }
        }
    }
}

/**
 * The Lectern's chrome (ReaderToolbar.swift): one floating glass capsule at
 * the bottom, under the thumb. The 64 dp row is the spine and never moves;
 * panels unfold upward out of it inside the same glass, then settle back.
 *
 *          [ ⌃ handle ]
 *   Row:  [▶ play]  [30 Blessed Assurance / status]  [⌗ jump]  [🔖 library]
 *
 * The title opens the hymn tray (only ever opens it). The handle toggles: tap
 * or swipe up to expand, tap or swipe down to collapse. One open highlight
 * slides between the title, jump and library. Full width minus 20 dp each
 * side, capped at 560 dp.
 */
@Composable
fun ReaderToolbar(
    number: Int,
    title: String,
    status: String,
    modifier: Modifier = Modifier,
    isPlaying: Boolean = false,
    hasAccompaniment: Boolean = false,
    playIsLocked: Boolean = false,
    openPanel: ReaderToolbarPanel = ReaderToolbarPanel.None,
    /** Wide windows: the hymn list stands in for the library panel; non-null lights the button while it shows. */
    libraryIsOn: Boolean? = null,
    onPlay: () -> Unit = {},
    onHymn: () -> Unit = {},
    onJump: () -> Unit = {},
    onLibrary: () -> Unit = {},
    onDismiss: () -> Unit = {},
    /** Opens the hymn tray if nothing is open; idempotent. Defaults to [onHymn]. */
    onExpand: (() -> Unit)? = null,
    /** Identifies the panel showing, so a change animates as one transaction. */
    panelKey: LecternState = LecternState.Collapsed,
    panel: @Composable ColumnScope.(LecternState) -> Unit = {},
) {
    val reduceMotion = rememberReduceMotion()
    val isOpen = openPanel != ReaderToolbarPanel.None
    val radius by animateDpAsState(if (isOpen) DS.Radius.panel else DS.Radius.dock, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "lectern-radius")
    val shape = dsShape(radius)
    val expand = onExpand ?: onHymn
    val density = LocalDensity.current
    val fade = DS.Motion.adaptive(DS.Motion.lectern<Float>(), reduceMotion) as FiniteAnimationSpec<Float>
    val slide = DS.Motion.adaptive(DS.Motion.lectern<IntOffset>(), reduceMotion) as FiniteAnimationSpec<IntOffset>
    val resize = DS.Motion.adaptive(DS.Motion.lectern<IntSize>(), reduceMotion) as FiniteAnimationSpec<IntSize>
    Box(
        modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars.union(WindowInsets.ime))
            .padding(horizontal = DS.Space.l)
            .padding(bottom = DS.Space.s),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Column(
            Modifier
                .widthIn(max = DS.Space.lecternMaxWidth)
                .fillMaxWidth()
                .dsGlass(shape, DS.GlassDepth.Dock)
                // Swipe up expands, swipe down collapses.
                .pointerInput(isOpen) {
                    var total = 0f
                    val travel = with(density) { 40.dp.toPx() }
                    detectVerticalDragGestures(
                        onDragStart = { total = 0f },
                        onDragEnd = {
                            if (total < -travel && !isOpen) expand()
                            if (total > travel && isOpen) onDismiss()
                        },
                    ) { _, dy -> total += dy }
                }
                .semantics { if (isOpen) customActions = listOf(CustomAccessibilityAction("Collapse") { onDismiss(); true }) },
        ) {
            OnGlass {
                LecternHandle(isOpen, reduceMotion, onToggle = if (isOpen) onDismiss else expand)
                // Panels unfold from the row: they rise out of its top edge and
                // fade, while the glass grows around them in the same transaction.
                AnimatedContent(
                    targetState = panelKey,
                    transitionSpec = {
                        val enter = if (reduceMotion) fadeIn(fade) else fadeIn(fade) + slideInVertically(slide) { it / 3 }
                        val exit = if (reduceMotion) fadeOut(fade) else fadeOut(fade) + slideOutVertically(slide) { it / 3 }
                        (enter togetherWith exit).using(SizeTransform(clip = true) { _, _ -> resize })
                    },
                    label = "lectern-panel",
                ) { state -> Column(Modifier.fillMaxWidth()) { panel(state) } }
                ToolbarRow(
                    number, title, status, isPlaying, hasAccompaniment, playIsLocked, openPanel, libraryIsOn,
                    onPlay, onHymn, onJump, onLibrary, onDismiss, reduceMotion,
                )
            }
        }
    }
}

/**
 * A small chevron at the top of the capsule that expands the Lectern to the
 * hymn tray and collapses whatever is open. The visible strip is 18 dp; the
 * touch target reaches past it. It turns with the Lectern; under Reduce
 * Motion it stays upright and swaps to a down chevron instead.
 */
@Composable
private fun LecternHandle(isOpen: Boolean, reduceMotion: Boolean, onToggle: () -> Unit) {
    val p = LocalSurface.current
    val turn by animateFloatAsState(if (!reduceMotion && isOpen) 180f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "handle")
    val interaction = remember { MutableInteractionSource() }
    Box(Modifier.fillMaxWidth().height(18.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .minimumInteractiveComponentSize()
                .size(88.dp, 18.dp)
                .dsPress(interaction)
                .clickable(interaction, null, role = Role.Button, onClick = onToggle)
                .clearAndSetSemantics {
                    contentDescription = "Hymn actions"
                    stateDescription = if (isOpen) "Expanded" else "Collapsed"
                    role = Role.Button
                    customActions = listOf(CustomAccessibilityAction(if (isOpen) "Collapse" else "Expand") { onToggle(); true })
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (reduceMotion && isOpen) Icons.Rounded.KeyboardArrowDown else Icons.Rounded.KeyboardArrowUp,
                contentDescription = null,
                tint = p.secondary,
                modifier = Modifier.size(20.dp).rotate(turn),
            )
        }
    }
}

private enum class WashSlot { Hymn, Jump, Library }

@Composable
private fun ToolbarRow(
    number: Int,
    title: String,
    status: String,
    isPlaying: Boolean,
    hasAccompaniment: Boolean,
    playIsLocked: Boolean,
    openPanel: ReaderToolbarPanel,
    libraryIsOn: Boolean?,
    onPlay: () -> Unit,
    onHymn: () -> Unit,
    onJump: () -> Unit,
    onLibrary: () -> Unit,
    onDismiss: () -> Unit,
    reduceMotion: Boolean,
) {
    val p = LocalSurface.current
    val isOpen = openPanel != ReaderToolbarPanel.None
    val divider by animateFloatAsState(if (isOpen) 0.6f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "divider")
    // Where each button sits, for the one open highlight that slides between them.
    val bounds = remember { mutableStateMapOf<WashSlot, Rect>() }
    var origin by remember { mutableStateOf(Offset.Zero) }
    val libraryShared = libraryIsOn == null
    val washSlot = when (openPanel) {
        ReaderToolbarPanel.Hymn -> WashSlot.Hymn
        ReaderToolbarPanel.Jump -> WashSlot.Jump
        ReaderToolbarPanel.Library -> if (libraryShared) WashSlot.Library else null
        ReaderToolbarPanel.None -> null
    }
    var lastSlot by remember { mutableStateOf(WashSlot.Hymn) }
    if (washSlot != null && washSlot != lastSlot) lastSlot = washSlot
    Box(Modifier.fillMaxWidth().onGloballyPositioned { origin = it.positionInRoot() }) {
        Box(Modifier.fillMaxWidth().height(1.dp).graphicsLayer { alpha = divider }.background(p.primary(DS.Fill.stroke)))
        SlidingWash(bounds[lastSlot]?.translate(-origin), lastSlot == WashSlot.Hymn, washSlot != null, reduceMotion)
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = DS.Size.lecternRow)
                .padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
        ) {
            Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                PlayButton(isPlaying, hasAccompaniment, playIsLocked, reduceMotion, onPlay)
                // Always onHymn, never a toggle: the title does one thing in every state.
                HymnHandleButton(
                    number, title, status, isPlaying, isOpen = openPanel == ReaderToolbarPanel.Hymn, reduceMotion = reduceMotion,
                    onClick = onHymn,
                    modifier = Modifier.weight(1f).tourTarget(TourTarget.Title).onGloballyPositioned { bounds[WashSlot.Hymn] = it.boundsInRoot() },
                )
            }
            ToolbarIconButton(
                Icons.Rounded.Apps, "Go to a hymn number or search", isOn = openPanel == ReaderToolbarPanel.Jump,
                ownWash = false,
                onClick = if (openPanel == ReaderToolbarPanel.Jump) onDismiss else onJump,
                modifier = Modifier.tourTarget(TourTarget.Jump).onGloballyPositioned { bounds[WashSlot.Jump] = it.boundsInRoot() },
            )
            val libraryOn = libraryIsOn ?: (openPanel == ReaderToolbarPanel.Library)
            ToolbarIconButton(
                if (libraryOn) Icons.Rounded.Bookmark else Icons.Rounded.BookmarkBorder, "Favourites and playlists", isOn = libraryOn,
                // Wide windows: lit by the hymn list, which can show alongside an open panel.
                ownWash = !libraryShared,
                onClick = if (openPanel == ReaderToolbarPanel.Library) onDismiss else onLibrary,
                modifier = Modifier.onGloballyPositioned { bounds[WashSlot.Library] = it.boundsInRoot() },
            )
        }
    }
}

/**
 * The tint wash behind the open button: one shape that moves between the
 * title, jump and library on the Lectern's spring. Under Reduce Motion it
 * fades in place instead of sliding.
 */
@Composable
private fun SlidingWash(rect: Rect?, onTitle: Boolean, visible: Boolean, reduceMotion: Boolean) {
    if (rect == null) return
    val p = LocalSurface.current
    val density = LocalDensity.current
    val move: FiniteAnimationSpec<Dp> = if (reduceMotion) snap() else DS.Motion.lectern<Dp>() as FiniteAnimationSpec<Dp>
    val x by animateDpAsState(with(density) { rect.left.toDp() }, move, label = "wash-x")
    val y by animateDpAsState(with(density) { rect.top.toDp() }, move, label = "wash-y")
    val w by animateDpAsState(with(density) { rect.width.toDp() }, move, label = "wash-w")
    val h by animateDpAsState(with(density) { rect.height.toDp() }, move, label = "wash-h")
    val r by animateDpAsState(if (onTitle) DS.Radius.key else DS.Radius.tile, move, label = "wash-r")
    val opacity = if (onTitle) DS.Fill.tintActive else DS.Fill.tintOn
    val alpha by animateFloatAsState(if (visible) 1f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "wash-a")
    Box(
        Modifier
            .offset(x, y)
            .size(w, h)
            .graphicsLayer { this.alpha = alpha }
            .background(p.tint.copy(alpha = opacity), dsShape(r)),
    )
}

/**
 * Always in the row so the title beside it slides rather than jumps when a
 * hymn with (or without) accompaniment opens. Without one it folds to no
 * width, fades and stops taking touches.
 */
@Composable
private fun PlayButton(isPlaying: Boolean, hasAccompaniment: Boolean, playIsLocked: Boolean, reduceMotion: Boolean, onPlay: () -> Unit) {
    val p = LocalSurface.current
    val width by animateDpAsState(
        if (hasAccompaniment) DS.Size.hitTarget + DS.Space.s else 0.dp,
        DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "play-width",
    )
    val shown by animateFloatAsState(if (hasAccompaniment) 1f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "play-shown")
    val interaction = remember { MutableInteractionSource() }
    Box(Modifier.width(width).height(DS.Size.hitTarget).tourTarget(TourTarget.Play), contentAlignment = Alignment.CenterStart) {
        if (shown > 0f) {
            Box(
                Modifier
                    .graphicsLayer {
                        alpha = shown
                        val s = if (reduceMotion) 1f else 0.5f + 0.5f * shown
                        scaleX = s
                        scaleY = s
                    }
                    .size(DS.Size.hitTarget)
                    .dsPress(interaction, hasAccompaniment)
                    .shadow(6.dp, CircleShape, clip = false, ambientColor = p.tint.copy(alpha = 0.35f), spotColor = p.tint.copy(alpha = 0.35f))
                    .background(p.tint, CircleShape)
                    .clickable(interaction, null, enabled = hasAccompaniment, role = Role.Button, onClick = onPlay)
                    .clearAndSetSemantics {
                        if (hasAccompaniment) {
                            contentDescription = if (isPlaying) "Pause accompaniment" else "Play accompaniment"
                            role = Role.Button
                            if (playIsLocked) stateDescription = "Advent Praise Pro. Shows what Pro includes."
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, null, tint = p.onTint, modifier = Modifier.size(24.dp))
                if (playIsLocked) {
                    Box(
                        Modifier
                            .align(Alignment.TopEnd)
                            .offset(3.dp, (-3).dp)
                            .size(16.dp)
                            .background(p.brass, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.Lock, null, tint = p.onTint, modifier = Modifier.size(9.dp)) }
                }
            }
        }
    }
}

/**
 * The hymn number and title, which also open the hymn tray. The handle's
 * chevron above is the cue that there is more; the sliding wash marks it open.
 */
@Composable
private fun HymnHandleButton(
    number: Int,
    title: String,
    status: String,
    isPlaying: Boolean,
    isOpen: Boolean,
    reduceMotion: Boolean,
    onClick: () -> Unit,
    modifier: Modifier,
) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressFill by animateFloatAsState(if (pressed) DS.Fill.hairline else 0f, DS.Motion.press(), label = "row-press")
    val scale by animateFloatAsState(if (pressed && !reduceMotion) 0.98f else 1f, DS.Motion.press(), label = "row-scale")
    Box(
        modifier
            .heightIn(min = DS.Size.lecternRow)
            .clickable(interaction, null, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Hymn $number, $title"
                stateDescription = status
                role = Role.Button
                selected = isOpen
            },
        contentAlignment = Alignment.CenterStart,
    ) {
        Column(
            Modifier
                .graphicsLayer { scaleX = scale; scaleY = scale }
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .background(p.foreground.copy(alpha = pressFill), dsShape(DS.Radius.key))
                .padding(horizontal = DS.Space.s),
            verticalArrangement = Arrangement.spacedBy(DS.Space.hair, Alignment.CenterVertically),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
                Text(number.toString(), style = DS.Type.numeral.copy(fontFeatureSettings = "tnum"), color = p.brass, maxLines = 1, softWrap = false)
                Text(title, style = DS.Type.label, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
                Text(status, style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false))
                // Always present, so starting playback doesn't reflow the status.
                PlaybackBars(isPlaying, p.tint, reduceMotion, Modifier.graphicsLayer { alpha = if (isPlaying) 1f else 0f }, height = 12.dp)
            }
        }
    }
}

@Composable
private fun ToolbarIconButton(
    icon: ImageVector,
    label: String,
    isOn: Boolean,
    ownWash: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val shape = dsShape(DS.Radius.tile)
    Box(
        modifier
            .size(DS.Size.hitTarget)
            .dsPress(interaction)
            .clip(shape)
            .background(
                when {
                    isOn && ownWash -> p.tint.copy(alpha = DS.Fill.tintOn)
                    isOn -> Color.Transparent
                    else -> p.primary(DS.Fill.inset)
                },
            )
            .clickable(interaction, null, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button; selected = isOn },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = if (isOn) p.tint else p.foreground, modifier = Modifier.size(22.dp))
    }
}
