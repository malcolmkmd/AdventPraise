package com.mDev.AdventPraise.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.settings.ReadingSurface

/**
 * Vesper, the iOS app's design system (AdventPraise/Design/DesignTokens.swift),
 * in Compose. Evergreen is navigation, actions and play; brass is anything
 * musical (hymn numbers, verse numerals, chorus labels, prices). Serif for
 * anything that *is* the hymnal, sans for controls.
 */
object DS {
    object Palette {
        val evergreen = Color(0xFF1F7466)
        val evergreenDeep = Color(0xFF19604F)
        val evergreenOnDark = Color(0xFF5FB8A6)
        val brass = Color(0xFF7F5B1C)
        val brassDeep = Color(0xFF6B4C14)
        val brassOnDark = Color(0xFFD4A853)
        val stage = Color(0xFF0E1110)
        val stageRaised = Color(0xFF1A1F1D)
        val destructive = Color(0xFFB3261E)
        val goldLight = Color(0xFFD9A84A)
        val goldDark = Color(0xFFE2B560)
    }

    /** One colour per hymnal, keyed by hymnals.json key (light, dark). */
    fun languageColor(hymnal: String, dark: Boolean): Color {
        val (light, onDark) = when (hymnal) {
            "english" -> 0xFF3F3D8F to 0xFF5250A6
            "chichewa" -> 0xFFA3452A to 0xFFA54B30
            "tswana" -> 0xFF1D5A94 to 0xFF2866A2
            "xhosa" -> 0xFF0F6878 to 0xFF13707F
            "sotho" -> 0xFF8A5908 to 0xFF8F5E0C
            "shona" -> 0xFF5C6B1A to 0xFF5F6F1D
            "venda" -> 0xFF74305E to 0xFF8A3B70
            "zulu" -> 0xFF2D6639 to 0xFF34723F
            "ndebele" -> 0xFF8F4F55 to 0xFF95545A
            // The SDA Hymnal: a book of its own beside the translations.
            "sdah" -> 0xFF23415F to 0xFF2E5276
            else -> 0xFF4C5857 to 0xFF5A6766
        }
        return Color(if (dark) onDark else light)
    }

    object Fill {
        const val row = 0.05f
        const val inset = 0.06f
        const val hairline = 0.08f
        const val stroke = 0.12f
        const val tintSelected = 0.12f
        const val tintOn = 0.14f
        const val highlight = 0.18f
        const val disabled = 0.40f
    }

    object Space {
        val hair = 2.dp
        val xxs = 4.dp
        val xs = 6.dp
        val s = 8.dp
        val m = 12.dp
        val panel = 14.dp
        val l = 20.dp
        val block = 22.dp
        val gutter = 28.dp
        val readingMeasure = 640.dp
        val lecternMaxWidth = 560.dp
    }

    object Size {
        val hitTarget = 44.dp
        val lecternRow = 64.dp
        val padKey = 50.dp
        val row = 52.dp
        val verseBadge = 26.dp
        val numberTile = 36.dp
    }

    object Radius {
        val dock = 32.dp
        val panel = 30.dp
        val capsule = 22.dp
        val card = 18.dp
        val tile = 16.dp
        val key = 14.dp
        val chip = 14.dp
        val badge = 11.dp
    }

    object Type {
        val display = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 34.sp)
        val hymnTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 28.sp)
        val sheetTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
        val panelTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 20.sp)
        val rowTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        val rowBody = TextStyle(fontFamily = FontFamily.Serif, fontSize = 16.sp)
        val numeral = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        val padDigit = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium, fontSize = 22.sp)
        val padReadout = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium, fontSize = 28.sp)
        val label = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        val button = TextStyle(fontWeight = FontWeight.Bold, fontSize = 15.sp)
        val detail = TextStyle(fontSize = 13.sp)
        val caption = TextStyle(fontSize = 12.sp)
        /** 11 sp bold, uppercase (the caller uppercases) and tracked. */
        fun eyebrow(tracking: Float = 1.3f) = TextStyle(fontWeight = FontWeight.Bold, fontSize = 11.sp, letterSpacing = tracking.sp)
    }
}

/** The colours of one reading surface (DSSurface on iOS). */
data class SurfacePalette(
    val surface: ReadingSurface,
    val background: Color,
    val foreground: Color,
    val elevated: Color,
    val tint: Color,
    val brass: Color,
) {
    val isDark: Boolean get() = surface.isDark
    /** Secondary text, ≥ 4.5:1 on every surface. */
    val secondary: Color get() = foreground.copy(alpha = if (surface == ReadingSurface.Sepia) 0.78f else 0.72f)
    val controlBorder: Color get() = foreground.copy(alpha = 0.62f)
    val onTint: Color get() = if (isDark) Color.Black else Color.White
    val languageInk: Color get() = if (isDark) Color(0xFFF7F1E6) else Color.White
    val gold: Color get() = if (isDark) DS.Palette.goldDark else DS.Palette.goldLight
    /** The paywall's ground: always the dark stage on dark surfaces. */
    val paywallGround: Color get() = if (isDark) DS.Palette.stage else background

    companion object {
        fun of(surface: ReadingSurface): SurfacePalette = when (surface) {
            ReadingSurface.Paper -> SurfacePalette(surface, Color(0xFFF7F4EE), Color(0xFF1C1F1E), Color(0xFFFCFBF8), DS.Palette.evergreen, DS.Palette.brass)
            ReadingSurface.Parchment -> SurfacePalette(surface, Color(0xFFF3E9D4), Color(0xFF3B2F1E), Color(0xFFF9F2E3), DS.Palette.evergreen, DS.Palette.brass)
            ReadingSurface.Sepia -> SurfacePalette(surface, Color(0xFFE6D6B9), Color(0xFF3E2F1D), Color(0xFFEFE3CC), DS.Palette.evergreenDeep, DS.Palette.brassDeep)
            ReadingSurface.Muted -> SurfacePalette(surface, Color(0xFF262A29), Color(0xFFD9DBD8), Color(0xFF323736), DS.Palette.evergreenOnDark, DS.Palette.brassOnDark)
            ReadingSurface.Black -> SurfacePalette(surface, Color.Black, Color(0xFFE8E6E0), Color(0xFF1B1C1B), DS.Palette.evergreenOnDark, DS.Palette.brassOnDark)
        }
    }
}

val LocalSurface = staticCompositionLocalOf { SurfacePalette.of(ReadingSurface.Paper) }

private fun colorScheme(p: SurfacePalette): ColorScheme {
    val base = if (p.isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = p.tint,
        onPrimary = p.onTint,
        primaryContainer = p.tint.copy(alpha = 0.16f),
        onPrimaryContainer = p.foreground,
        secondary = p.brass,
        onSecondary = p.onTint,
        tertiary = p.brass,
        background = p.background,
        onBackground = p.foreground,
        surface = p.background,
        onSurface = p.foreground,
        surfaceVariant = p.elevated,
        onSurfaceVariant = p.secondary,
        surfaceContainer = p.elevated,
        surfaceContainerHigh = p.elevated,
        surfaceContainerHighest = p.elevated,
        surfaceContainerLow = p.elevated,
        outline = p.controlBorder,
        outlineVariant = p.foreground.copy(alpha = DS.Fill.stroke),
        error = DS.Palette.destructive,
    )
}

/** The whole app is drawn on the person's reading surface, as on iOS. */
@Composable
fun VesperTheme(surface: ReadingSurface, content: @Composable () -> Unit) {
    val palette = SurfacePalette.of(surface)
    CompositionLocalProvider(LocalSurface provides palette) {
        MaterialTheme(colorScheme = colorScheme(palette), content = content)
    }
}
