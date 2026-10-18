package com.mDev.AdventPraise.ui.design

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/** The small-caps label iOS calls an eyebrow: 11 sp bold, uppercase, tracked. */
@Composable
fun Eyebrow(text: String, color: Color, modifier: Modifier = Modifier, tracking: Float = 1.3f) {
    Text(text.uppercase(), style = DS.Type.eyebrow(tracking), color = color, modifier = modifier)
}

/**
 * One hymn in a list: number tile, serif title, an optional matching line. The first
 * milestone's row; new lists use [HymnRow], the iOS component.
 */
@Composable
fun HymnRowItem(
    hymn: Hymn,
    isCurrent: Boolean,
    isFavourite: Boolean,
    snippet: String? = null,
    onClick: () -> Unit,
) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.row)
            .clip(RoundedCornerShape(DS.Radius.tile))
            .background(if (isCurrent) p.tint.copy(alpha = DS.Fill.tintSelected) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Space.s, vertical = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        NumberTile(hymn.number)
        Column(Modifier.weight(1f)) {
            Text(hymn.title, style = DS.Type.rowTitle, color = p.foreground, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (snippet != null && snippet != hymn.title) {
                Text(snippet, style = DS.Type.detail, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (isFavourite) {
            Icon(Icons.Rounded.Star, contentDescription = "Favourite", tint = p.brass, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Eyebrow(text, LocalSurface.current.secondary, modifier.padding(start = DS.Space.s, top = DS.Space.l, bottom = DS.Space.xs))
}

@Composable
fun HSpace(width: Dp) = Spacer(Modifier.width(width))

/** A light tap, when the person has Haptics on in More. New code calls [Haptics.play] with an event. */
@Composable
fun rememberHaptic(enabled: Boolean): () -> Unit {
    val haptics = LocalHapticFeedback.current
    return { if (enabled) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
}

fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
