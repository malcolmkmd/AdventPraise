package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * iOS's segmented picker (`.pickerStyle(.segmented)`, iOS 26): a capsule track
 * in the surface's quiet fill with the chosen segment raised on it, the
 * chosen label semibold. The caller plays the selection haptic. [fill] stretches the segments across the width (the
 * library's Favourites | Playlists); otherwise each fits its label (Page | System).
 */
@Composable
fun <T> SegmentedPicker(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    fill: Boolean = false,
    textStyle: TextStyle = DS.Type.detail,
    segmentHeight: Dp = 28.dp,
    description: ((T) -> String)? = null,
) {
    val p = LocalSurface.current
    val track = RoundedCornerShape(50)
    Row(modifier.clip(track).background(p.primary(DS.Fill.stroke * 0.8f), track).padding(2.dp)) {
        for (option in options) {
            val on = option == selected
            Box(
                Modifier
                    .then(if (fill) Modifier.weight(1f) else Modifier.widthIn(min = 64.dp))
                    .then(if (on) Modifier.shadow(1.dp, track).background(p.elevated, track) else Modifier)
                    .clip(track)
                    .clickable(role = Role.Tab) { if (!on) onSelect(option) }
                    .semantics {
                        this.selected = on
                        description?.let { contentDescription = it(option) }
                    }
                    .height(segmentHeight)
                    .padding(horizontal = DS.Space.m),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label(option), color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    style = textStyle.copy(fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal),
                )
            }
        }
    }
}
