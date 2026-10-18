package com.mDev.AdventPraise.ui.theme

import android.animation.ValueAnimator
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.settings.ReadingFont
import kotlin.math.PI
import kotlin.math.pow

/**
 * Vesper, the iOS app's design system (AdventPraise/Design/DesignTokens.swift),
 * in Compose: colour, type, spacing, radii, sizes and motion. Evergreen is
 * navigation, actions and play; brass is anything musical (hymn numbers, verse
 * numerals, chorus labels, prices). Serif for anything that *is* the hymnal,
 * sans for controls.
 *
 * Fonts: iOS uses only system faces (New York, SF, Avenir Next and Baskerville
 * bold italic for the chorus), none of which may ship on Android. The Android
 * system faces stand in: serif (Noto Serif) for New York, sans (Roboto) for SF,
 * and the chorus keeps its contrast by swapping family in bold italic.
 */
object DS {
    object Palette {
        val evergreen = Color(0xFF1F7466)       // light grounds
        val evergreenDeep = Color(0xFF19604F)   // sepia ground (AA on #E6D6B9)
        val evergreenOnDark = Color(0xFF5FB8A6) // dark grounds
        val brass = Color(0xFF7F5B1C)
        val brassDeep = Color(0xFF6B4C14)       // sepia ground (AA on #E6D6B9)
        val brassOnDark = Color(0xFFD4A853)
        /** What's New / Stage: always dark, whatever the reading surface. */
        val stage = Color(0xFF0E1110)
        val stageRaised = Color(0xFF1A1F1D)
        val destructive = Color(0xFFB3261E)
        /** The paywall's gold (ProPaywall / PaywallScenery). */
        val goldLight = Color(0xFFD9A84A)
        val goldDark = Color(0xFFE2B560)
    }

    /** A hymnal's colour on light and dark surfaces (DSLanguageColor). */
    data class LanguageColor(val light: Long, val dark: Long) {
        fun fill(isDark: Boolean): Color = Color(if (isDark) dark else light)
        fun fill(on: SurfacePalette): Color = fill(on.isDark)
    }

    /**
     * One colour per hymnal, filling its whole tile or chip; the label is drawn in
     * `languageInk` at ≥ 4.5:1. Dark-surface fills are a step lighter.
     */
    object Language {
        val indigo = LanguageColor(0xFF3F3D8F, 0xFF5250A6)
        val terracotta = LanguageColor(0xFFA3452A, 0xFFA54B30)
        val sapphire = LanguageColor(0xFF1D5A94, 0xFF2866A2)
        val teal = LanguageColor(0xFF0F6878, 0xFF13707F)
        val ochre = LanguageColor(0xFF8A5908, 0xFF8F5E0C)
        val olive = LanguageColor(0xFF5C6B1A, 0xFF5F6F1D)
        val plum = LanguageColor(0xFF74305E, 0xFF8A3B70)
        val forest = LanguageColor(0xFF2D6639, 0xFF34723F)
        val clay = LanguageColor(0xFF8F4F55, 0xFF95545A)
        /** The SDA Hymnal: a book of its own beside the translations. */
        val midnight = LanguageColor(0xFF23415F, 0xFF2E5276)
        /** A hymnal without a colour of its own. */
        val slate = LanguageColor(0xFF4C5857, 0xFF5A6766)

        /** Keyed by hymnals.json key, so a colour never moves when the list changes. */
        fun color(hymnal: String): LanguageColor = when (hymnal) {
            "english" -> indigo
            "chichewa" -> terracotta
            "tswana" -> sapphire
            "xhosa" -> teal
            "sotho" -> ochre
            "shona" -> olive
            "venda" -> plum
            "zulu" -> forest
            "ndebele" -> clay
            "sdah" -> midnight
            else -> slate
        }
    }

    /** One colour per hymnal, keyed by hymnals.json key. */
    fun languageColor(hymnal: String, dark: Boolean): Color = Language.color(hymnal).fill(dark)

    /** Opacity steps for fills and strokes drawn with the foreground or a tint. Never invent new ones. */
    object Fill {
        const val row = 0.05f          // list rows, grouped sections
        const val inset = 0.06f        // keys, inputs, icon buttons
        const val hairline = 0.08f     // key borders, glass stroke (light)
        const val stroke = 0.12f       // chips, swatches, glass stroke (dark)
        const val tintActive = 0.10f   // the hymn handle while its tray is open
        const val tintSelected = 0.12f // selected chip / card
        const val tintOn = 0.14f       // toggled-on tile, current verse badge
        const val highlight = 0.18f    // search-match highlight (brass)
        const val dimmed = 0.55f       // verses not currently sung
        const val disabled = 0.40f
    }

    /** Spacing on a 4-pt grid, values taken from the Vesper screens. */
    object Space {
        val hair = 2.dp
        val xxs = 4.dp
        val xs = 6.dp
        val s = 8.dp           // between siblings in a row
        val m = 12.dp          // between groups in a panel
        val panel = 14.dp      // inner padding of Lectern panels
        val l = 20.dp          // sheet side margin, Lectern side inset
        val block = 22.dp      // between verses
        val gutter = 28.dp     // reader side margin (phone)
        val top = 38.dp        // reader top inset under the status bar
        val chorusIndent = 40.dp
        /** Max line measure for lyrics on tablets / landscape. */
        val readingMeasure = 640.dp
        /** Max width of the floating Lectern on tablets. */
        val lecternMaxWidth = 560.dp
    }

    object Size {
        val hitTarget = 44.dp
        val worshipHitTarget = 72.dp
        val lecternRow = 64.dp
        val padKey = 50.dp
        val row = 52.dp
        val compactRow = 48.dp
        val verseBadge = 26.dp
        val numberTile = 36.dp
        /** A hymnal tile (LanguageTile), before its text grows it. */
        val languageTile = 64.dp
    }

    /** Corner radii. iOS draws them continuous; Compose's rounded corners stand in. */
    object Radius {
        val dock = 32.dp     // Lectern collapsed
        val panel = 30.dp    // Lectern expanded, What's New tiles
        val capsule = 22.dp
        val card = 18.dp     // font cards, GlassCard
        val tile = 16.dp     // tray tiles, inputs, rows, swatches
        val key = 14.dp      // pad keys, primary buttons
        val chip = 14.dp
        val badge = 11.dp    // number tiles
    }

    /**
     * Chrome type, on the iOS text-style sizes at the default Dynamic Type size
     * (sp follows the system font scale). Serif for anything that is the hymnal.
     */
    object Type {
        val display = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 34.sp, lineHeight = 41.sp)
        val hymnTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, lineHeight = 34.sp)
        val sheetTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 28.sp)
        val panelTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, lineHeight = 25.sp)
        val rowTitle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 21.sp)
        val rowBody = TextStyle(fontFamily = FontFamily.Serif, fontSize = 16.sp, lineHeight = 21.sp)
        val numeral = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 22.sp)
        val padDigit = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium, fontSize = 22.sp, lineHeight = 28.sp)
        val padReadout = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium, fontSize = 28.sp, lineHeight = 34.sp)
        val label = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 20.sp)
        val button = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 15.sp, lineHeight = 20.sp)
        val detail = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 13.sp, lineHeight = 18.sp)
        val caption = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 12.sp, lineHeight = 16.sp)
        val body = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 17.sp, lineHeight = 22.sp)
        /** 11 sp bold; the caller uppercases (Eyebrow does). */
        val eyebrowBase = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 11.sp, lineHeight = 13.sp)
        /** 11 sp bold, tracked (iOS points of tracking ≈ sp of letter spacing). */
        fun eyebrow(tracking: Float = 1.3f) = eyebrowBase.copy(letterSpacing = tracking.sp)

        /** Material's typography mapped onto the ladder, for stock components. */
        val material = Typography(
            displayLarge = display, displayMedium = display, displaySmall = display,
            headlineLarge = hymnTitle, headlineMedium = sheetTitle, headlineSmall = panelTitle,
            titleLarge = sheetTitle, titleMedium = rowTitle, titleSmall = label,
            bodyLarge = body, bodyMedium = label.copy(fontWeight = FontWeight.Normal), bodySmall = detail,
            labelLarge = button, labelMedium = caption.copy(fontWeight = FontWeight.SemiBold), labelSmall = eyebrowBase,
        )
    }

    /**
     * Lyric sizes. The person picks a step; the system font scale then multiplies
     * it, capped per scale. Three scales share one slider.
     */
    enum class LyricScale(val key: String, val label: String) {
        Standard("standard", "Standard"),
        LargePrint("largePrint", "Large print"),
        Worship("worship", "Worship");

        /** Point sizes at the default font scale. */
        val steps: List<Float>
            get() = when (this) {
                Standard -> listOf(16f, 18f, 19f, 21f, 24f)
                LargePrint -> listOf(26f, 28f, 32f, 36f, 40f)
                Worship -> listOf(36f, 42f, 48f, 56f, 64f)
            }

        val defaultStep: Int get() = 2

        /** Upper bound on the font-scale multiplier: big scales would wrap a word a line. */
        val fontScaleCap: Float
            get() = when (this) {
                Standard -> 2.2f
                LargePrint -> 1.5f
                Worship -> 1.2f
            }

        /** Big type needs proportionally less leading. */
        val leadingScale: Float
            get() = when (this) {
                Standard -> 1f
                LargePrint -> 0.8f
                Worship -> 0.6f
            }

        /** How far pinch-to-zoom may take the base size. */
        val pinchRange: ClosedFloatingPointRange<Float>
            get() = when (this) {
                Standard -> 14f..32f
                LargePrint -> 24f..48f
                Worship -> 30f..80f
            }
    }

    /** The refrain's contrasting face (DS.ReadingFont.chorusFace on iOS). */
    object Chorus {
        /** Serif lyrics get a sans chorus (Avenir Next on iOS); sans lyrics a serif one (Baskerville). */
        fun family(font: ReadingFont): FontFamily = if (font == ReadingFont.Serif) FontFamily.SansSerif else FontFamily.Serif
        val weight = FontWeight.Bold
        val style = FontStyle.Italic
        /** Evens out x-height so the chorus doesn't look bigger or smaller than the verses. */
        fun sizeRatio(font: ReadingFont): Float = if (font == ReadingFont.Serif) 0.92f else 1.06f
    }

    /** The lyric family for a reading font. */
    fun lyricFamily(font: ReadingFont): FontFamily = if (font == ReadingFont.Serif) FontFamily.Serif else FontFamily.SansSerif

    /**
     * No overshoot anywhere: chrome settles with a critically damped spring or a
     * plain ease-out, so it never wobbles under a tap.
     */
    object Motion {
        /** SwiftUI's default curves. */
        val easeOut = CubicBezierEasing(0f, 0f, 0.58f, 1f)
        val easeIn = CubicBezierEasing(0.42f, 0f, 1f, 1f)
        val easeInOut = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)

        /** `Animation.spring(duration:bounce: 0)`: critically damped, settling in `seconds`. */
        fun <T> criticalSpring(seconds: Float, visibilityThreshold: T? = null): AnimationSpec<T> =
            spring(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = (2 * PI / seconds).pow(2).toFloat(), visibilityThreshold = visibilityThreshold)

        /** The Lectern opening, closing, switching panels; a tap mid-move retargets smoothly. */
        fun <T> lectern(): AnimationSpec<T> = criticalSpring(0.35f)
        /** Entering / leaving focus (chrome-free) reading. */
        fun <T> focus(): FiniteAnimationSpec<T> = tween(300, easing = easeOut)
        /** Selection of a card, swatch or chip. */
        fun <T> select(): FiniteAnimationSpec<T> = tween(200, easing = easeOut)
        /** Press-down on keys and tiles: short, no spring. */
        fun <T> press(): FiniteAnimationSpec<T> = tween(120, easing = easeOut)
        /** Current-verse highlight moving during playback / worship. */
        fun <T> verse(): FiniteAnimationSpec<T> = tween(350, easing = easeInOut)
        /** Small state changes: previews, toggles, labels. */
        fun <T> quick(): FiniteAnimationSpec<T> = tween(200, easing = easeInOut)
        /** Changing reading surface: a slow cross-fade, never a spring. */
        fun <T> surface(): FiniteAnimationSpec<T> = tween(300, easing = easeInOut)
        /** Reduce Motion: springs and moves become a plain cross-fade. */
        fun <T> reduced(): FiniteAnimationSpec<T> = tween(200, easing = easeInOut)

        /** [spec], or the plain cross-fade when the person has turned animations off. */
        fun <T> adaptive(spec: AnimationSpec<T>, reduceMotion: Boolean): AnimationSpec<T> =
            if (reduceMotion) reduced() else spec
    }

    /** How far a glass layer floats: its fill and shadow (DSGlassDepth). */
    enum class GlassDepth(val fillAlpha: Float, val shadowElevation: Float) {
        Dock(0.78f, 10f),     // collapsed Lectern, floating capsules
        Capsule(0.84f, 11f),  // expanded Lectern, pad, small floating controls
        Card(0.84f, 11f),     // GlassCard, What's New tiles
        Sheet(0.92f, 11f),    // full panels, drawers
    }
}

/**
 * Android's stand-in for Reduce Motion: animations turned off in Developer options
 * or Accessibility ("Remove animations").
 */
@Composable
fun rememberReduceMotion(): Boolean = remember { !ValueAnimator.areAnimatorsEnabled() }
