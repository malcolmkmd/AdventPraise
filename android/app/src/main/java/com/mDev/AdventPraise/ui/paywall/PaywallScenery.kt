// OWNER: shell
package com.mDev.AdventPraise.ui.paywall

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.root.SDALogoShape
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.SurfacePalette
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/*
 * The Pro paywall's picture (PaywallScenery.swift): warm gold light rising
 * from the bottom edge that slowly breathes, like light through a church
 * window, with a crowd of raised hands across the whole bottom in front of
 * it, gold-and-green silhouettes like a congregation seen from the platform.
 * The front row is large and bright; the two rows behind are smaller,
 * fainter, greener and set a little higher. Every hand lifts into view on its
 * own beat when the paywall opens, then rises and falls slowly, each in its
 * own time, with a slight lean each way. The church logo above the headline
 * glows with the same light.
 *
 * Everything is drawn: the hand is a vector path, the light is gradients. The
 * crowd is laid out from the width by a fixed hash, so it looks the same every
 * time. One frame clock drives the whole crowd in the draw phase (nothing
 * recomposes per frame). Animations off: no lift, no rise and fall, no sway
 * (the hands fade in and stand still), and the light breathes in opacity
 * only, slowly.
 */

/**
 * Screenshot tests and previews: the scenery and the rises settle at once and
 * hold still (the settled end state), with no frame loop.
 */
val LocalStillMotion = compositionLocalOf { false }

/** Still: screenshots, or animations turned off. */
@Composable
fun rememberStillMotion(): Boolean = LocalStillMotion.current

// MARK: - Palette

/** The paywall's colours on the current reading surface. */
class PaywallPalette(surface: SurfacePalette) {
    val isDark: Boolean = surface.isDark
    val ground: Color = if (surface.isDark) DS.Palette.stage else surface.background
    /** The light itself. */
    val gold: Color = if (surface.isDark) Color(0xFFE2B560) else Color(0xFFD9A84A)
    /** Text and strokes in gold: dark enough to read on light grounds. */
    val brass: Color = surface.brass
    val green: Color = surface.tint

    /** Fingertips catch the light; the wrists sit in the green of the ground. Rows further back keep less gold. */
    fun handColors(depth: Int): List<Color> = when {
        isDark && depth == 0 -> listOf(gold, gold.copy(alpha = 0.92f), green.copy(alpha = 0.85f))
        isDark && depth == 1 -> listOf(gold.copy(alpha = 0.9f), green.copy(alpha = 0.9f), green)
        isDark -> listOf(gold.copy(alpha = 0.7f), green.copy(alpha = 0.95f), green)
        depth == 0 -> listOf(brass.copy(alpha = 0.9f), brass.copy(alpha = 0.7f), green.copy(alpha = 0.75f))
        depth == 1 -> listOf(brass.copy(alpha = 0.8f), green.copy(alpha = 0.8f), green.copy(alpha = 0.9f))
        else -> listOf(brass.copy(alpha = 0.6f), green.copy(alpha = 0.85f), green.copy(alpha = 0.95f))
    }

    val logoColors: List<Color>
        get() = if (isDark) listOf(Color(0xFFF3D68C), gold, Color(0xFFB9892F))
        else listOf(Color(0xFFC89B3C), brass, Color(0xFF6B4C14))
}

// MARK: - Hand

/**
 * One raised open hand, palm to the viewer, thumb on the leading side, forearm
 * running off the bottom (PraiseHandShape). In unit space (x 0…1, y 0…1 down);
 * overlaps are unioned into one outline, so a translucent fill shows no seams.
 */
object PraiseHand {
    /** Width over height of the drawing. */
    const val ASPECT_RATIO = 0.78f

    private class Finger(val x: Float, val y: Float, val angle: Float, val length: Float, val width: Float)

    private val fingers = listOf(
        Finger(0.34f, 0.56f, -46f, 0.25f, 0.115f), // thumb
        Finger(0.39f, 0.42f, -7f, 0.29f, 0.105f),  // index
        Finger(0.50f, 0.41f, -1f, 0.33f, 0.105f),  // middle
        Finger(0.61f, 0.42f, 5f, 0.30f, 0.10f),    // ring
        Finger(0.70f, 0.46f, 12f, 0.23f, 0.095f),  // little
    )

    /** The outline in unit space. Built once. */
    val unitPath: Path by lazy {
        fun rounded(x: Float, y: Float, w: Float, h: Float, r: Float) =
            Path().apply { addRoundRect(RoundRect(Rect(x, y, x + w, y + h), CornerRadius(r))) }
        var hand = Path.combine(PathOperation.Union, rounded(0.37f, 0.58f, 0.27f, 0.60f, 0.07f), rounded(0.30f, 0.37f, 0.43f, 0.32f, 0.12f))
        for (f in fingers) {
            val capsule = rounded(-f.width / 2, -f.length - f.width / 2, f.width, f.length + f.width, f.width / 2)
            capsule.transform(Matrix().apply { translate(f.x, f.y); rotateZ(f.angle) })
            hand = Path.combine(PathOperation.Union, hand, capsule)
        }
        hand
    }
}

// MARK: - Crowd

/** Where one hand in the crowd stands and how it moves (CrowdHandSpec). Lengths in px, times in seconds. */
data class CrowdHandSpec(
    val id: String,
    /** 0 is the front row; 1 and 2 stand behind it. */
    val depth: Int,
    /** Centre, from the leading edge. */
    val x: Float,
    /** How far above the bottom edge the wrist sits. */
    val baseline: Float,
    val width: Float,
    val height: Float,
    /** Thumb on the trailing side. */
    val flipped: Boolean,
    /** Degrees from upright, as the hand rests. */
    val lean: Float,
    val opacity: Float,
    /** Seconds after the opening before this hand rises into view. */
    val liftDelay: Double,
    val swayAmplitude: Double,
    val swayPeriod: Double,
    val swayDelay: Double,
    /** The slow rise and fall after the lift-in: travel, full period, and when it starts. */
    val bobTravel: Float,
    val bobPeriod: Double,
    val bobDelay: Double,
)

object PraiseCrowd {
    private class Row(val scale: Float, val rise: Float, val spacing: Float, val opacity: Float, val travel: Float)

    /** Front to back: the front row travels furthest, the back row least, as a crowd looks in depth. */
    private val rows = listOf(
        Row(1.00f, 0.00f, 0.80f, 1.00f, 0.070f),
        Row(0.74f, 0.26f, 0.82f, 0.62f, 0.042f),
        Row(0.52f, 0.48f, 0.84f, 0.40f, 0.024f),
    )

    /** How much taller than a front-row hand the crowd stands. */
    const val HEIGHT_FACTOR = 1.3f

    /** A fixed, even spread in 0…<1 for hand `index` in row `depth` (the classic sine hash). */
    private fun noise(index: Int, depth: Int, salt: Int): Double {
        val x = sin(index * 12.9898 + depth * 78.233 + salt * 37.719) * 43758.5453
        return x - floor(x)
    }

    /** The crowd for a band [width] wide, front row hands [height] tall. Back rows first, so the front row draws over them. */
    fun layout(width: Float, height: Float): List<CrowdHandSpec> {
        val specs = mutableListOf<CrowdHandSpec>()
        for (depth in rows.indices.reversed()) {
            val row = rows[depth]
            val rowHeight = height * row.scale
            val rowWidth = rowHeight * PraiseHand.ASPECT_RATIO
            val spacing = rowWidth * row.spacing
            // Rows behind are offset by half a step so they show between the hands in front.
            val start = -spacing * 0.2f + if (depth % 2 == 1) spacing * 0.5f else 0f
            val count = ceil((width + spacing * 0.4f) / spacing).toInt() + 1
            for (index in 0 until count) {
                val sizeVariation = 1f + ((noise(index, depth, 1) - 0.5) * 0.26).toFloat()
                val handHeight = rowHeight * sizeVariation
                val x = start + (index + 0.5f) * spacing + ((noise(index, depth, 2) - 0.5) * spacing * 0.36).toFloat()
                val leanSign = if (noise(index, depth, 3) < 0.5) -1f else 1f
                val liftDelay = 0.12 + depth * 0.14 + noise(index, depth, 8) * 0.34
                // The rise and fall starts once the lift-in has settled, a little later for each hand
                // across the width and each row back, so it ripples through the crowd.
                val across = max(0.0, min(1.0, (x / max(width, 1f)).toDouble()))
                val bobDelay = liftDelay + 1.1 + across * 1.4 + depth * 0.3 + noise(index, depth, 13) * 0.7
                specs += CrowdHandSpec(
                    id = "$depth.$index",
                    depth = depth,
                    x = x,
                    baseline = height * row.rise + ((noise(index, depth, 4) - 0.5) * height * 0.08).toFloat(),
                    width = handHeight * PraiseHand.ASPECT_RATIO,
                    height = handHeight,
                    flipped = noise(index, depth, 5) < 0.5,
                    lean = leanSign * (4f + (noise(index, depth, 6) * 10).toFloat()),
                    opacity = row.opacity * (0.88f + (noise(index, depth, 7) * 0.12).toFloat()),
                    liftDelay = liftDelay,
                    swayAmplitude = 1.1 + noise(index, depth, 9) * 1.2,
                    swayPeriod = 2.9 + noise(index, depth, 10) * 1.5,
                    swayDelay = 0.9 + noise(index, depth, 11) * 1.8,
                    bobTravel = height * row.travel * (0.8f + (noise(index, depth, 12) * 0.4).toFloat()),
                    bobPeriod = 3.2 + noise(index, depth, 14) * 1.6,
                    bobDelay = bobDelay,
                )
            }
        }
        return specs
    }
}

// MARK: - Motion helpers

/** A critically damped spring settling in about [duration] seconds, at [t] seconds (0 → 1). */
private fun springProgress(t: Double, duration: Double): Float {
    if (t <= 0) return 0f
    val omega = 2 * PI / duration
    return (1 - (1 + omega * t) * exp(-omega * t)).toFloat().coerceIn(0f, 1f)
}

/** easeInOut back and forth: 0 → 1 over [half] seconds, then back, forever; 0 before it starts. */
private fun pingPong(t: Double, half: Double): Float {
    if (t <= 0) return 0f
    val phase = t / half
    val cycle = floor(phase).toLong()
    val frac = phase - cycle
    val eased = (0.5 - 0.5 * cos(PI * frac)).toFloat()
    return if (cycle % 2 == 0L) eased else 1f - eased
}

/** Seconds since the scenery appeared, ticking every frame while it animates; null when still. */
@Composable
private fun rememberSceneryClock(animates: Boolean): State<Long>? {
    if (!animates) return null
    val nanos = remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) withFrameNanos { nanos.longValue = it - start }
    }
    return nanos
}

// MARK: - Light

/**
 * Gold light rising from the bottom edge, breathing: a steady warm floor, a
 * pool of light at the bottom centre and two soft columns through it, like
 * window lights on a floor. [intensity] is lower for small sheets.
 */
@Composable
fun PaywallLight(palette: PaywallPalette, modifier: Modifier = Modifier, intensity: Float = 1f) {
    val still = rememberStillMotion()
    val reduce = rememberReduceMotion()
    val breath = if (still) 1f else {
        val transition = rememberInfiniteTransition(label = "paywall-light")
        val period = if (reduce) 6500 else 4600
        transition.animateFloat(0f, 1f, infiniteRepeatable(tween(period, easing = DS.Motion.easeInOut), RepeatMode.Reverse), label = "breath").value
    }
    val gold = palette.gold
    val wash = (if (palette.isDark) 0.36f else 0.30f) * intensity
    Box(modifier.fillMaxSize().clearAndSetSemantics {}) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.verticalGradient(0.42f to gold.copy(alpha = 0f), 1f to gold.copy(alpha = wash)))
        }
        // The breathing part.
        Canvas(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = 0.62f + 0.38f * breath
                    // Animations off: opacity only.
                    val grow = if (reduce) 0f else breath
                    scaleX = 1f + 0.06f * grow
                    scaleY = 1f + 0.10f * grow
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)
                    compositingStrategy = CompositingStrategy.Offscreen
                },
        ) {
            // The pool: an ellipse centred just under the bottom edge.
            val pool = (if (palette.isDark) 0.55f else 0.42f) * intensity
            val center = Offset(size.width * 0.5f, size.height * 1.04f)
            val ry = 0.72f * size.height / 2
            val rx = 0.72f * size.width / 2
            if (ry > 0f && rx > 0f) {
                scale(rx / ry, 1f, center) {
                    drawRect(Brush.radialGradient(listOf(gold.copy(alpha = pool), gold.copy(alpha = 0f)), center, ry),
                        topLeft = Offset(center.x - size.width, 0f), size = Size(size.width * 2, size.height))
                }
            }
            // Two columns, fading in toward the bottom.
            val column = 0.16f * intensity
            drawColumns(gold, column)
        }
    }
}

private fun DrawScope.drawColumns(gold: Color, alpha: Float) {
    val layer = Rect(Offset.Zero, size)
    drawContext.canvas.saveLayer(layer, androidx.compose.ui.graphics.Paint())
    drawRect(Brush.horizontalGradient(
        0.18f to gold.copy(alpha = 0f), 0.36f to gold.copy(alpha = alpha), 0.50f to gold.copy(alpha = 0f),
        0.64f to gold.copy(alpha = alpha), 0.82f to gold.copy(alpha = 0f),
    ))
    drawRect(Brush.verticalGradient(0.3f to Color.Transparent, 1f to Color.Black), blendMode = BlendMode.DstIn)
    drawContext.canvas.restore()
}

// MARK: - Hands

/**
 * The crowd of raised hands across the bottom edge. They lift into view when
 * [lifted] turns true, each on its own beat, then rise, fall and sway gently
 * and independently. [height] is a front-row hand's; the forearms run off the bottom.
 */
@Composable
fun PaywallHands(palette: PaywallPalette, lifted: Boolean, modifier: Modifier = Modifier, height: Dp = 190.dp) {
    val still = rememberStillMotion()
    val reduce = rememberReduceMotion()
    val clock = rememberSceneryClock(!still)
    // When the lift began, on the scenery clock.
    var liftedAt by remember { mutableLongStateOf(-1L) }
    LaunchedEffect(lifted, clock) { if (lifted && liftedAt < 0) liftedAt = clock?.value ?: 0L }
    val bandOpacity = if (palette.isDark) 0.62f else 0.46f
    Canvas(
        modifier
            .fillMaxWidth()
            .height(height * PraiseCrowd.HEIGHT_FACTOR)
            .graphicsLayer { alpha = bandOpacity; compositingStrategy = CompositingStrategy.Offscreen }
            .clearAndSetSemantics {},
    ) {
        val handHeight = height.toPx()
        val specs = PraiseCrowd.layout(size.width, handHeight)
        // Read in the draw phase only: every frame redraws, nothing recomposes.
        val now = (clock?.value ?: 0L) / 1e9
        val since = if (still) 1e6 else if (liftedAt < 0 || !lifted) -1.0 else now - liftedAt / 1e9
        for (spec in specs) {
            val t = since
            val lift = when {
                still -> 1f
                reduce -> if (t < 0) 0f else min(1f, ((t - spec.liftDelay * 0.4) / 0.6).toFloat().coerceAtLeast(0f))
                else -> springProgress(t - spec.liftDelay, 1.5)
            }
            if (lift <= 0f) continue
            val moving = !still && !reduce
            val drop = if (moving) (1f - lift) * spec.height * 0.95f else 0f
            val sway = if (moving) (-1f + 2f * pingPong(t - spec.swayDelay, spec.swayPeriod)) * spec.swayAmplitude.toFloat() else 0f
            val bob = if (moving) pingPong(t - spec.bobDelay, spec.bobPeriod / 2) * spec.bobTravel else 0f
            val left = spec.x - spec.width / 2
            val top = size.height - spec.baseline - spec.height - bob + drop
            val brush = Brush.verticalGradient(palette.handColors(spec.depth), startY = 0f, endY = 1f)
            translate(left, top) {
                rotate(spec.lean + sway, Offset(spec.width / 2, spec.height)) {
                    scale(if (spec.flipped) -1f else 1f, 1f, Offset(spec.width / 2, 0f)) {
                        scale(spec.width, spec.height, Offset.Zero) {
                            drawPath(PraiseHand.unitPath, brush, alpha = spec.opacity * (if (reduce) lift else min(1f, lift * 1.2f)))
                        }
                    }
                }
            }
        }
        // The fingertips soften into the light, so words scrolled over them stay readable.
        drawRect(
            Brush.verticalGradient(0f to Color.Black.copy(alpha = 0.12f), 0.3f to Color.Black.copy(alpha = 0.5f), 0.62f to Color.Black),
            blendMode = BlendMode.DstIn,
        )
    }
}

// MARK: - Logo

/** The church logo, lit from below: a gold fill with a soft glow behind it that breathes with the light. */
@Composable
fun PaywallLogo(palette: PaywallPalette, modifier: Modifier = Modifier, width: Dp = 84.dp) {
    val still = rememberStillMotion()
    val reduce = rememberReduceMotion()
    val glow = if (still) 1f else {
        val transition = rememberInfiniteTransition(label = "paywall-logo")
        transition.animateFloat(0f, 1f, infiniteRepeatable(tween(if (reduce) 6500 else 4600, easing = DS.Motion.easeInOut), RepeatMode.Reverse), label = "glow").value
    }
    val height = width / SDALogoShape.ASPECT_RATIO
    Box(modifier.size(width, height).semantics { contentDescription = "Seventh-day Adventist Church logo" }, contentAlignment = Alignment.Center) {
        // The glow: drawn in a canvas with room around the logo, so the blur fades out inside it.
        Canvas(
            Modifier
                .requiredSize(width * 2, height * 2)
                .graphicsLayer { alpha = (0.45f + 0.45f * glow) * (if (palette.isDark) 1f else 0.6f) }
                .blur(width * 0.2f, BlurredEdgeTreatment.Unbounded),
        ) {
            val w = size.width / 2 * 1.18f
            val h = size.height / 2 * 1.18f
            drawPath(SDALogoShape.path(Rect(Offset((size.width - w) / 2, (size.height - h) / 2), Size(w, h))), palette.gold)
        }
        Canvas(Modifier.size(width, height)) {
            drawPath(SDALogoShape.path(Rect(Offset.Zero, size)), Brush.verticalGradient(palette.logoColors))
        }
    }
}

// MARK: - Backdrop

/** Ground, light and the crowd together, for the paywall, Support and the thank-you. */
@Composable
fun PaywallBackdrop(
    palette: PaywallPalette,
    lifted: Boolean,
    modifier: Modifier = Modifier,
    handHeight: Dp = 190.dp,
    lightIntensity: Float = 1f,
    content: @Composable BoxScope.() -> Unit = {},
) {
    Box(
        modifier
            .fillMaxSize()
            .clipToBounds()
            .drawWithContent { drawRect(palette.ground); drawContent() },
    ) {
        PaywallLight(palette, intensity = lightIntensity)
        PaywallHands(
            palette, lifted,
            Modifier.align(Alignment.BottomCenter).offset(y = handHeight * 0.1f),
            height = handHeight,
        )
        content()
    }
}
