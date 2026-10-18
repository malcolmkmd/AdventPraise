// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.ui.design.dsGlass
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * The reader's scroll-driven header (HymnHeaderMorph.swift). At rest the number
 * and title sit large at the top of the text; as the text scrolls they shrink,
 * lift and fade into a compact capsule pinned in the top bar, number and title
 * side by side, whose glass fades in behind them. Scrolling back reverses it
 * exactly: everything is a function of the scroll offset. Only the large
 * header's layer and the compact header read the progress.
 */

/** How far the header has collapsed: 0 at rest, 1 once the large title has scrolled away. */
@Stable
class HeaderMorph {
    var progress by mutableFloatStateOf(0f)
        private set
    /** Faded out while the hymn is paged away, so the old title doesn't linger over the incoming hymn. */
    var isHidden by mutableStateOf(false)
    /** The scroll distance (px) over which the header collapses: the large header's height. */
    var range: Float = 120f

    /** Past this, Reduce Motion shows the compact header (a crossfade, not a morph). */
    val isCollapsed: Boolean get() = progress > 0.6f

    /** `distance` is how far the text has scrolled from the top, in px. */
    fun update(distance: Float) {
        val p = (distance / max(range, 1f)).coerceIn(0f, 1f)
        // Inside the text, scrolling leaves this at 1 and nothing updates.
        if (abs(p - progress) > 0.002f || (p != progress && (p == 0f || p == 1f))) progress = p
    }
}

/** 0 below `a`, 1 above `b`, an S-curve between. */
internal fun smoothstep(a: Float, b: Float, x: Float): Float {
    val t = ((x - a) / (b - a)).coerceIn(0f, 1f)
    return t * t * (3 - 2 * t)
}

/** Ease-out: quick at first, settling into place. */
internal fun ease(t: Float): Float = 1 - (1 - t) * (1 - t)

/**
 * Shrinks, lifts and fades the large header toward the bar as it collapses
 * (HeaderCollapseEffect). Read in the layer, so scrolling never recomposes the
 * header. Under Reduce Motion it scrolls away as it is.
 */
fun Modifier.headerCollapse(morph: HeaderMorph, centered: Boolean, reduceMotion: Boolean, lift: Float): Modifier =
    if (reduceMotion) this else graphicsLayer {
        val p = morph.progress
        val s = 1 - 0.14f * ease(p)
        scaleX = s
        scaleY = s
        transformOrigin = if (centered) TransformOrigin(0.5f, 0f) else TransformOrigin(0f, 0f)
        // Moves up a little faster than the text, toward the bar.
        translationY = -lift * ease(p)
        // Mostly gone by the time the title passes under the bar, where the compact header is arriving.
        alpha = 1 - smoothstep(0.15f, 0.75f, p)
    }

/**
 * Number and title side by side in one line, pinned in the top bar
 * (CompactHymnHeader). Sized by the landed (semibold) line and drawn at the
 * current weight, so its width never changes while scrolling. Tapping it
 * scrolls back to the top. VoiceOver/TalkBack read the large header instead.
 */
@Composable
fun CompactHymnHeader(
    morph: HeaderMorph,
    number: Int,
    title: String,
    centered: Boolean,
    maxWidth: Dp,
    reduceMotion: Boolean,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val collapsed by animateFloatAsState(if (morph.isCollapsed) 1f else 0f, tween(200, easing = DS.Motion.easeInOut), label = "compact-rm")
    val hidden by animateFloatAsState(if (morph.isHidden) 0f else 1f, tween(160, easing = DS.Motion.easeOut), label = "compact-hidden")
    // Reduce Motion: on or off past the midpoint, crossfaded.
    val t = if (reduceMotion) collapsed else smoothstep(0.45f, 0.95f, morph.progress)
    val shown = t * hidden
    val glassAlpha = smoothstep(0.7f, 1f, t)
    val glassShape = RoundedCornerShape(50)
    val density = LocalDensity.current
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .widthIn(max = maxWidth)
            .graphicsLayer {
                val s = if (reduceMotion) 1f else 1.08f - 0.08f * t
                scaleX = s
                scaleY = s
                transformOrigin = if (centered) TransformOrigin.Center else TransformOrigin(0f, 0.5f)
                translationY = if (reduceMotion) 0f else with(density) { 8.dp.toPx() } * (1 - t)
                alpha = shown
            }
            .clearAndSetSemantics { }
            .then(if (shown > 0.5f) Modifier.clickable(interaction, null, onClick = onTap) else Modifier),
    ) {
        // The capsule's glass fades in once it has nearly landed.
        Box(Modifier.matchParentSize().alpha(glassAlpha).then(if (glassAlpha > 0f) Modifier.dsGlass(glassShape) else Modifier))
        Box(Modifier.heightIn(min = 36.dp).padding(horizontal = DS.Space.panel, vertical = DS.Space.xs), contentAlignment = Alignment.CenterStart) {
            // The landed line holds the size; the live weight draws over it.
            Box(Modifier.alpha(0f)) { CompactLine(number, title, 1f) }
            CompactLine(number, title, t)
        }
    }
}

@Composable
private fun CompactLine(number: Int, title: String, weight: Float) {
    val p = LocalSurface.current
    val style = compactFont(weight)
    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
        Text(number.toString(), style = style.copy(fontFeatureSettings = "tnum"), color = p.brass, maxLines = 1, softWrap = false)
        Text(title, style = style, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * The serif headline, its weight carried from regular (as it arrives) to
 * semibold (once it has landed), in twelve steps. The bar's height is fixed,
 * so the size stops growing at the largest accessibility scale it can hold.
 */
@Composable
private fun compactFont(t: Float): TextStyle {
    val steps = 12f
    val q = (t * steps).roundToInt() / steps
    val weight = FontWeight((400 + (600 - 400) * q).roundToInt())
    val fontScale = LocalDensity.current.fontScale
    val size = 17f * minOf(fontScale, 1.4f) / fontScale
    return TextStyle(fontFamily = FontFamily.Serif, fontWeight = weight, fontSize = size.sp, lineHeight = (size * 1.3f).sp)
}
