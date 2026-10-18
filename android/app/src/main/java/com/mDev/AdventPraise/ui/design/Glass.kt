package com.mDev.AdventPraise.ui.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalOnGlass
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/**
 * Vesper glass (`dsGlass`): the one way to make a floating layer. Android has no
 * live blur of what lies beneath, so iOS's Liquid Glass becomes a translucent
 * raised fill in the surface's colours, an optional tint wash, a hairline and a
 * warm shadow (the iOS 17–25 fallback, which is the same idea).
 * Content inside reads [LocalOnGlass] and adds no glass of its own.
 */
@Composable
fun Modifier.dsGlass(
    shape: Shape,
    depth: DS.GlassDepth = DS.GlassDepth.Capsule,
    tint: Color? = null,
): Modifier {
    val p = LocalSurface.current
    val fill = p.elevated.copy(alpha = depth.fillAlpha)
    val wash = tint?.copy(alpha = tint.alpha * 0.22f)?.compositeOver(fill) ?: fill
    val stroke = if (p.isDark) Color.White.copy(alpha = DS.Fill.stroke) else Color.Black.copy(alpha = DS.Fill.hairline)
    val shadow = if (p.isDark) Color.Black.copy(alpha = 0.45f) else Color(0xFF1C1F1F).copy(alpha = 0.12f)
    return this
        .shadow(depth.shadowElevation.dp, shape, clip = false, ambientColor = shadow, spotColor = shadow)
        .clip(shape)
        .background(wash, shape)
        .border(1.dp, stroke, shape)
}

/** Provides [LocalOnGlass] to content drawn inside a glass layer. */
@Composable
fun OnGlass(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalOnGlass provides true, content = content)
}

/**
 * Subtle press feedback for keys and tiles (DSPressStyle): a slight dip and dim,
 * no bounce. With animations off, only the dim.
 */
@Composable
fun Modifier.dsPress(interactionSource: InteractionSource, enabled: Boolean = true): Modifier {
    val pressed by interactionSource.collectIsPressedAsState()
    val reduce = rememberReduceMotion()
    val down = pressed && enabled
    val scale by animateFloatAsState(if (down && !reduce) 0.97f else 1f, DS.Motion.press(), label = "press-scale")
    val alpha by animateFloatAsState(if (down) 0.75f else 1f, DS.Motion.press(), label = "press-alpha")
    return graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = alpha }
}

/** `RoundedRectangle.ds(radius)`: the one corner style. */
fun dsShape(radius: Dp) = RoundedCornerShape(radius)

/**
 * A floating rounded panel for the control layer only (a transient HUD over the
 * reading surface). Never wrap content in it: lyrics, rows and tiles stay opaque.
 * Don't nest one inside another glass layer; use [InsetGroup] there.
 */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    radius: Dp = DS.Radius.card,
    padding: Dp = DS.Space.panel,
    depth: DS.GlassDepth = DS.GlassDepth.Card,
    tint: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .dsGlass(dsShape(radius), depth, tint)
            .padding(padding),
    ) {
        OnGlass { Column(content = content) }
    }
}

/**
 * The non-glass grouping used inside glass (Lectern panels, sheets, More): a 5 %
 * foreground fill with an optional eyebrow title (DSInsetGroup).
 */
@Composable
fun InsetGroup(
    modifier: Modifier = Modifier,
    title: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val p = LocalSurface.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        if (title != null) {
            Eyebrow(title, p.secondary, Modifier.padding(horizontal = DS.Space.xxs).semantics { heading() })
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(dsShape(DS.Radius.tile))
                .background(p.primary(DS.Fill.row)),
            content = content,
        )
    }
}
