package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import kotlin.math.ceil

/**
 * Centred text that wraps into lines of even length, like CSS `text-wrap:
 * balance` (BalancedWrap). A wrapped title or lyric line takes the narrowest
 * width that still needs no more lines than the full width does, so a lyric
 * never leaves one word alone on a line. Text that fits on one line is left alone.
 */
@Composable
fun BalancedText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    isOn: Boolean = true,
) {
    val centred = style.copy(textAlign = TextAlign.Center)
    if (!isOn) {
        Text(text, modifier, color = color, style = centred)
        return
    }
    val measurer = rememberTextMeasurer()
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        val max = constraints.maxWidth
        val width = remember(text, centred, max) { balancedWidth(measurer, text, centred, max) }
        Text(text, Modifier.width(with(LocalDensity.current) { width.toDp() }), color = color, style = centred)
    }
}

/** The narrowest width (to a pixel) that keeps the line count the full width gives. */
internal fun balancedWidth(measurer: TextMeasurer, text: String, style: TextStyle, maxWidth: Int): Int {
    if (maxWidth == Constraints.Infinity || maxWidth <= 0) return maxWidth
    val natural = measurer.measure(text, style, softWrap = false).size.width
    if (natural <= maxWidth) return natural
    fun lines(width: Int) = measurer.measure(text, style, constraints = Constraints(maxWidth = width)).lineCount
    val target = lines(maxWidth)
    // Balanced lines are never under half the width for two lines, less for more.
    var low = maxWidth * 0.35f
    var high = maxWidth.toFloat()
    while (high - low > 1f) {
        val mid = (low + high) / 2
        if (lines(mid.toInt()) > target) low = mid else high = mid
    }
    return ceil(high).toInt().coerceAtMost(maxWidth)
}

/**
 * Lyric text at the person's step × font scale, capped per scale (DSLyricText).
 *
 * @param chorus set in the chorus's contrasting face (bold italic, other family).
 * @param highlightedLine a line (index into [text]'s "\n"-separated lines) drawn in
 *   brass, for following the accompaniment. Colour only, so nothing re-wraps.
 */
@Composable
fun LyricText(
    text: String,
    style: ReadingStyle,
    modifier: Modifier = Modifier,
    chorus: Boolean = false,
    italic: Boolean = false,
    weight: FontWeight = FontWeight.Normal,
    highlightedLine: Int? = null,
) {
    val p = LocalSurface.current
    val fontScale = LocalDensity.current.fontScale
    val ratio = if (chorus) DS.Chorus.sizeRatio(style.font) else 1f
    val points = style.lyricPoints(fontScale) * ratio
    val leading = style.leading(fontScale)
    val family: FontFamily = if (chorus) DS.Chorus.family(style.font) else DS.lyricFamily(style.font)
    val textStyle = TextStyle(
        fontFamily = family,
        fontWeight = if (chorus) DS.Chorus.weight else weight,
        fontStyle = if (chorus || italic) FontStyle.Italic else FontStyle.Normal,
        // Points on screen already include the font scale: divide it back out of sp.
        fontSize = (points / fontScale).sp,
        lineHeight = ((points * 1.2f + leading) / fontScale).sp,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
        textAlign = style.textAlign,
        color = LocalContentColor.current,
    )
    val lines = text.split("\n")
    if (style.centered) {
        // Centred: each hymn line wraps on its own into balanced halves.
        Column(
            modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = text },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(with(LocalDensity.current) { (leading / fontScale).sp.toDp() }),
        ) {
            lines.forEachIndexed { index, line ->
                BalancedText(
                    line.ifEmpty { " " },
                    textStyle,
                    color = if (index == highlightedLine) p.brass else Color.Unspecified,
                )
            }
        }
    } else {
        val annotated = buildAnnotatedString {
            lines.forEachIndexed { index, line ->
                if (index > 0) append("\n")
                if (index == highlightedLine) withStyle(SpanStyle(color = p.brass)) { append(line) } else append(line)
            }
        }
        Box(modifier.fillMaxWidth()) {
            Text(annotated, Modifier.fillMaxWidth(), style = textStyle)
        }
    }
}
