package com.mDev.AdventPraise.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.mDev.AdventPraise.settings.ReadingSurface

/** The colours of one reading surface (DSSurface on iOS). */
data class SurfacePalette(
    val surface: ReadingSurface,
    val background: Color,
    val foreground: Color,
    /** Opaque raised surface: keys on the pad, and glass where there is no blur. */
    val elevated: Color,
    val tint: Color,
    val brass: Color,
) {
    val isDark: Boolean get() = surface.isDark
    /** Secondary text, ≥ 4.5:1 on every surface. Use this, not a lower alpha, for text. */
    val secondary: Color get() = foreground.copy(alpha = if (surface == ReadingSurface.Sepia) 0.78f else 0.72f)
    /** Outline of an unfilled control (note keys, chips) on `elevated`: ≥ 3:1 on every surface. */
    val controlBorder: Color get() = foreground.copy(alpha = 0.62f)
    /** Text and icons on a solid `tint` fill (play, Go). */
    val onTint: Color get() = if (isDark) Color.Black else Color.White
    /** Text and icons on a hymnal's colour: white, or a warm off-white on dark surfaces. */
    val languageInk: Color get() = if (isDark) Color(0xFFF7F1E6) else Color.White
    val gold: Color get() = if (isDark) DS.Palette.goldDark else DS.Palette.goldLight
    /** The paywall's ground: always the dark stage on dark surfaces. */
    val paywallGround: Color get() = if (isDark) DS.Palette.stage else background

    // High contrast (worship mode): every surface collapses to one of two grounds.
    val highContrastBackground: Color get() = if (isDark) Color.Black else Color.White
    val highContrastForeground: Color get() = if (isDark) Color(0xFFF4F1EA) else Color(0xFF0B0C0C)

    /** `.primary` at an opacity step (DS.Fill), as iOS draws fills and hairlines. */
    fun primary(alpha: Float): Color = foreground.copy(alpha = alpha)

    companion object {
        fun of(surface: ReadingSurface): SurfacePalette = when (surface) {
            ReadingSurface.Paper -> SurfacePalette(surface, Color(0xFFF7F4EE), Color(0xFF1C1F1E), Color(0xFFFCFBF8), DS.Palette.evergreen, DS.Palette.brass)
            ReadingSurface.Parchment -> SurfacePalette(surface, Color(0xFFF3E9D4), Color(0xFF3B2F1E), Color(0xFFF9F2E3), DS.Palette.evergreen, DS.Palette.brass)
            ReadingSurface.Sepia -> SurfacePalette(surface, Color(0xFFE6D6B9), Color(0xFF3E2F1D), Color(0xFFEFE3CC), DS.Palette.evergreenDeep, DS.Palette.brassDeep)
            ReadingSurface.Muted -> SurfacePalette(surface, Color(0xFF262A29), Color(0xFFD9DBD8), Color(0xFF323736), DS.Palette.evergreenOnDark, DS.Palette.brassOnDark)
            ReadingSurface.Black -> SurfacePalette(surface, Color.Black, Color(0xFFE8E6E0), Color(0xFF1B1C1B), DS.Palette.evergreenOnDark, DS.Palette.brassOnDark)
        }

        /** Every surface the reader offers, in the iOS order. */
        val all: List<SurfacePalette> get() = ReadingSurface.entries.map(::of)
    }
}

/** The reading surface beneath the current composable (`\.dsSurface`). */
val LocalSurface = staticCompositionLocalOf { SurfacePalette.of(ReadingSurface.Paper) }

/** Worship mode: maximum contrast, no decoration, bigger targets (`\.dsWorshipMode`). */
val LocalWorshipMode = compositionLocalOf { false }

/**
 * True inside a glass layer (the Lectern, a standalone pad, a drawer). Controls there
 * must not add glass of their own: never glass on glass (`\.dsOnGlass`).
 */
val LocalOnGlass = compositionLocalOf { false }

private fun colorScheme(p: SurfacePalette): ColorScheme {
    val base = if (p.isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = p.tint,
        onPrimary = p.onTint,
        primaryContainer = p.tint.copy(alpha = 0.16f),
        onPrimaryContainer = p.foreground,
        secondary = p.brass,
        onSecondary = p.onTint,
        secondaryContainer = p.brass.copy(alpha = DS.Fill.tintSelected),
        onSecondaryContainer = p.foreground,
        tertiary = p.brass,
        background = p.background,
        onBackground = p.foreground,
        surface = p.background,
        onSurface = p.foreground,
        surfaceVariant = p.elevated,
        onSurfaceVariant = p.secondary,
        surfaceContainerLowest = p.background,
        surfaceContainerLow = p.elevated,
        surfaceContainer = p.elevated,
        surfaceContainerHigh = p.elevated,
        surfaceContainerHighest = p.elevated,
        surfaceBright = p.elevated,
        surfaceDim = p.background,
        inverseSurface = p.foreground,
        inverseOnSurface = p.background,
        outline = p.controlBorder,
        outlineVariant = p.foreground.copy(alpha = DS.Fill.stroke),
        error = DS.Palette.destructive,
        scrim = Color.Black,
    )
}

/**
 * The whole app is drawn on the person's reading surface, as on iOS
 * (`.dsSurface(_:)`): sets the surface, Material's colours from it, and the
 * content colour. Worship mode (or [highContrast]) collapses to the two
 * maximum-contrast grounds.
 */
@Composable
fun VesperTheme(
    surface: ReadingSurface,
    worshipMode: Boolean = false,
    highContrast: Boolean = false,
    content: @Composable () -> Unit,
) {
    val palette = SurfacePalette.of(surface)
    val high = worshipMode || highContrast
    CompositionLocalProvider(
        LocalSurface provides palette,
        LocalWorshipMode provides worshipMode,
    ) {
        MaterialTheme(colorScheme = colorScheme(palette), typography = DS.Type.material) {
            CompositionLocalProvider(
                LocalContentColor provides if (high) palette.highContrastForeground else palette.foreground,
                content = content,
            )
        }
    }
}

/** A subtree that paints its surface's ground (`.dsSurface(_, paintsBackground: true)`). */
@Composable
fun SurfaceGround(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val p = LocalSurface.current
    val high = LocalWorshipMode.current
    Box(modifier.background(if (high) p.highContrastBackground else p.background)) { content() }
}
