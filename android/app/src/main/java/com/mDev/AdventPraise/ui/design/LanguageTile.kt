package com.mDev.AdventPraise.ui.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Book
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/** Gap between a tile and its current ring, and the ring's width. */
private val RingGap = 3.dp
private val RingWidth = 2.dp
/** How far tiles reach into their container's padding (their ring padding), so they line up. */
val LanguageTileRingInset = RingGap + RingWidth

/**
 * A hymnal as a full-colour tile (LanguageTile): the whole tile is the hymnal's
 * colour, with the language and the book's title in `languageInk`. The current
 * hymnal has a check badge and a ring in the surface's ink, just outside the
 * tile. States: current · owned · purchasing (spinner) · locked (lock + price).
 * A hymnal of its own (the SDA Hymnal) has a book mark and an "Own numbering" tag.
 */
@Composable
fun LanguageTile(
    hymnal: DSHymnal,
    access: DSHymnalAccess,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    /** Under the language; null = the hymnal's title. */
    detail: String? = null,
    /** Spoken hint for an owned hymnal; null = "Switches to this hymnal". */
    switchHint: String? = null,
) {
    val p = LocalSurface.current
    val isCurrent = access == DSHymnalAccess.Current
    val ring by animateFloatAsState(if (isCurrent) 1f else 0f, DS.Motion.select(), label = "tile-ring")
    val interaction = remember { MutableInteractionSource() }
    val fill = hymnal.color.fill(p)
    val ink = p.languageInk
    val tileShape = dsShape(DS.Radius.tile)
    val label = if (hymnal.isOwnBook && detail != null) "${hymnal.language}, ${hymnal.name}, $detail" else "${hymnal.language}, ${detail ?: hymnal.name}"
    val state = when (access) {
        DSHymnalAccess.Current -> "Showing now"
        DSHymnalAccess.Owned -> switchHint ?: "Switches to this hymnal"
        DSHymnalAccess.Purchasing -> "Purchasing"
        is DSHymnalAccess.Locked -> access.price?.let { "Locked, $it" } ?: "Locked"
    }
    Box(
        modifier
            .dsPress(interaction, access != DSHymnalAccess.Purchasing)
            .border(RingWidth, p.foreground.copy(alpha = ring), dsShape(DS.Radius.tile + RingGap + RingWidth))
            .padding(RingGap + RingWidth)
            .clearAndSetSemantics {
                contentDescription = label
                stateDescription = state
                role = Role.Button
                selected = isCurrent
            },
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .heightIn(min = DS.Size.languageTile)
                .clip(tileShape)
                .background(fill)
                // A faint inner edge keeps neighbouring tiles apart on dark grounds.
                .border(1.dp, ink.copy(alpha = DS.Fill.stroke), tileShape)
                .clickable(interaction, null, enabled = access != DSHymnalAccess.Purchasing, onClick = onClick)
                .padding(horizontal = DS.Space.m, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(DS.Space.hair),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                if (hymnal.isOwnBook) Icon(Icons.Rounded.Book, null, tint = ink, modifier = Modifier.size(14.dp))
                Text(hymnal.language, style = DS.Type.rowTitle, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = true))
                Badge(access, hymnal)
            }
            Text(detail ?: hymnal.name, style = DS.Type.caption, color = ink, maxLines = 3)
            if (hymnal.isOwnBook) {
                Text(
                    "Own numbering",
                    style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = ink,
                    modifier = Modifier
                        .padding(top = DS.Space.xxs)
                        .border(1.dp, ink, RoundedCornerShape(50))
                        .padding(horizontal = DS.Space.xs, vertical = DS.Space.hair),
                )
            }
        }
    }
}

@Composable
private fun Badge(access: DSHymnalAccess, hymnal: DSHymnal) {
    val p = LocalSurface.current
    val ink = p.languageInk
    when (access) {
        DSHymnalAccess.Current -> Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) {
            // The palette check: the hymnal's colour on an ink disc.
            Box(Modifier.size(16.dp).background(hymnal.color.fill(p), RoundedCornerShape(50)))
            Icon(Icons.Rounded.CheckCircle, null, tint = ink, modifier = Modifier.size(20.dp))
        }
        DSHymnalAccess.Owned -> Unit
        DSHymnalAccess.Purchasing -> CircularProgressIndicator(Modifier.size(16.dp), color = ink, strokeWidth = 2.dp)
        is DSHymnalAccess.Locked -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Icon(Icons.Rounded.Lock, null, tint = ink, modifier = Modifier.size(12.dp))
            Text(access.price ?: "—", style = DS.Type.caption.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum"), color = ink)
        }
    }
}

/** Widens a child into its parent's padding by [by] on both sides (a negative horizontal padding). */
fun Modifier.horizontalOutset(by: androidx.compose.ui.unit.Dp): Modifier = layout { measurable, constraints ->
    val extra = (by * 2).roundToPx()
    val widened = if (constraints.hasBoundedWidth) constraints.copy(minWidth = constraints.minWidth + extra, maxWidth = constraints.maxWidth + extra) else constraints
    val placeable = measurable.measure(widened)
    layout(placeable.width - extra, placeable.height) { placeable.place(-extra / 2, 0) }
}

/**
 * Tiles two to a row, each row as tall as its tallest tile; one column at the
 * largest font scales. Hymnals of their own follow the translations, one across
 * each row (LanguageTileGrid).
 */
@Composable
fun LanguageTileGrid(
    hymnals: List<DSHymnal>,
    modifier: Modifier = Modifier,
    tile: @Composable (DSHymnal, Modifier) -> Unit,
) {
    val columns = if (LocalDensity.current.fontScale >= 1.8f) 1 else 2
    val translations = hymnals.filter { !it.isOwnBook }
    val ownBooks = hymnals.filter { it.isOwnBook }
    Column(modifier) {
        translations.chunked(columns).forEach { row ->
            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
                row.forEach { tile(it, Modifier.weight(1f).fillMaxHeight()) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        ownBooks.forEach { tile(it, Modifier.fillMaxWidth()) }
    }
}

/** The current language as a small filled capsule (LanguageChip). */
@Composable
fun LanguageChip(hymnal: DSHymnal, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    Text(
        hymnal.language,
        style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold),
        color = p.languageInk,
        maxLines = 1,
        modifier = modifier
            .background(hymnal.color.fill(p), RoundedCornerShape(50))
            .padding(horizontal = DS.Space.s, vertical = DS.Space.xxs),
    )
}

/**
 * Choose the hymnal (LanguagePicker): the full list as LanguageTiles, so
 * purchase state is inline. Embedded in the reader menu or a sheet, or
 * [isStandalone] with its own glass.
 */
@Composable
fun LanguagePicker(
    hymnals: List<DSHymnal>,
    access: (DSHymnal) -> DSHymnalAccess,
    onSelect: (DSHymnal) -> Unit,
    modifier: Modifier = Modifier,
    unlockAllPrice: String? = null,
    isUnlockingAll: Boolean = false,
    ownsEverything: Boolean = true,
    isStandalone: Boolean = false,
    onUnlockAll: () -> Unit = {},
    /** null hides Restore purchases (the hymnals are free). */
    onRestore: (() -> Unit)? = null,
) {
    val p = LocalSurface.current
    val list = @Composable {
        Column(Modifier.padding(DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text("Hymnals", style = DS.Type.panelTitle, color = p.foreground, modifier = Modifier.weight(1f))
                Eyebrow("${hymnals.size} languages", p.secondary, tracking = 0.9f)
            }
            // Into the panel's padding by the tiles' ring padding, so the tiles line up with the title.
            LanguageTileGrid(hymnals, Modifier.horizontalOutset(LanguageTileRingInset)) { hymnal, m ->
                LanguageTile(hymnal, access(hymnal), onClick = { onSelect(hymnal) }, modifier = m)
            }
            if (!ownsEverything) {
                PaywallUnlockAllButton(count = hymnals.size - 1, price = unlockAllPrice, isPurchasing = isUnlockingAll, onClick = onUnlockAll)
            }
            if (onRestore != null) {
                Box(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).clickable(onClick = onRestore), contentAlignment = Alignment.Center) {
                    Text("Restore purchases", style = DS.Type.button, color = p.tint)
                }
            }
        }
    }
    if (isStandalone) {
        Box(modifier.dsGlass(dsShape(DS.Radius.panel), DS.GlassDepth.Sheet)) { OnGlass(list) }
    } else {
        Box(modifier.alpha(1f)) { list() }
    }
}

/** The "Unlock all N hymnals" call to action that closes the picker's list (PaywallUnlockAllButton). */
@Composable
fun PaywallUnlockAllButton(
    count: Int,
    price: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isPurchasing: Boolean = false,
) {
    GlassButton(
        title = if (price != null) "Unlock all $count hymnals · $price" else "Unlock all $count hymnals",
        onClick = onClick,
        modifier = modifier,
        icon = Icons.Rounded.LockOpen,
        isLoading = isPurchasing,
        fullWidth = true,
        enabled = !isPurchasing && price != null,
    )
}
