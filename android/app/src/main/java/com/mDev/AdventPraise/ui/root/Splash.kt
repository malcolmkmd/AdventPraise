package com.mDev.AdventPraise.ui.root

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.hypot

/** Where the launch splash is. What's New waits for [Finished]. */
enum class SplashPhase {
    /** No splash in this tree (previews, tests): nothing to wait for. */
    None,
    Showing,
    Finished,
}

val LocalSplashPhase = compositionLocalOf { SplashPhase.None }

/**
 * The logo's width on the launch screen (res/drawable/splash_logo.xml). iOS's LaunchLogo is
 * 160 pt; Android masks the splash icon to a 192 dp circle, and 140 dp is the widest the logo
 * fits inside it whole.
 */
val SplashMarkWidth = 140.dp

/** The app settles from slightly enlarged as the window opens. */
private const val CONTENT_START_SCALE = 1.06f

/**
 * Covers [content] with the splash once, when the window first appears
 * (`.splashReveal()`). It picks up from the system splash screen (the logo
 * 140 dp wide, centred, on evergreen or, in dark mode, the Stage) and reveals
 * the app through the logo: it dips, its gradient fades and it grows, a
 * logo-shaped window zooming into the book's left page until the page covers
 * the screen. About a second, critically damped. Animations off: a cross-fade.
 */
@Composable
fun SplashReveal(enabled: Boolean = true, content: @Composable () -> Unit) {
    var phase by rememberSaveable { mutableStateOf(if (enabled) SplashPhase.Showing else SplashPhase.None) }
    val contentScale = remember { Animatable(if (phase == SplashPhase.Showing) CONTENT_START_SCALE else 1f) }
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().graphicsLayer { scaleX = contentScale.value; scaleY = contentScale.value }) {
            CompositionLocalProvider(LocalSplashPhase provides phase, content = content)
        }
        if (phase == SplashPhase.Showing) {
            SplashOverlay(contentScale) { phase = SplashPhase.Finished }
        }
    }
}

/** The splash's colours: evergreen ground in light, the Stage in dark; the logo's gradient on both. */
private data class SplashPalette(val background: Color) {
    companion object {
        val Light = SplashPalette(DS.Palette.evergreen)
        val Dark = SplashPalette(DS.Palette.stage)
    }
}

@Composable
private fun SplashOverlay(contentScale: Animatable<Float, *>, onFinished: () -> Unit) {
    val palette = if (isSystemInDarkTheme()) SplashPalette.Dark else SplashPalette.Light
    val reduceMotion = rememberReduceMotion()
    val scale = remember { Animatable(1f) }
    // The logo's gradient; fading it is what opens the window.
    val markOpacity = remember { Animatable(1f) }
    val opacity = remember { Animatable(1f) }
    var size by remember { mutableStateOf(Size.Zero) }
    val markWidth = with(LocalDensity.current) { SplashMarkWidth.toPx() }

    LaunchedEffect(size) {
        if (size == Size.Zero) return@LaunchedEffect
        if (reduceMotion) {
            delay(300)
            contentScale.snapTo(1f)
            opacity.animateTo(0f, tween(400, easing = DS.Motion.easeInOut))
            onFinished()
            return@LaunchedEffect
        }
        // Hold the launch frame a beat, so the hand-off isn't felt.
        delay(150)
        coroutineScope {
            launch { scale.animateTo(0.88f, DS.Motion.criticalSpring(0.3f)) }
            delay(200)
            launch { markOpacity.animateTo(0f, tween(220, easing = DS.Motion.easeOut)) }
            launch { contentScale.animateTo(1f, DS.Motion.criticalSpring(0.75f)) }
            scale.animateTo(coverScale(size, markWidth), DS.Motion.criticalSpring(0.75f))
        }
        onFinished()
    }

    Canvas(
        Modifier
            .fillMaxSize()
            .onSizeChanged { size = Size(it.width.toFloat(), it.height.toFloat()) }
            .graphicsLayer { alpha = opacity.value }
            .clearAndSetSemantics {},
    ) {
        val mark = markRect(this.size, markWidth)
        val anchor = anchorPoint(mark)
        val logo = SDALogoShape.path(mark)
        val zoom = Matrix().apply {
            translate(anchor.x, anchor.y)
            scale(scale.value, scale.value)
            translate(-anchor.x, -anchor.y)
        }
        val zoomed = Path().apply { addPath(logo); transform(zoom) }
        // The screen with a logo-shaped hole, even-odd so the logo's own holes stay ground.
        val ground = Path().apply {
            fillType = PathFillType.EvenOdd
            addRect(Rect(Offset.Zero, this@Canvas.size))
            addPath(zoomed)
        }
        drawPath(ground, palette.background)
        withTransform({ scale(scale.value, scale.value, anchor) }) {
            drawPath(
                logo,
                Brush.linearGradient(
                    0.15f to DS.Palette.evergreenOnDark, 0.85f to DS.Palette.brassOnDark,
                    start = Offset(mark.left, mark.bottom), end = Offset(mark.right, mark.top),
                ),
                alpha = markOpacity.value,
            )
        }
    }
}

private fun markRect(screen: Size, markWidth: Float): Rect {
    val height = markWidth / SDALogoShape.ASPECT_RATIO
    return Rect(Offset((screen.width - markWidth) / 2, (screen.height - height) / 2), Size(markWidth, height))
}

private fun anchorPoint(mark: Rect) =
    Offset(mark.left + SDALogoShape.revealAnchor.x * mark.width, mark.top + SDALogoShape.revealAnchor.y * mark.height)

/**
 * Big enough that the largest disc inside the logo, which stays put while the
 * logo grows around it, clears the screen's farthest corner.
 */
private fun coverScale(screen: Size, markWidth: Float): Float {
    val anchor = anchorPoint(markRect(screen, markWidth))
    val farthest = listOf(Offset.Zero, Offset(screen.width, 0f), Offset(0f, screen.height), Offset(screen.width, screen.height))
        .maxOf { hypot(it.x - anchor.x, it.y - anchor.y) }
    return farthest / (SDALogoShape.REVEAL_RADIUS * markWidth) * 1.05f
}

/** The launch frame, still: what the screenshot test and the system splash hand-off show. */
@Composable
fun SplashFrame(modifier: Modifier = Modifier, dark: Boolean = isSystemInDarkTheme()) {
    val palette = if (dark) SplashPalette.Dark else SplashPalette.Light
    Canvas(modifier.fillMaxSize()) {
        drawRect(palette.background)
        val mark = markRect(size, SplashMarkWidth.toPx())
        drawPath(
            SDALogoShape.path(mark),
            Brush.linearGradient(
                0.15f to DS.Palette.evergreenOnDark, 0.85f to DS.Palette.brassOnDark,
                start = Offset(mark.left, mark.bottom), end = Offset(mark.right, mark.top),
            ),
        )
    }
}
