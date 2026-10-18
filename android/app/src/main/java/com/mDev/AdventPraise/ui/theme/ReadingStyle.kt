package com.mDev.AdventPraise.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.settings.LineSpacing
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSettings
import kotlin.math.abs

/**
 * Everything the reader's text needs (DSReadingStyle). A value type so the
 * components stay previewable; ReadingSettings vends one ([readingStyle]).
 */
@Immutable
data class ReadingStyle(
    val scale: DS.LyricScale = DS.LyricScale.Standard,
    val step: Int = 2,
    val font: ReadingFont = ReadingFont.Serif,
    val lineSpacing: LineSpacing = LineSpacing.Normal,
    val centered: Boolean = false,
    /** A size between the steps, set by pinch-to-zoom; null means "use [step]". */
    val pinchedPointSize: Float? = null,
) {
    val basePointSize: Float
        get() {
            pinchedPointSize?.let { return it.coerceIn(scale.pinchRange) }
            val steps = scale.steps
            return steps[step.coerceIn(0, steps.size - 1)]
        }

    val isDefaultSize: Boolean get() = pinchedPointSize == null && step == scale.defaultStep
    val textAlign: TextAlign get() = if (centered) TextAlign.Center else TextAlign.Start

    /** A new scale or step drops any pinched size, as on iOS. */
    fun withScale(value: DS.LyricScale) = copy(scale = value, step = step.coerceAtMost(value.steps.size - 1), pinchedPointSize = null)
    fun withStep(value: Int) = copy(step = value.coerceIn(0, scale.steps.size - 1), pinchedPointSize = null)

    /** Keeps a pinched size; the slider shows the nearest step. */
    fun pinched(to: Float): ReadingStyle {
        val size = to.coerceIn(scale.pinchRange)
        val nearest = scale.steps.indices.minByOrNull { abs(scale.steps[it] - size) } ?: scale.defaultStep
        return copy(step = nearest, pinchedPointSize = size)
    }

    fun resetSize() = withStep(scale.defaultStep)

    /** The lyric size in sp: the base size times the font scale, capped per scale. */
    @Composable
    fun lyricSize(sizeRatio: Float = 1f): TextUnit {
        val fontScale = LocalDensity.current.fontScale
        // sp is multiplied by the font scale again on the way out: divide it back in.
        return (lyricPoints(fontScale) * sizeRatio / fontScale).sp
    }

    /** Points on screen at [fontScale]: the base size grown by the system font scale, capped. */
    fun lyricPoints(fontScale: Float): Float = basePointSize * fontScale.coerceAtMost(scale.fontScaleCap)

    /** Extra leading between lines, in points on screen. */
    fun leading(fontScale: Float): Float = lyricPoints(fontScale) * lineSpacing.leading * scale.leadingScale

    /** The verse badge grows with the lyric size: 26 dp at 19 pt text. */
    fun verseBadge(fontScale: Float): Dp = maxOf(DS.Size.verseBadge.value, lyricPoints(fontScale) * 1.35f).dp

    companion object {
        /** Church mode's style: worship scale, compact, centred. */
        val Worship = ReadingStyle(scale = DS.LyricScale.Worship, step = 2, font = ReadingFont.Serif, lineSpacing = LineSpacing.Compact, centered = true)
    }
}

/** The person's reading choices as a style for the design components. */
val ReadingSettings.readingStyle: ReadingStyle
    get() = ReadingStyle(
        scale = if (largePrint) DS.LyricScale.LargePrint else DS.LyricScale.Standard,
        step = step,
        font = font,
        lineSpacing = lineSpacing,
        centered = centered,
    )
