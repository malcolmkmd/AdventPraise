package com.mDev.AdventPraise.ui.design

import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfacePalette
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

/** Where a drawer rests (AdventDrawerDetent). */
sealed interface DrawerDetent {
    /** The content's own height, capped at [Large]. */
    data object Fitted : DrawerDetent
    /** A fraction of the screen height. */
    data class Fraction(val value: Float) : DrawerDetent
    /** As tall as the screen allows, below the status bar. */
    data object Large : DrawerDetent
}

/** How a drawer looks and rests (AdventDrawerStyle). */
data class AdventDrawerStyle(
    /** Opens at the smallest; a drag up reaches the rest. */
    val detents: List<DrawerDetent> = listOf(DrawerDetent.Fitted),
    /** Backdrop opacity when fully open; low where the page behind is a live preview. */
    val dimming: Float = 0.36f,
    /** Forces a reading surface (What's New is always the Stage, ReadingSurface.Black). */
    val surface: ReadingSurface? = null,
    /** Painted over the glass, under the content (the Stage's glow). */
    val background: (Modifier.() -> Modifier)? = null,
    /** The colour the action slot fades content into; the surface ground by default. */
    val actionScrim: Color? = null,
    /** The root's close button. Without it, a drag down or a backdrop tap closes. */
    val showsClose: Boolean = true,
)

/**
 * The app's modal drawer (AdventDrawer.swift): a floating glass card that rises
 * from the bottom edge and sizes itself to its content or to fixed detents.
 * The backdrop dims with it; a drag down or a backdrop tap closes it; Back
 * (predictive) goes back a page, then closes. Bottom [actions] sit in a pinned
 * slot that slides in once the content scrolls (or straight away when there is
 * nothing to scroll). Given a [pageTitle] the drawer shows a page: a bar with
 * Back and the title, and no close button.
 *
 * Mount it only while it should be up (or pass [visible]); it animates in on
 * mount and calls [onDismissed] after animating out.
 */
@Composable
fun AdventDrawer(
    title: String,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    visible: Boolean = true,
    style: AdventDrawerStyle = AdventDrawerStyle(),
    pageTitle: String? = null,
    /** Identifies the page shown (null = the root); [content] is called with it. */
    page: Any? = pageTitle,
    onBack: (() -> Unit)? = null,
    onDismissed: () -> Unit = {},
    actions: (@Composable () -> Unit)? = null,
    content: @Composable (page: Any?) -> Unit,
) {
    val inherited = LocalSurface.current
    val palette = style.surface?.let { SurfacePalette.of(it) } ?: inherited
    val reduceMotion = rememberReduceMotion()
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    // 0 = resting, 1 = fully off screen. Drives the card, the dim and the scale together.
    val offset = remember { Animatable(1f) }
    var cardHeight by remember { mutableStateOf(0) }
    var largeIndex by remember { mutableStateOf(0) }
    val isOnPage = page != null
    val enter = DS.Motion.adaptive(DS.Motion.criticalSpring<Float>(0.35f), reduceMotion)

    LaunchedEffect(visible) {
        if (visible) offset.animateTo(0f, enter) else {
            offset.animateTo(1f, enter)
            onDismissed()
        }
    }

    // Back: a page goes back, the root closes. The card follows the gesture.
    PredictiveBackHandler(enabled = visible) { progress ->
        try {
            progress.collect { event -> if (!isOnPage) offset.snapTo(event.progress * 0.3f) }
            if (isOnPage && onBack != null) onBack() else onDismissRequest()
        } catch (e: CancellationException) {
            offset.animateTo(0f, enter)
        }
    }

    CompositionLocalProvider(LocalSurface provides palette) {
        BoxWithConstraints(modifier.fillMaxSize()) {
            // Backdrop.
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = 1f - offset.value }
                    .background(Color.Black.copy(alpha = style.dimming))
                    .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onDismissRequest),
            )
            val large = style.detents.any { it == DrawerDetent.Large }
            val maxHeight: Dp = with(density) { (constraints.maxHeight).toDp() } - 10.dp
            val minHeight: Dp = style.detents.minOfOrNull { detent ->
                when (detent) {
                    is DrawerDetent.Fraction -> maxHeight * detent.value
                    DrawerDetent.Large -> maxHeight
                    DrawerDetent.Fitted -> 0.dp
                }
            } ?: 0.dp
            val wantsLarge = large && (largeIndex > 0 || style.detents.all { it == DrawerDetent.Large })
            val shape = RoundedCornerShape(28.dp)
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .windowInsetsPadding(WindowInsets.statusBars.union(WindowInsets.ime))
                    .padding(horizontal = DS.Space.s)
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(bottom = DS.Space.s)
                    .widthIn(max = 600.dp)
                    .fillMaxWidth()
                    .heightIn(min = max(minHeight.value, 120f).dp, max = maxHeight)
                    .then(if (wantsLarge) Modifier.height(maxHeight) else Modifier)
                    .onSizeChanged { cardHeight = it.height }
                    .graphicsLayer {
                        val travel = cardHeight + 96.dp.toPx()
                        translationY = if (reduceMotion) 0f else offset.value * travel
                        alpha = if (reduceMotion) 1f - offset.value else 1f
                        val s = if (reduceMotion) 1f else 1f - 0.04f * offset.value
                        scaleX = s; scaleY = s
                    }
                    .dsGlass(shape, DS.GlassDepth.Sheet)
                    .let { m -> style.background?.let { m.it() } ?: m }
                    .semantics { paneTitle = title },
            ) {
                OnGlass {
                    DrawerCard(
                        page = page,
                        pageTitle = pageTitle,
                        style = style,
                        palette = palette,
                        onBack = onBack,
                        onClose = onDismissRequest,
                        onDrag = { dy ->
                            scope.launch {
                                val travel = max(cardHeight.toFloat(), 1f)
                                offset.snapTo((offset.value + dy / travel).coerceIn(-0.05f, 1f))
                            }
                        },
                        onDragEnd = { velocity ->
                            scope.launch {
                                when {
                                    offset.value > 0.25f || velocity > 1800f -> onDismissRequest()
                                    offset.value < -0.02f || velocity < -1200f -> {
                                        if (large) largeIndex = 1
                                        offset.animateTo(0f, enter)
                                    }
                                    else -> offset.animateTo(0f, enter)
                                }
                            }
                        },
                        actions = actions,
                        content = content,
                    )
                }
            }
        }
    }
}

@Composable
private fun DrawerCard(
    page: Any?,
    pageTitle: String?,
    style: AdventDrawerStyle,
    palette: SurfacePalette,
    onBack: (() -> Unit)?,
    onClose: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: (Float) -> Unit,
    actions: (@Composable () -> Unit)?,
    content: @Composable (page: Any?) -> Unit,
) {
    val isOnPage = page != null
    val barHeight = DS.Space.s + DS.Size.hitTarget + DS.Space.xs
    val handleBand = 28.dp
    val reduceMotion = rememberReduceMotion()
    val scrim = style.actionScrim ?: palette.background

    Box {
        AnimatedContent(
            targetState = page,
            transitionSpec = {
                if (reduceMotion) fadeIn() togetherWith fadeOut()
                else if (targetState != null) (slideInHorizontally { it / 8 } + fadeIn()) togetherWith (slideOutHorizontally { -it / 8 } + fadeOut())
                else (slideInHorizontally { -it / 8 } + fadeIn()) togetherWith (slideOutHorizontally { it / 8 } + fadeOut())
            },
            label = "drawer-page",
        ) { page ->
            // Each level has its own scroller, so the root keeps its place under a page.
            val scroll = rememberScrollState()
            var latched by remember { mutableStateOf(false) }
            val reveal = when {
                actions == null || page != null -> 0f
                latched || scroll.maxValue == 0 -> 1f
                else -> min(1f, scroll.value / with(LocalDensity.current) { 56.dp.toPx() })
            }
            LaunchedEffect(reveal >= 1f) { if (reveal >= 1f) latched = true }
            Box {
                Column(Modifier.fillMaxWidth()) {
                    Column(
                        Modifier
                            .weight(1f, fill = false)
                            .verticalScroll(scroll)
                            .padding(top = if (page != null) barHeight else 0.dp),
                    ) {
                        content(page)
                        Spacer(Modifier.height(if (actions != null && page == null) DS.Space.m else DS.Space.l))
                    }
                    if (actions != null && page == null) {
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .background(Brush.verticalGradient(0f to scrim.copy(alpha = 0f), 0.45f to scrim.copy(alpha = 0.88f)))
                                .graphicsLayer {
                                    alpha = reveal
                                    translationY = if (reduceMotion) 0f else (1f - reveal) * 32.dp.toPx()
                                }
                                .padding(bottom = DS.Space.l),
                        ) { actions() }
                    }
                }
                // Fades in behind a page's bar once the page scrolls under it.
                if (page != null) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(barHeight + DS.Space.m)
                            .graphicsLayer { alpha = min(1f, scroll.value / DS.Space.m.toPx()) }
                            .background(Brush.verticalGradient(0f to scrim.copy(alpha = 0.92f), 0.6f to scrim.copy(alpha = 0.92f), 1f to scrim.copy(alpha = 0f))),
                    )
                }
            }
        }
        // The top band is a drag handle; the close or back button and a page's title sit on it.
        Box(
            Modifier
                .fillMaxWidth()
                .height(if (isOnPage) barHeight else handleBand)
                .pointerInput(Unit) {
                    var velocity = 0f
                    var last = 0L
                    detectVerticalDragGestures(
                        onDragStart = { velocity = 0f; last = System.nanoTime() },
                        onVerticalDrag = { change, dy ->
                            val now = System.nanoTime()
                            val dt = max(1L, now - last) / 1e9f
                            velocity = dy / dt
                            last = now
                            change.consume()
                            onDrag(dy)
                        },
                        onDragEnd = { onDragEnd(velocity) },
                        onDragCancel = { onDragEnd(0f) },
                    )
                },
        ) {
            Box(
                Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = DS.Space.xs)
                    .size(36.dp, 5.dp)
                    .background(palette.primary(0.28f), RoundedCornerShape(50)),
            )
        }
        Row(Modifier.fillMaxWidth().padding(top = DS.Space.s, start = DS.Space.m, end = DS.Space.m)) {
            if (isOnPage && onBack != null) GlassButton("Back", onBack, icon = Icons.AutoMirrored.Rounded.ArrowBack, kind = GlassButtonKind.Icon)
            Spacer(Modifier.weight(1f))
            if (!isOnPage && style.showsClose) GlassButton("Close", onClose, icon = Icons.Rounded.Close, kind = GlassButtonKind.Icon)
        }
        if (pageTitle != null) {
            Text(
                pageTitle,
                style = DS.Type.rowTitle,
                color = palette.foreground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = DS.Space.s + 12.dp, start = DS.Size.hitTarget + DS.Space.m + DS.Space.xs, end = DS.Size.hitTarget + DS.Space.m + DS.Space.xs)
                    .semantics { heading() },
            )
        }
    }
}
