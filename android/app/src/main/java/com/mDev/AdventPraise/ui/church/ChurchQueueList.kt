package com.mDev.AdventPraise.ui.church

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.data.RunningQueue
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * The running playlist or service plan, above church mode's number pad
 * (ChurchQueueList). The hymn Next goes to is highlighted and scrolled into
 * view; the open one is marked Now. Tap any hymn to jump there and follow
 * the list on from it. Hymns this hymnal lacks are muted and can't be chosen.
 */
@Composable
fun ChurchQueueList(queue: RunningQueue, title: (Int) -> String?, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val progress = queue.current?.let { "${it + 1} of ${queue.numbers.size}" } ?: "${queue.numbers.size}"
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Row(
            Modifier
                .padding(horizontal = DS.Space.xxs)
                .semantics(mergeDescendants = true) { heading() },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            Icon(Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.secondary, modifier = Modifier.size(13.dp))
            Eyebrow(queue.name, p.secondary, Modifier.weight(1f), tracking = 0.9f)
            Eyebrow(progress, p.secondary, tracking = 0.9f)
        }
        val list = rememberLazyListState()
        // The next hymn, or the open one at the end of the list, in the middle.
        LaunchedEffect(Unit) {
            val target = queue.next ?: queue.current ?: return@LaunchedEffect
            list.scrollToItem((target - 1).coerceAtLeast(0))
        }
        LazyColumn(
            Modifier.heightIn(max = 208.dp),
            state = list,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xxs),
        ) {
            itemsIndexed(queue.numbers) { index, number -> QueueRow(index, number, title(number), queue, onSelect) }
        }
    }
}

@Composable
private fun QueueRow(index: Int, number: Int, name: String?, queue: RunningQueue, onSelect: (Int) -> Unit) {
    val p = LocalSurface.current
    val isNext = index == queue.next
    val isCurrent = index == queue.current
    val shape = dsShape(DS.Radius.tile)
    val interaction = remember { MutableInteractionSource() }
    val fill = when {
        isNext -> p.tint
        isCurrent -> p.tint.copy(alpha = DS.Fill.tintSelected)
        else -> p.primary(DS.Fill.inset)
    }
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .dsPress(interaction, name != null)
            .background(fill, shape)
            .clickable(interaction, null, enabled = name != null) { onSelect(index) }
            .clearAndSetSemantics {
                contentDescription = "Hymn $number, ${name ?: "not in this hymnal"}"
                role = Role.Button
                stateDescription = when { isNext -> "Next"; isCurrent -> "Now showing"; else -> "" }
                selected = isCurrent
                if (name == null) disabled() else onClick("Shows this hymn and follows the list from here.") { onSelect(index); true }
            }
            .padding(horizontal = DS.Space.s),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Text(
            number.toString(),
            style = DS.Type.label.copy(fontFeatureSettings = "tnum", textAlign = TextAlign.End),
            color = if (isNext) p.onTint else p.brass,
            modifier = Modifier.widthIn(min = 40.dp),
        )
        Text(
            name ?: "Not in this hymnal",
            style = DS.Type.label,
            color = when { isNext -> p.onTint; name == null -> p.secondary; else -> p.highContrastForeground },
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (isNext || isCurrent) {
            Eyebrow(if (isNext) "Next" else "Now", if (isNext) p.onTint else p.tint, tracking = 0.9f)
        }
    }
}
