package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalOnGlass
import com.mDev.AdventPraise.ui.theme.LocalSurface

/** The three kinds of button (GlassButton.Kind). */
enum class GlassButtonKind {
    /** The single most important action on a surface (Go, Unlock, Get started). */
    Primary,
    /** Everything else that floats (Continue, Restore, Exit). */
    Secondary,
    /** A 44 dp circular glyph button (close, +, share). */
    Icon,
}

/**
 * Three kinds of button, one API (GlassButton.swift). Primary is a solid tint
 * key with the onTint label; secondary a tint wash over a raised fill; icon a
 * 44 dp circle. Inside another glass layer ([LocalOnGlass]) the raised fill is
 * a plain inset fill: never glass on glass.
 *
 * @param tint defaults to the surface tint (Evergreen); pass the surface brass for purchases.
 */
@Composable
fun GlassButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    kind: GlassButtonKind = GlassButtonKind.Primary,
    tint: Color? = null,
    isLoading: Boolean = false,
    fullWidth: Boolean = false,
    enabled: Boolean = true,
) {
    val p = LocalSurface.current
    val onGlass = LocalOnGlass.current
    val resolved = tint ?: p.tint
    val interaction = remember { MutableInteractionSource() }
    val raisedFill = if (onGlass) p.primary(DS.Fill.inset) else p.elevated.copy(alpha = DS.GlassDepth.Capsule.fillAlpha)
    val labelColor = when (kind) {
        GlassButtonKind.Primary -> if (enabled) p.onTint else p.secondary
        GlassButtonKind.Secondary -> resolved
        GlassButtonKind.Icon -> p.foreground
    }
    val alpha = if (enabled) 1f else DS.Fill.disabled + 0.1f

    val base = modifier
        .semantics { contentDescription = title }
        .dsPress(interaction, enabled)

    when (kind) {
        GlassButtonKind.Icon -> Box(
            base
                .size(DS.Size.hitTarget)
                .clip(CircleShape)
                .background(raisedFill, CircleShape)
                .border(1.dp, if (onGlass) Color.Transparent else p.primary(DS.Fill.hairline), CircleShape)
                .clickable(interaction, indication = null, enabled = enabled && !isLoading, role = Role.Button, onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            if (isLoading) {
                CircularProgressIndicator(Modifier.size(18.dp), color = resolved, strokeWidth = 2.dp)
            } else if (icon != null) {
                Icon(icon, contentDescription = null, tint = labelColor.copy(alpha = labelColor.alpha * alpha), modifier = Modifier.size(22.dp))
            }
        }
        else -> {
            val shape = dsShape(DS.Radius.key)
            val primary = kind == GlassButtonKind.Primary
            val fillModifier = if (primary) {
                val fill = if (enabled) resolved else p.primary(DS.Fill.stroke)
                Modifier
                    .shadow(if (enabled) 6.dp else 0.dp, shape, clip = false, ambientColor = resolved.copy(alpha = 0.3f), spotColor = resolved.copy(alpha = 0.3f))
                    .background(fill, shape)
            } else {
                Modifier.background(raisedFill, shape).background(resolved.copy(alpha = DS.Fill.tintSelected), shape)
            }
            Row(
                base
                    .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
                    .heightIn(min = 50.dp)
                    .then(fillModifier)
                    .clip(shape)
                    .clickable(interaction, indication = null, enabled = enabled && !isLoading, role = Role.Button, onClick = onClick)
                    .padding(horizontal = DS.Space.l, vertical = DS.Space.s),
                horizontalArrangement = Arrangement.spacedBy(DS.Space.xs, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val color = labelColor.copy(alpha = labelColor.alpha * alpha)
                if (isLoading) {
                    CircularProgressIndicator(Modifier.size(20.dp), color = if (primary) p.onTint else resolved, strokeWidth = 2.dp)
                } else {
                    if (icon != null) Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                    Text(title, style = DS.Type.button, color = color, maxLines = 2, textAlign = TextAlign.Center)
                }
            }
        }
    }
}
