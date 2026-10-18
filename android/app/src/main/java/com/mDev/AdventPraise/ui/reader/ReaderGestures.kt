// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.automirrored.rounded.ArrowForwardIos
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlin.math.PI
import kotlin.math.pow

/**
 * Pinch-to-zoom state shared by the reader and church mode (PinchZoom.swift):
 * the lyric size while fingers are down, clamped to a range, with a limit
 * haptic each time the pinch reaches either end. The caller commits [end].
 */
class PinchZoom {
    /** The size while a pinch is under way; null otherwise. */
    var liveSize: Float? = null
        private set
    /** From the first pinch movement until just after release, so swipes and taps by the same fingers are ignored. */
    var isActive = false
        private set
    private var startSize = 0f
    private var atLimit = false

    fun update(magnification: Float, from: Float, range: ClosedFloatingPointRange<Float>): Float {
        if (liveSize == null) startSize = from
        isActive = true
        val raw = startSize * magnification
        val limited = raw < range.start || raw > range.endInclusive
        if (limited && !atLimit) Haptics.play(HapticEvent.Limit)
        atLimit = limited
        return raw.coerceIn(range).also { liveSize = it }
    }

    /** The size to keep, if the pinch moved at all. */
    fun end(): Float? = liveSize.also { liveSize = null; atLimit = false }

    fun settle() { isActive = false }
}

/**
 * The page swipe's numbers (HymnReaderView.pageGesture): how far to drag
 * before letting go changes the hymn, and which way a drag is going.
 */
object PageSwipe {
    /** min(22 % of the width, 110). */
    fun threshold(width: Float, density: Float): Float = minOf(width * 0.22f, 110f * density)

    /**
     * The axis, decided on the first few points of movement. The leading 24
     * of the screen belong to the system (back); a drag is horizontal when it
     * moves clearly more across than down.
     */
    fun isHorizontal(startX: Float, dx: Float, dy: Float, density: Float): Boolean =
        startX >= 24f * density && kotlin.math.abs(dx) > kotlin.math.abs(dy) * 1.2f

    /** Rubber band (and no arrow) at either end of the hymnal or playlist. */
    fun offset(dx: Float, hasTarget: Boolean): Float = if (hasTarget) dx else dx * 0.2f
}

/** SwiftUI's `.spring(duration:bounce:)` as a Compose spring. */
internal fun <T> swiftSpring(duration: Float, bounce: Float, visibilityThreshold: T? = null) =
    spring(dampingRatio = 1f - bounce, stiffness = (2 * PI / duration).pow(2).toFloat(), visibilityThreshold = visibilityThreshold)

/**
 * The round arrow at the edge the next hymn comes from (PageArrow). It grows
 * and its ring fills as the drag nears the threshold; past it the circle
 * fills solid. Reduce Motion keeps its size and position fixed (fill only).
 */
@Composable
fun PageArrow(forward: Boolean, progress: Float, reduceMotion: Boolean, modifier: Modifier = Modifier) {
    val s = LocalSurface.current
    val p = progress.coerceIn(0f, 1f)
    val armed = progress >= 1f
    val diameter: Dp = if (reduceMotion) 52.dp else (30 + 22 * p).dp
    val scale by animateFloatAsState(
        if (armed && !reduceMotion) 1.08f else 1f,
        if (reduceMotion) tween(0) else swiftSpring(0.25f, 0.35f),
        label = "arrow-armed",
    )
    val density = LocalDensity.current
    Box(
        modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                alpha = minOf(p * 2.5f, 1f)
                translationX = if (reduceMotion) 0f else (if (forward) 1 else -1) * with(density) { 10.dp.toPx() } * (1 - p)
            }
            .size(diameter)
            .shadow(6.dp, CircleShape, ambientColor = Color.Black.copy(alpha = if (s.isDark) 0.4f else 0.12f),
                spotColor = Color.Black.copy(alpha = if (s.isDark) 0.4f else 0.12f))
            .background(if (armed) s.tint else s.elevated, CircleShape)
            .clearAndSetSemantics { },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.matchParentSize()) {
            val ring = 2.dp.toPx()
            drawCircle(s.tint.copy(alpha = 0.3f), radius = size.minDimension / 2 - ring / 2, style = Stroke(ring))
            val arc = 2.5.dp.toPx()
            val inset = 1.25.dp.toPx() + arc / 2
            drawArc(
                s.tint, startAngle = -90f, sweepAngle = 360f * p, useCenter = false,
                topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                size = androidx.compose.ui.geometry.Size(this.size.width - inset * 2, this.size.height - inset * 2),
                style = Stroke(arc, cap = StrokeCap.Round),
            )
        }
        Icon(
            if (forward) Icons.AutoMirrored.Rounded.ArrowForwardIos else Icons.AutoMirrored.Rounded.ArrowBackIos,
            contentDescription = null,
            tint = if (armed) s.onTint else s.tint,
            modifier = Modifier.size(diameter * 0.4f).padding(start = if (forward) 0.dp else diameter * 0.04f),
        )
    }
}

/** Four bars that breathe while music sounds (DSPlaybackBars). Static under Reduce Motion. */
@Composable
fun PlaybackBars(isAnimating: Boolean, color: Color, reduceMotion: Boolean, modifier: Modifier = Modifier, height: Dp = 16.dp) {
    val heights = listOf(0.9f, 0.5f, 1f, 0.65f)
    val transition = rememberInfiniteTransition(label = "bars")
    Row(modifier.height(height).clearAndSetSemantics { }, horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.Bottom) {
        heights.forEachIndexed { i, h ->
            val other = heights[(i + 2) % 4]
            val phase by transition.animateFloat(
                0f, 1f,
                infiniteRepeatable(tween((450 + i * 80), easing = DS.Motion.easeInOut), RepeatMode.Reverse),
                label = "bar$i",
            )
            val scale = when {
                !isAnimating -> 0.3f
                reduceMotion -> h
                else -> other + (h - other) * phase
            }
            Box(Modifier.width(3.dp).height(height * scale).background(color, RoundedCornerShape(1.5.dp)))
        }
    }
}
