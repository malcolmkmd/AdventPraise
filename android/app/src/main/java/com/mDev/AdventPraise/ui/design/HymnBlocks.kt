package com.mDev.AdventPraise.ui.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.LocalWorshipMode
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/** During playback or worship one block is current and the others dimmed (DSBlockState). */
enum class BlockState { Normal, Current, Dimmed }

@Composable
private fun blockAlpha(state: BlockState): Float {
    val worship = LocalWorshipMode.current
    val target = if (state == BlockState.Dimmed) (if (worship) 0.38f else DS.Fill.dimmed) else 1f
    val alpha by animateFloatAsState(target, DS.Motion.adaptive(DS.Motion.verse(), rememberReduceMotion()), label = "block-dim")
    return alpha
}

/**
 * A numbered verse (ChapterVerseBlock). The numeral is brass serif in a circle
 * that grows with the lyric size; the current verse has a 14 % brass wash.
 * No glass: lyrics are content.
 */
@Composable
fun ChapterVerseBlock(
    number: Int,
    lines: List<String>,
    modifier: Modifier = Modifier,
    style: ReadingStyle = ReadingStyle(),
    state: BlockState = BlockState.Normal,
    /** While accompaniment plays: the line being sung, picked out in brass. */
    currentLine: Int? = null,
) {
    val badge = style.verseBadge(LocalDensity.current.fontScale)
    val lit = if (state == BlockState.Current) currentLine else null
    val text = lines.joinToString("\n")
    val semantics = Modifier.semantics(mergeDescendants = true) {
        if (state == BlockState.Current) stateDescription = "Now singing"
    }
    if (style.centered) {
        Column(
            modifier.fillMaxWidth().alpha(blockAlpha(state)).then(semantics),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            VerseBadge(number, isCurrent = state == BlockState.Current, size = badge)
            LyricText(text, style, highlightedLine = lit)
        }
    } else {
        Row(
            modifier.fillMaxWidth().alpha(blockAlpha(state)).then(semantics),
            horizontalArrangement = Arrangement.spacedBy(DS.Space.panel),
        ) {
            VerseBadge(number, isCurrent = state == BlockState.Current, size = badge, modifier = Modifier.padding(top = DS.Space.hair))
            LyricText(text, style, Modifier.weight(1f), highlightedLine = lit)
        }
    }
}

/** The verse numeral: brass serif in a circle, washed when current. */
@Composable
fun VerseBadge(number: Int, modifier: Modifier = Modifier, isCurrent: Boolean = false, size: Dp = DS.Size.verseBadge) {
    val p = LocalSurface.current
    val fontScale = LocalDensity.current.fontScale
    Box(
        modifier
            .size(size)
            .background(p.brass.copy(alpha = if (isCurrent) DS.Fill.tintOn else 0f), CircleShape)
            .clearAndSetSemantics { contentDescription = "Verse $number" },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            number.toString(),
            style = TextStyle(
                fontFamily = FontFamily.Serif,
                fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Medium,
                // The badge's size already includes the font scale.
                fontSize = (size.value * 0.58f / fontScale).sp,
                fontFeatureSettings = "tnum",
                textAlign = TextAlign.Center,
            ),
            color = if (isCurrent) p.brass else p.secondary,
        )
    }
}

/**
 * The refrain (ChorusBlock): bold italic in the contrasting family, a brass
 * eyebrow label (the hymnal's own word for "Chorus", never hard-coded) and a
 * thin brass rule down its leading edge, lined up with the verse text.
 * Centred, the rule becomes a short dash above the label.
 */
@Composable
fun ChorusBlock(
    lines: List<String>,
    modifier: Modifier = Modifier,
    label: String = "Chorus",
    style: ReadingStyle = ReadingStyle(),
    state: BlockState = BlockState.Normal,
    /** Second and later repeats can collapse to the first line + "…". */
    isCollapsedRepeat: Boolean = false,
    currentLine: Int? = null,
) {
    val p = LocalSurface.current
    val displayed = if (isCollapsedRepeat && lines.isNotEmpty()) lines.first() + " …" else lines.joinToString("\n")
    val lit = if (state == BlockState.Current && !isCollapsedRepeat) currentLine else null
    val isCurrent = state == BlockState.Current
    val semantics = Modifier.clearAndSetSemantics {
        contentDescription = "Chorus. $displayed"
        if (isCurrent) stateDescription = "Now singing"
    }
    if (style.centered) {
        Column(
            modifier.fillMaxWidth().alpha(blockAlpha(state)).then(semantics),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            ChorusRule(p.brass, Modifier.padding(bottom = DS.Space.xxs).size(24.dp, 2.dp))
            ChorusLabel(label, isCurrent)
            LyricText(displayed, style, chorus = true, highlightedLine = lit)
        }
    } else {
        val badge = style.verseBadge(LocalDensity.current.fontScale)
        Row(
            modifier
                .fillMaxWidth()
                .alpha(blockAlpha(state))
                .then(semantics)
                // Line the rule up with the verse text, past the verse numerals.
                .padding(start = badge + DS.Space.panel)
                .height(IntrinsicSize.Min),
        ) {
            ChorusRule(p.brass, Modifier.width(2.dp).fillMaxHeight())
            Spacer(Modifier.width(DS.Space.panel))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                ChorusLabel(label, isCurrent)
                LyricText(displayed, style, chorus = true, highlightedLine = lit)
            }
        }
    }
}

/** The chorus's accent: a thin brass rule, quiet enough to do without a box. */
@Composable
fun ChorusRule(color: Color, modifier: Modifier = Modifier) {
    Box(modifier.background(color.copy(alpha = 0.7f), RoundedCornerShape(50)))
}

@Composable
private fun ChorusLabel(text: String, isCurrent: Boolean) {
    val p = LocalSurface.current
    Eyebrow(
        text,
        p.brass,
        Modifier
            .background(p.brass.copy(alpha = if (isCurrent) DS.Fill.tintOn else 0f), RoundedCornerShape(50))
            .padding(horizontal = if (isCurrent) 10.dp else 0.dp, vertical = if (isCurrent) DS.Space.xxs else 0.dp)
            .semantics { heading() },
        tracking = 1.5f,
    )
}
