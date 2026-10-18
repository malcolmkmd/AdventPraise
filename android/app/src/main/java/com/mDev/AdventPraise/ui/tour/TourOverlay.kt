// OWNER: shell
package com.mDev.AdventPraise.ui.tour

import android.view.accessibility.AccessibilityManager
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateRectAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.TourSource
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.paywall.rememberStillMotion
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalOnGlass
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlin.math.max
import kotlin.math.min

/*
 * How the tour is drawn (TourOverlay.swift, TourRootHost.swift). Controls mark
 * themselves with `Modifier.tourTarget`; one overlay over the whole window
 * (TourHost, above every sheet and cover) reads their bounds and, while the
 * current stage's area is on top, lays a spotlight over everything: a dim with
 * a rounded cut-out around the real control, a brass ring that breathes, and a
 * card that says what to do. Taps inside the cut-out reach the control; taps
 * outside are swallowed (except on the swipe step, which needs the whole page).
 * The hole moves on a short critically damped spring; with animations off, the
 * ring stands still and the card cross-fades.
 */

/**
 * The Destination.Tour route (More's Replay tour): starts the tour and takes
 * itself off the stack at once. The spotlight is TourHost's.
 */
@Composable
fun TourOverlay(services: AppServices, navigator: AppNavigator, source: String, onFinish: () -> Unit) {
    LaunchedEffect(Unit) {
        services.tour.start(TourSource.entries.firstOrNull { it.key == source } ?: TourSource.More)
        onFinish()
    }
}

/** What is presented, without the tour's own route. */
private fun presented(navigator: AppNavigator) = navigator.stack.filter { it !is Destination.Tour }

/**
 * The tour on the whole window (TourRootHost): tells the model what the reader
 * did, keeps its context current, runs what a Next needs done, starts a pending
 * tour once the screen is clear, and draws the spotlight. Mounted once in the
 * root, above the presentation host.
 */
@Composable
fun TourHost(services: AppServices, navigator: AppNavigator) {
    val tour = services.tour
    val reader = services.reader
    val player = services.player

    LaunchedEffect(tour) {
        tour.perform = { action ->
            when (action) {
                TourAction.ResetChrome -> { reader.closeMenu(); reader.closeLectern() }
                TourAction.CloseLectern -> reader.closeLectern()
                TourAction.CloseMenu -> reader.closeMenu()
                TourAction.StopPlayer -> player.stop()
                TourAction.LeaveChurchMode -> navigator.stack.lastOrNull { it is Destination.ChurchMode }?.let(navigator::dismiss)
                TourAction.CloseMore -> navigator.leaveMore()
            }
        }
    }
    // What the reader did (onChange on iOS: changes only, never the first value).
    LaunchedEffect(tour) {
        snapshotFlow { reader.lectern }.distinctUntilChanged().drop(1).collect { tour.observe(TourSignal.Lectern(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { "${reader.hymnal?.info?.id}#${reader.hymn?.number}" }.distinctUntilChanged().drop(1)
            .collect { tour.observe(TourSignal.HymnChanged) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { reader.isMenuOpen }.distinctUntilChanged().drop(1).collect { tour.observe(TourSignal.MenuOpen(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow {
            val hymn = reader.hymn
            val hymnal = reader.hymnal
            hymn != null && hymnal != null && player.isPlaying && player.isHymn(hymnal.info.id, hymn)
        }.distinctUntilChanged().drop(1).collect { tour.observe(TourSignal.Playing(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { navigator.stack.any { it is Destination.Memorise } }.distinctUntilChanged().drop(1)
            .collect { tour.observe(TourSignal.MemoriseOpen(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { navigator.stack.any { it is Destination.ChurchMode } }.distinctUntilChanged().drop(1)
            .collect { tour.observe(TourSignal.ChurchOpen(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { Destination.More in navigator.stack }.distinctUntilChanged().drop(1)
            .collect { tour.observe(TourSignal.MoreOpen(it)) }
    }
    LaunchedEffect(tour) {
        snapshotFlow { reader.hymn?.hasAccompaniment == true }.collect { tour.context = tour.context.copy(hasAccompaniment = it) }
    }
    // A start asked for under What's New (or its Try Worship Mode) goes ahead the
    // moment the screen is clear: nothing presented, no paywall waiting.
    LaunchedEffect(tour) {
        snapshotFlow { tour.pending != null && presented(navigator).isEmpty() && reader.paywall == null }
            .collect { clear -> if (clear) tour.startPending() }
    }

    val stage = tour.stage ?: return
    if (stage.isHidden) return
    val top = presented(navigator).lastOrNull()
    val onTop = when (stage.area) {
        TourArea.Root -> top == null
        TourArea.Church -> top is Destination.ChurchMode
        TourArea.More -> top == Destination.More
    }
    if (!onTop) return
    TourSpotlight(tour, stage, cutout(stage))
}

/** The frame around the stage's controls, a little roomier than they are. */
@Composable
private fun cutout(stage: TourStage): Rect? {
    val density = LocalDensity.current
    val rects = stage.targets.mapNotNull { TourTargets[it] }
    var union = rects.firstOrNull() ?: return null
    rects.drop(1).forEach { union = Rect(min(union.left, it.left), min(union.top, it.top), max(union.right, it.right), max(union.bottom, it.bottom)) }
    if (union.width <= 1f || union.height <= 1f) return null
    return union.inflate(with(density) { DS.Space.s.toPx() })
}

/** The dim, the ring, the touch panes and the card for one stage. */
@Composable
fun TourSpotlight(tour: TourModel, stage: TourStage, cutout: Rect?, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val density = LocalDensity.current
    val still = rememberStillMotion()
    var size by remember { mutableStateOf(Size.Zero) }
    val radius = with(density) { DS.Radius.card.toPx() }

    // The hole, or (a card alone) nothing: a zero rect where the card sits, so the
    // ring folds into the card and grows back out of it.
    val target = cutout ?: Rect(Offset(size.width / 2, size.height * 0.42f), Size.Zero)
    val hole by animateRectAsState(target, if (still) tween(0) else DS.Motion.criticalSpring(0.3f), label = "tour-hole")
    val breathing = if (still) 0f else {
        val transition = rememberInfiniteTransition(label = "tour-ring")
        transition.animateFloat(0f, 1f, infiniteRepeatable(tween(1300, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "breath").value
    }

    Box(modifier.fillMaxSize().onSizeChanged { size = Size(it.width.toFloat(), it.height.toFloat()) }) {
        val dim = if (p.isDark) 0.66f else 0.52f
        Canvas(Modifier.fillMaxSize()) {
            val path = Path().apply {
                fillType = PathFillType.EvenOdd
                addRect(Rect(Offset.Zero, this@Canvas.size))
                if (hole.width > 0f && hole.height > 0f) {
                    val r = min(radius, min(hole.width / 2, hole.height / 2))
                    addRoundRect(RoundRect(hole, CornerRadius(r)))
                }
            }
            drawPath(path, Color.Black.copy(alpha = dim))
            if (hole.width > 0f && hole.height > 0f) {
                // A brass ring, and a soft band outside it in place of a shadow. Breathes with scale and opacity alone.
                val s = 1f + 0.02f * breathing
                scale(s, s, hole.center) {
                    val alpha = 1f - 0.12f * breathing
                    val band = 6.dp.toPx()
                    val line = 2.5.dp.toPx()
                    drawRoundRect(p.brass.copy(alpha = 0.3f * alpha), hole.topLeft - Offset(band / 2, band / 2),
                        Size(hole.width + band, hole.height + band), CornerRadius(radius + band / 2), Stroke(band))
                    drawRoundRect(p.brass.copy(alpha = alpha), hole.topLeft + Offset(line / 2, line / 2),
                        Size(hole.width - line, hole.height - line), CornerRadius(max(0f, radius - line / 2)), Stroke(line))
                }
            }
        }
        // Never animated: the lit control takes a tap at once.
        if (stage.blocksTouches) TouchBlockers(cutout, size)
        TourCardLayer(tour, stage, cutout, size, still)
    }
}

/** Panes around the hole that swallow every touch, so only the lit control can be used. Without a hole, one pane. */
@Composable
private fun TouchBlockers(cutout: Rect?, size: Size) {
    val panes = if (cutout == null) listOf(Rect(Offset.Zero, size)) else listOf(
        Rect(0f, 0f, size.width, max(cutout.top, 0f)),
        Rect(0f, cutout.bottom, size.width, size.height),
        Rect(0f, cutout.top, max(cutout.left, 0f), cutout.bottom),
        Rect(cutout.right, cutout.top, size.width, cutout.bottom),
    )
    val density = LocalDensity.current
    panes.filter { it.width > 0f && it.height > 0f }.forEach { pane ->
        Box(
            Modifier
                .offset { IntOffset(pane.left.toInt(), pane.top.toInt()) }
                .size(with(density) { pane.width.toDp() }, with(density) { pane.height.toDp() })
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) awaitPointerEvent().changes.forEach { it.consume() }
                    }
                },
        )
    }
}

/** The card, placed below the control when it sits in the upper half, above it otherwise. */
@Composable
private fun TourCardLayer(tour: TourModel, stage: TourStage, cutout: Rect?, size: Size, still: Boolean) {
    val density = LocalDensity.current
    val insets = WindowInsets.safeDrawing
    val margin = with(density) { DS.Space.l.toPx() }
    val cardWidth = min(size.width - margin * 2, with(density) { 420.dp.toPx() })
    AnimatedContent(
        targetState = tour.cardId to stage,
        transitionSpec = {
            if (still) fadeIn(tween(0)) togetherWith fadeOut(tween(0))
            else (scaleIn(initialScale = 0.96f) + fadeIn()) togetherWith fadeOut()
        },
        contentKey = { it.first },
        label = "tour-card",
        modifier = Modifier.fillMaxSize(),
    ) { (_, shown) ->
        var height by remember { mutableFloatStateOf(0f) }
        val top = max(insets.getTop(density).toFloat(), margin) + with(density) { DS.Space.s.toPx() } + height / 2
        val bottom = size.height - max(insets.getBottom(density).toFloat(), margin) - with(density) { DS.Space.s.toPx() } - height / 2
        val gap = with(density) { DS.Space.l.toPx() }
        val (x, rawY) = if (cutout != null) {
            val below = cutout.center.y < size.height * 0.5f
            val y = if (below) cutout.bottom + gap + height / 2 else cutout.top - gap - height / 2
            min(max(cutout.center.x, cardWidth / 2 + margin), size.width - cardWidth / 2 - margin) to y
        } else {
            // A card alone: a little above centre, clear of the Lectern.
            size.width / 2 to size.height * 0.42f
        }
        val y = min(max(rawY, top), max(top, bottom))
        Box(Modifier.fillMaxSize()) {
            TourCard(
                tour, shown,
                Modifier
                    .offset { IntOffset((x - cardWidth / 2).toInt(), (y - height / 2).toInt()) }
                    .width(with(density) { cardWidth.coerceAtLeast(0f).toDp() })
                    .onSizeChanged { height = it.height.toFloat() }
                    .graphicsLayer { alpha = if (height == 0f) 0f else 1f },
            )
        }
    }
}

/** The card: the step counter, a title, a line or two, Skip tour and, where the stage explains, Next. */
@Composable
fun TourCard(tour: TourModel, stage: TourStage, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val context = LocalContext.current
    val still = rememberStillMotion()
    // TalkBack always has a way on: the control it is asked to find may be hard to reach.
    val talkBack = remember {
        (context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager)?.isTouchExplorationEnabled == true
    }
    val isLast = tour.phase == TourPhase.Finale
    val asksForATap = !stage.showsNext && stage.target != null
    val showsNext = stage.showsNext || talkBack
    val counter = tour.step?.let { "Step ${it.number} of ${TourStep.entries.size}" } ?: "Tour complete"
    val shape = RoundedCornerShape(DS.Radius.card)
    val focus = remember { FocusRequester() }
    LaunchedEffect(tour.cardId) { if (talkBack) runCatching { focus.requestFocus() } }
    val shadow = Color.Black.copy(alpha = if (p.isDark) 0.5f else 0.18f)

    CompositionLocalProvider(LocalOnGlass provides false) {
        Column(
            modifier
                .shadow(18.dp, shape, ambientColor = shadow, spotColor = shadow)
                .clip(shape)
                .background(p.elevated)
                .border(1.dp, p.brass.copy(alpha = if (p.isDark) 0.35f else 0.28f), shape)
                .padding(DS.Space.panel + 2.dp),
            verticalArrangement = Arrangement.spacedBy(DS.Space.s),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                Icon(Icons.Rounded.AutoAwesome, null, tint = p.brass, modifier = Modifier.size(14.dp))
                Eyebrow(counter, p.brass, tracking = 1.2f)
                Spacer(Modifier.weight(1f))
                Text(
                    "Skip tour", style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = p.secondary,
                    modifier = Modifier
                        .heightIn(min = 32.dp)
                        .clip(RoundedCornerShape(50))
                        .clickable { tour.skip() }
                        .padding(horizontal = DS.Space.xs, vertical = DS.Space.xs)
                        .semantics { role = Role.Button },
                )
            }
            Text(stage.title, style = DS.Type.panelTitle, color = p.foreground,
                modifier = Modifier.focusRequester(focus).focusable().semantics { heading() })
            Text(stage.body, style = DS.Type.detail, color = p.secondary)
            Row(
                Modifier.fillMaxWidth().padding(top = DS.Space.xxs),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
            ) {
                if (asksForATap) {
                    val pulse = if (still) 1f else {
                        val t = rememberInfiniteTransition(label = "tap-pulse")
                        t.animateFloat(1f, 0.45f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse").value
                    }
                    Row(Modifier.weight(1f, fill = false), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                        Icon(Icons.Rounded.TouchApp, null, tint = p.tint, modifier = Modifier.size(16.dp).graphicsLayer { alpha = pulse })
                        Text("Tap the highlighted control", style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = p.tint)
                    }
                }
                Spacer(Modifier.weight(1f))
                if (showsNext) {
                    GlassButton(
                        if (isLast) "Done" else "Next", onClick = { tour.advance() },
                        icon = if (isLast) Icons.Rounded.Check else Icons.AutoMirrored.Rounded.ArrowForward,
                    )
                }
            }
        }
    }
}
