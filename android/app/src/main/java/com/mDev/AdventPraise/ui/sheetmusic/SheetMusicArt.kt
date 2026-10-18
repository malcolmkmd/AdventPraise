// OWNER: music
package com.mDev.AdventPraise.ui.sheetmusic

import android.graphics.Picture
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import com.caverock.androidsvg.SVG
import com.mDev.AdventPraise.data.SheetMusicHighlight
import com.mDev.AdventPraise.data.SheetMusicPage
import com.mDev.AdventPraise.settings.ReadingSurface

/**
 * One engraved page, ready to draw: the SVG (drawn in `currentColor`) inked
 * in the reading surface's text colour and recorded once into a [Picture]
 * in the page's own SVG units, so it stays sharp at any zoom.
 */
class SheetMusicArt(val page: SheetMusicPage, val picture: Picture) {
    val width: Double get() = page.width
    val height: Double get() = page.height

    companion object {
        /** Parses and records `page` in `ink` (off the main thread). Null when it can't be read. */
        fun render(page: SheetMusicPage, ink: Color): SheetMusicArt? = runCatching {
            val hex = "#%06X".format(ink.toArgbInt() and 0xFFFFFF)
            val svg = SVG.getFromString(narrowText(page.svg.replace("currentColor", hex)))
            svg.documentWidth = page.width.toFloat()
            svg.documentHeight = page.height.toFloat()
            SheetMusicArt(page, svg.renderToPicture(page.width.toInt().coerceAtLeast(1), page.height.toInt().coerceAtLeast(1)))
        }.getOrNull()

        /**
         * The pages are engraved for Times (iOS's serif), each syllable placed
         * at its own x. Android's serif (Noto Serif) sets the same words about
         * a fifth wider (Times / Noto Serif = 0.833 on a line of lyrics), so
         * neighbouring syllables would run together ("warninggive;"): the
         * lyrics are set at 0.83 to keep Times's widths, which also gives them
         * Times's x-height (0.846 of Noto Serif's).
         */
        private val fontSize = Regex("font-size=\"([0-9.]+)px\"")
        internal fun narrowText(svg: String): String = fontSize.replace(svg) { match ->
            val size = match.groupValues[1].toDoubleOrNull() ?: return@replace match.value
            "font-size=\"%.1fpx\"".format(java.util.Locale.ROOT, size * TIMES_TO_SERIF)
        }
        private const val TIMES_TO_SERIF = 0.83

        private fun Color.toArgbInt(): Int {
            val a = (alpha * 255).toInt(); val r = (red * 255).toInt(); val g = (green * 255).toInt(); val b = (blue * 255).toInt()
            return (a shl 24) or (r shl 16) or (g shl 8) or b
        }
    }
}

/** The reading surface's text colour, for the music's ink (sheetMusicInk on iOS). */
fun ReadingSurface.sheetMusicInk(): Color = when (this) {
    ReadingSurface.Paper -> Color(0xFF1C1F1E)
    ReadingSurface.Parchment -> Color(0xFF3B2F1E)
    ReadingSurface.Sepia -> Color(0xFF3E2F1D)
    ReadingSurface.Muted -> Color(0xFFD9DBD8)
    ReadingSurface.Black -> Color(0xFFE8E6E0)
}

/** The surface's tint (Evergreen), for marking what the accompaniment plays (sheetMusicAccent). */
fun ReadingSurface.sheetMusicAccent(): Color = when (this) {
    ReadingSurface.Sepia -> Color(0xFF19604F)
    ReadingSurface.Muted, ReadingSurface.Black -> Color(0xFF5FB8A6)
    else -> Color(0xFF1F7466)
}

/**
 * Draws `art` with its top-left at `origin` and `scale` dp-pixels per SVG
 * unit, the highlight's marks behind the notes: a tinted measure, a dot on
 * the melody note and the syllable being sung.
 */
fun DrawScope.drawSheetMusic(art: SheetMusicArt, origin: Offset, scale: Float, highlight: SheetMusicHighlight, accent: Color) {
    translate(origin.x, origin.y) {
        scale(scale, scale, pivot = Offset.Zero) {
            highlight.measure?.let { b ->
                drawRoundRect(accent.copy(alpha = 0.13f), Offset(b.x.toFloat(), b.y.toFloat()), Size(b.width.toFloat(), b.height.toFloat()), CornerRadius(8f))
            }
            highlight.syllable?.let { b ->
                drawRoundRect(accent.copy(alpha = 0.30f), Offset(b.x.toFloat(), b.y.toFloat()), Size(b.width.toFloat(), b.height.toFloat()), CornerRadius(4f))
            }
            highlight.note?.let { (x, y, r) ->
                drawCircle(accent.copy(alpha = 0.42f), r.toFloat(), Offset(x.toFloat(), y.toFloat()))
            }
            drawIntoCanvas { it.nativeCanvas.drawPicture(art.picture) }
        }
    }
}
