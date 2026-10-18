// OWNER: music
package com.mDev.AdventPraise.ui.sheetmusic

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationState
import androidx.compose.animation.core.animateDecay
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.exponentialDecay
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.data.SheetMusicHighlight
import com.mDev.AdventPraise.data.SheetMusicSystemFrame
import com.mDev.AdventPraise.data.SheetMusicTiming
import com.mDev.AdventPraise.ui.theme.DS
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max

/** Most a page zooms in (WKWebView's maximum-scale=5 on iOS). */
private const val MAX_ZOOM = 5f
/** A double-tap zooms in this far. */
private const val DOUBLE_TAP_ZOOM = 2.5f
/** After a scroll or zoom, the page isn't moved to follow the music for this long. */
private const val HANDS_OFF_MS = 4000L

/**
 * The whole page, scrolling: edge to edge with 4 dp at the sides, padded so
 * its top clears the controls. Pinch or double-tap to zoom (to 5×), drag and
 * fling to scroll. While [follows], the marked measure is kept in view, as
 * iOS scrolls its web view, unless the page was just moved by hand. A tap
 * reports its point in the page's SVG units.
 */
@Composable
internal fun SheetPageView(
    art: SheetMusicArt,
    topInset: Dp,
    bottomInset: Dp,
    highlight: SheetMusicHighlight,
    follows: Boolean,
    accent: Color,
    description: String,
    onTap: (Pair<Double, Double>?) -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val viewWidth = constraints.maxWidth.toFloat()
        val viewHeight = constraints.maxHeight.toFloat()
        val side = with(density) { 4.dp.toPx() }
        val top = with(density) { topInset.toPx() }
        val bottom = with(density) { bottomInset.toPx() }
        val unit = (viewWidth - side * 2) / art.width.toFloat()
        val contentHeight = top + art.height.toFloat() * unit + bottom

        var zoom by remember(art) { mutableFloatStateOf(1f) }
        var x by remember(art) { mutableFloatStateOf(0f) }
        var y by remember(art) { mutableFloatStateOf(0f) }
        var touchedAt by remember { mutableLongStateOf(0L) }
        var gesturing by remember { mutableStateOf(false) }
        val scope = rememberCoroutineScope()
        var motion by remember { mutableStateOf<Job?>(null) }

        fun maxX(z: Float) = max(0f, viewWidth * z - viewWidth)
        fun maxY(z: Float) = max(0f, contentHeight * z - viewHeight)
        fun place(z: Float, nx: Float, ny: Float) {
            zoom = z.coerceIn(1f, MAX_ZOOM)
            x = nx.coerceIn(0f, maxX(zoom))
            y = ny.coerceIn(0f, maxY(zoom))
        }

        /** Animates to a zoom and offset (double-tap, following). */
        fun animateTo(z: Float, nx: Float, ny: Float, millis: Int = 300) {
            motion?.cancel()
            val fromZ = zoom; val fromX = x; val fromY = y
            val toZ = z.coerceIn(1f, MAX_ZOOM)
            val toX = nx.coerceIn(0f, maxX(toZ)); val toY = ny.coerceIn(0f, maxY(toZ))
            motion = scope.launch {
                val t = Animatable(0f)
                t.animateTo(1f, tween(millis, easing = DS.Motion.easeInOut)) {
                    val f = value
                    place(fromZ + (toZ - fromZ) * f, fromX + (toX - fromX) * f, fromY + (toY - fromY) * f)
                }
            }
        }

        // Keep the place sensible when the size changes (rotation, controls).
        LaunchedEffect(viewWidth, viewHeight, contentHeight) { place(zoom, x, y) }

        // Following: bring the measure's system up near the top, under the controls.
        LaunchedEffect(highlight.measure, follows) {
            val box = highlight.measure ?: return@LaunchedEffect
            if (!follows || gesturing || System.currentTimeMillis() - touchedAt < HANDS_OFF_MS) return@LaunchedEffect
            val boxTop = (top + box.y.toFloat() * unit) * zoom
            val boxBottom = (top + (box.y + box.height).toFloat() * unit) * zoom
            val boxLeft = (side + box.x.toFloat() * unit) * zoom
            val boxRight = (side + (box.x + box.width).toFloat() * unit) * zoom
            var ty = y
            var tx = x
            if (boxTop < y + top || boxBottom > y + viewHeight - bottom) ty = boxTop - top - (viewHeight - top - bottom) * 0.12f
            if (boxLeft < x || boxRight > x + viewWidth) tx = boxLeft - with(density) { 16.dp.toPx() }
            if (tx != x || ty != y) animateTo(zoom, tx, ty, 450)
        }

        val slop = LocalViewConfiguration.current.touchSlop
        Canvas(
            Modifier
                .fillMaxSize()
                .clipToBounds()
                .semantics { contentDescription = description }
                .pointerInput(art, contentHeight) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        motion?.cancel()
                        val tracker = VelocityTracker()
                        tracker.addPosition(down.uptimeMillis, down.position)
                        var moving = false
                        var travelled = Offset.Zero
                        var scaled = 1f
                        do {
                            val event = awaitPointerEvent()
                            if (event.changes.any { it.isConsumed }) break
                            val zoomChange = event.calculateZoom()
                            val pan = event.calculatePan()
                            val centroid = event.calculateCentroid(useCurrent = false)
                            if (!moving) {
                                travelled += pan
                                scaled *= zoomChange
                                if (travelled.getDistance() > slop || abs(1 - scaled) * viewWidth / 2 > slop) {
                                    moving = true
                                    gesturing = true
                                }
                            }
                            if (moving) {
                                val z = (zoom * zoomChange).coerceIn(1f, MAX_ZOOM)
                                val factor = z / zoom
                                place(z, (x + centroid.x) * factor - centroid.x - pan.x, (y + centroid.y) * factor - centroid.y - pan.y)
                                touchedAt = System.currentTimeMillis()
                                event.changes.forEach { if (it.positionChanged()) it.consume() }
                            }
                            if (event.changes.size == 1) event.changes[0].let { tracker.addPosition(it.uptimeMillis, it.position) }
                        } while (event.changes.any { it.pressed })
                        gesturing = false
                        if (moving) {
                            val velocity = tracker.calculateVelocity()
                            motion = scope.launch {
                                coroutineScope {
                                    launch {
                                        var last = 0f
                                        AnimationState(0f, -velocity.y).animateDecay(exponentialDecay()) {
                                            val before = y
                                            place(zoom, x, y + (value - last))
                                            last = value
                                            touchedAt = System.currentTimeMillis()
                                            if (y == before && abs(velocity.y) > 0) cancelAnimation()
                                        }
                                    }
                                    launch {
                                        var last = 0f
                                        AnimationState(0f, -velocity.x).animateDecay(exponentialDecay()) {
                                            val before = x
                                            place(zoom, x + (value - last), y)
                                            last = value
                                            if (x == before) cancelAnimation()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .pointerInput(art, contentHeight, unit) {
                    detectTapGestures(
                        onTap = { pos ->
                            val px = ((pos.x + x) / zoom - side) / unit
                            val py = ((pos.y + y) / zoom - top) / unit
                            onTap(px.toDouble() to py.toDouble())
                        },
                        onDoubleTap = { pos ->
                            touchedAt = System.currentTimeMillis()
                            if (zoom > 1.01f) {
                                animateTo(1f, x / zoom, y / zoom)
                            } else {
                                val cx = (pos.x + x) / zoom
                                val cy = (pos.y + y) / zoom
                                animateTo(DOUBLE_TAP_ZOOM, cx * DOUBLE_TAP_ZOOM - viewWidth / 2, cy * DOUBLE_TAP_ZOOM - viewHeight / 2)
                            }
                        },
                    )
                },
        ) {
            translate(-x, -y) {
                scale(zoom, zoom, pivot = Offset.Zero) {
                    drawSheetMusic(art, Offset(side, top), unit, highlight, accent)
                }
            }
        }
    }
}

/**
 * One system at a time, as large as fits between [top] and [bottom]: the
 * page placed and clipped so the system's band fills the width, moving to
 * the next with a 0.3 s slide. Swipe left or right for the next or
 * previous; taps report their point in SVG units.
 */
@Composable
internal fun SheetSystemView(
    art: SheetMusicArt,
    geometry: SheetMusicTiming.Geometry?,
    systemIndex: Int,
    top: Dp,
    bottom: Dp,
    highlight: SheetMusicHighlight,
    accent: Color,
    description: String,
    onTap: (Pair<Double, Double>?) -> Unit,
    onSwipe: (Int) -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val g = geometry
        val band = g?.systems?.getOrNull(systemIndex)
        val side = DS.Space.xs.value.toDouble()
        val frame = if (g == null || band == null) null else {
            val (extentX, extentWidth) = g.systemExtent
            SheetMusicSystemFrame.fit(
                band, extentX, extentWidth, art.width, art.height,
                side, top.value.toDouble(), maxWidth.value - side * 2, (maxHeight - top - bottom).value.toDouble(),
            )
        } ?: return@BoxWithConstraints
        val spec = tween<Float>(300, easing = DS.Motion.easeInOut)
        val scale by animateFloatAsState(frame.scale.toFloat(), spec, label = "sys-scale")
        val fx by animateFloatAsState(frame.x.toFloat(), spec, label = "sys-x")
        val fy by animateFloatAsState(frame.y.toFloat(), spec, label = "sys-y")
        val clipTop by animateFloatAsState(frame.clipTop.toFloat(), spec, label = "sys-ct")
        val clipBottom by animateFloatAsState(frame.clipBottom.toFloat(), spec, label = "sys-cb")
        val clipLeft by animateFloatAsState(frame.clipLeft.toFloat(), spec, label = "sys-cl")
        val clipRight by animateFloatAsState(frame.clipRight.toFloat(), spec, label = "sys-cr")
        val density = LocalDensity.current.density
        val swipe = with(LocalDensity.current) { 40.dp.toPx() }
        Canvas(
            Modifier
                .fillMaxSize()
                .semantics { contentDescription = description }
                .pointerInput(frame) {
                    detectTapGestures { pos ->
                        onTap(frame.pagePoint(pos.x / density.toDouble(), pos.y / density.toDouble()))
                    }
                }
                .pointerInput(Unit) {
                    var total = 0f
                    detectHorizontalDragGestures(
                        onDragStart = { total = 0f },
                        onDragEnd = { if (abs(total) > swipe) onSwipe(if (total < 0) 1 else -1) },
                        onHorizontalDrag = { change, amount -> total += amount; change.consume() },
                    )
                },
        ) {
            val s = scale * density
            val ox = fx * density
            val oy = fy * density
            val pageW = art.width.toFloat() * s
            val pageH = art.height.toFloat() * s
            clipRect(ox + clipLeft * density, oy + clipTop * density, ox + pageW - clipRight * density, oy + pageH - clipBottom * density) {
                drawSheetMusic(art, Offset(ox, oy), s, highlight, accent)
            }
        }
    }
}

/**
 * The free preview: the top of the page (or its first system and the start
 * of the next) fading out towards the Pro button. Doesn't scroll, zoom or
 * take taps.
 */
@Composable
internal fun SheetPreview(art: SheetMusicArt, modifier: Modifier, frame: SheetMusicSystemFrame?, description: String) {
    Canvas(
        modifier
            .clipToBounds()
            .semantics { contentDescription = description }
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen },
    ) {
        if (frame == null) {
            val side = 4.dp.toPx()
            val unit = (size.width - side * 2) / art.width.toFloat()
            drawSheetMusic(art, Offset(side, 8.dp.toPx()), unit, SheetMusicHighlight.none, Color.Transparent)
        } else {
            val s = frame.scale.toFloat() * density
            val ox = frame.x.toFloat() * density
            val oy = frame.y.toFloat() * density
            clipRect(ox + frame.clipLeft.toFloat() * density, oy + frame.clipTop.toFloat() * density,
                ox + art.width.toFloat() * s - frame.clipRight.toFloat() * density,
                oy + art.height.toFloat() * s - frame.clipBottom.toFloat() * density) {
                drawSheetMusic(art, Offset(ox, oy), s, SheetMusicHighlight.none, Color.Transparent)
            }
        }
        // Opaque to 55 % of the height, then fading out.
        drawRect(
            Brush.verticalGradient(0f to Color.Black, 0.55f to Color.Black, 1f to Color.Transparent),
            blendMode = BlendMode.DstIn,
        )
    }
}

