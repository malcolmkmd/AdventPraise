// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AppearanceChange
import com.mDev.AdventPraise.analytics.TextSizeContext
import com.mDev.AdventPraise.analytics.TextSizeMethod
import com.mDev.AdventPraise.settings.LyricScale
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import com.mDev.AdventPraise.ui.theme.readingStyle
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.debounce

/**
 * The reader's appearance analytics (ReadingSettings' reporting on iOS):
 * changes are reported a second after they settle, so dragging the size slider
 * or flicking through surfaces sends the final choice only. "Chorus after
 * every verse" is reported by More, where it is switched; church mode reports
 * its own size.
 */
object AppearanceReporting {
    /** How the next reader size change was made, when the change alone can't tell. Cleared once reported. */
    var nextSizeMethod: TextSizeMethod? = null

    private data class Snapshot(val style: ReadingStyle, val surface: ReadingSurface)

    @OptIn(FlowPreview::class)
    @Composable
    operator fun invoke(settings: ReadingSettings) {
        LaunchedEffect(settings) {
            var reported = Snapshot(settings.readingStyle, settings.surface)
            snapshotFlow { Snapshot(settings.readingStyle, settings.surface) }
                .debounce(1000)
                .collect { now ->
                    report(reported, now)
                    reported = now
                }
        }
    }

    private fun report(old: Snapshot, now: Snapshot) {
        if (old == now) return
        val style = now.style
        val changes = buildList {
            if (now.surface != old.surface) add(AppearanceChange.Surface(now.surface))
            if (style.font != old.style.font) add(AppearanceChange.Font(style.font))
            if (style.lineSpacing != old.style.lineSpacing) add(AppearanceChange.Spacing(style.lineSpacing))
            if (style.centered != old.style.centered) add(AppearanceChange.Centered(style.centered))
            if (style.scale != old.style.scale) add(AppearanceChange.LargePrint(style.scale == LyricScale.LargePrint))
        }
        changes.forEach { Analytics.track(AnalyticsEvent.AppearanceChanged(it)) }
        // Switching print scale moves the size with it; that's the large print change, not a resize.
        if (style.scale == old.style.scale && style.basePointSize.toInt() != old.style.basePointSize.toInt()) {
            val method = nextSizeMethod ?: if (style.pinchedPointSize != null) TextSizeMethod.Pinch else TextSizeMethod.Slider
            Analytics.track(AnalyticsEvent.TextSizeChanged(TextSizeContext.Reader, method, style.basePointSize.toInt()))
        }
        nextSizeMethod = null
        if (now.surface != old.surface || style.scale != old.style.scale) {
            Analytics.setAppearance(now.surface, style.scale == LyricScale.LargePrint)
        }
    }
}

/**
 * Applies a style from the Text panel's controls (which edit a whole
 * DSReadingStyle on iOS) to the saved settings, one setting at a time.
 */
fun ReadingSettings.apply(style: ReadingStyle) {
    val current = readingStyle
    if (style.scale != current.scale) {
        updateLargePrint(style.scale == LyricScale.LargePrint)
    } else if (style.pinchedPointSize != current.pinchedPointSize || style.step != current.step) {
        val pinched = style.pinchedPointSize
        if (pinched != null) pinch(pinched) else updateStep(style.step)
    }
    if (style.font != current.font) updateFont(style.font)
    if (style.lineSpacing != current.lineSpacing) updateLineSpacing(style.lineSpacing)
    if (style.centered != current.centered) updateCentered(style.centered)
}
