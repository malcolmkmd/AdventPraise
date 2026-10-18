package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfacePalette
import java.text.Normalizer

/** HymnRow's two backgrounds. */
enum class HymnRowStyle {
    /** Inside glass (Lectern panels, sheets): a 5 % fill, no glass. */
    Inset,
    /** Inside a plain list; the list owns the background. */
    Plain,
}

/**
 * One hymn in a list (HymnRow): number in brass serif on a brass tile, title in
 * serif, an optional lyric snippet with the search match highlighted. At the
 * largest font scales the tile stacks above the text instead of squeezing it.
 */
@Composable
fun HymnRow(
    hymn: DSHymnSummary,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    snippet: String? = null,
    /** Words to highlight in the snippet (the search query). */
    highlight: String? = null,
    isFavourite: Boolean = false,
    isCurrent: Boolean = false,
    style: HymnRowStyle = HymnRowStyle.Inset,
    showsChevron: Boolean = true,
) {
    val p = LocalSurface.current
    val large = LocalDensity.current.fontScale >= 1.8f
    val shape = dsShape(DS.Radius.tile)
    val line = snippet ?: hymn.firstLine
    val description = buildList {
        add("${hymn.number}"); add(hymn.title)
        if (isFavourite) add("favourite")
        if (isCurrent) add("now open")
        line?.let(::add)
    }.joinToString(", ")
    val surface = when (style) {
        HymnRowStyle.Inset -> Modifier
            .background(if (isCurrent) p.tint.copy(alpha = DS.Fill.tintActive) else p.primary(DS.Fill.row), shape)
            .border(1.dp, if (isCurrent) p.tint.copy(alpha = 0.35f) else Color.Transparent, shape)
        HymnRowStyle.Plain -> Modifier
    }
    val rowModifier = modifier
        .fillMaxWidth()
        .heightIn(min = DS.Size.row)
        .clip(shape)
        .then(surface)
        .clickable(onClick = onClick)
        .padding(horizontal = DS.Space.m, vertical = DS.Space.s)
        .clearAndSetSemantics { contentDescription = description; role = Role.Button; selected = isCurrent }

    val tile = @Composable { NumberTile(hymn.number, tint = if (isCurrent) p.tint else p.brass) }
    val text = @Composable { m: Modifier ->
        Column(m, verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                Text(hymn.title, style = DS.Type.rowTitle, color = p.foreground, maxLines = if (large) 3 else 1,
                    overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (isFavourite) Icon(Icons.Rounded.Star, null, tint = p.brass, modifier = Modifier.size(13.dp))
            }
            if (line != null) {
                Text(highlighted(line, highlight, p), style = DS.Type.caption, color = p.secondary,
                    maxLines = if (large) 3 else 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
    if (large) {
        Column(rowModifier, verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            tile(); text(Modifier.fillMaxWidth())
        }
    } else {
        Row(rowModifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            tile()
            text(Modifier.weight(1f))
            if (showsChevron) {
                Icon(
                    if (isCurrent) Icons.Rounded.Check else Icons.AutoMirrored.Rounded.KeyboardArrowRight, null,
                    tint = if (isCurrent) p.tint else p.secondary, modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

/** A hymn number in brass (or the tint) on a soft tile of the same colour. */
@Composable
fun NumberTile(number: Int, modifier: Modifier = Modifier, tint: Color = LocalSurface.current.brass) {
    Box(
        modifier
            .defaultMinSize(DS.Size.numberTile, DS.Size.numberTile)
            .clip(dsShape(DS.Radius.badge))
            .background(tint.copy(alpha = DS.Fill.tintSelected))
            .padding(horizontal = DS.Space.xxs),
        contentAlignment = Alignment.Center,
    ) {
        Text(number.toString(), style = DS.Type.numeral.copy(fontFeatureSettings = "tnum"), color = tint, maxLines = 1)
    }
}

/** The snippet with the first case- and accent-insensitive match of [query] picked out. */
internal fun highlighted(text: String, query: String?, p: SurfacePalette): AnnotatedString {
    if (query.isNullOrBlank()) return AnnotatedString(text)
    val fold = { s: String -> Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase() }
    // Folding can only drop combining marks, so map folded offsets back through the kept characters.
    val kept = ArrayList<Int>()
    val folded = StringBuilder()
    text.forEachIndexed { i, c ->
        val f = fold(c.toString())
        repeat(f.length) { kept += i }
        folded.append(f)
    }
    val start = folded.indexOf(fold(query.trim()))
    if (start < 0) return AnnotatedString(text)
    val end = start + fold(query.trim()).length
    val from = kept[start]
    val to = if (end - 1 < kept.size) kept[end - 1] + 1 else text.length
    return buildAnnotatedString {
        append(text)
        addStyle(SpanStyle(background = p.brass.copy(alpha = DS.Fill.highlight), color = p.foreground, fontWeight = FontWeight.Bold), from, to)
    }
}
