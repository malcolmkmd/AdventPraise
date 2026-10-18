// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import android.content.Context
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.statusBarsIgnoringVisibility
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.TextSizeMethod
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.ui.design.BalancedText
import com.mDev.AdventPraise.ui.design.BlockState
import com.mDev.AdventPraise.ui.design.ChapterVerseBlock
import com.mDev.AdventPraise.ui.design.ChorusBlock
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.church.MirroringBannerSlot
import com.mDev.AdventPraise.ui.library.HymnSidebar
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import com.mDev.AdventPraise.ui.theme.readingStyle
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** The top bar's height under the status bar: the globe's row (MenuGeometry.rowHeight). */
internal val ReaderBarHeight = 52.dp
/** The bar's side margins, where the compact header and the globe sit. */
internal val ReaderBarMargin = 16.dp
/** What the collapsed Lectern takes at the bottom: the row, the handle and its margin. */
internal val LecternCollapsedHeight = DS.Size.lecternRow + 18.dp + DS.Space.s
/** iPad's regular width: the hymn list fits beside a reading measure. */
internal val WideReaderWidth = 700.dp

/** The status bar's height, kept while focus mode hides it, so the text never moves. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun statusBarTop(): Dp = WindowInsets.statusBarsIgnoringVisibility.asPaddingValues().calculateTopPadding()

/**
 * The reader (HymnReaderView): the hymn with nothing above it but the top bar
 * (the compact header and the globe), and the Lectern at the bottom. Tap the
 * text for focus mode, where everything fades and only the hymn remains.
 * Swipe sideways for the next or previous hymn, pinch to resize the text.
 *
 * Wide windows (iPad's regular width): the hymn list sits beside the reader,
 * and the Lectern's library button shows or hides it.
 */
@Composable
fun ReaderScreen(services: AppServices) {
    val model = services.reader
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.Reader) }
    AppearanceReporting(services.settings)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wide = maxWidth >= WideReaderWidth
        if (wide && model.isSidebarVisible) {
            Row(Modifier.fillMaxSize()) {
                HymnSidebar(services, Modifier.width(340.dp).fillMaxHeight())
                Box(Modifier.width(1.dp).fillMaxHeight().background(LocalSurface.current.primary(DS.Fill.stroke)))
                HymnReader(services, wide = true, Modifier.weight(1f))
            }
        } else {
            HymnReader(services, wide = wide, Modifier.fillMaxSize())
        }
    }
}

@Composable
private fun HymnReader(services: AppServices, wide: Boolean, modifier: Modifier) {
    val model = services.reader
    val settings = services.settings
    val reduceMotion = rememberReduceMotion()
    val hymnal = model.hymnal
    val hymn = model.hymn
    val focusAlpha by animateFloatAsState(if (model.isFocused) 0f else 1f, DS.Motion.adaptive(DS.Motion.focus(), reduceMotion), label = "focus")
    FocusStatusBar(model.isFocused)

    // Opening another hymn stops the one playing and cues the new one. Playlist
    // advance and the lock screen load theirs first, so this finds it cued and leaves it playing.
    LaunchedEffect(hymnal?.id, hymn?.number) {
        if (hymnal != null && hymn != null) services.player.cue(hymn, hymnal.info)
    }

    val morph = remember { HeaderMorph() }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val p = LocalSurface.current
    BoxWithConstraints(modifier) {
        val barWidth = maxWidth
        if (hymnal != null && hymn != null) HymnPage(services, hymnal, hymn, morph, scroll)
        // The soft top edge: the text fades out under the bar.
        val top = statusBarTop()
        Box(
            Modifier
                .fillMaxWidth()
                .height(top + ReaderBarHeight)
                .graphicsLayer { alpha = focusAlpha }
                .background(Brush.verticalGradient(listOf(p.background, p.background.copy(alpha = 0f)))),
        )
        // The compact header, pinned in the bar (gone with the chrome in focus mode).
        if (hymn != null && focusAlpha > 0f) {
            val centered = settings.centered
            val buttons = if (model.hasSheetMusic) 2 else 1
            val reserved = 76.dp + (DS.Size.hitTarget + DS.Space.s) * (buttons - 1)
            val capped = (barWidth - reserved * (if (centered) 2 else 1) - DS.Space.l).coerceAtLeast(120.dp)
            Box(
                Modifier
                    .padding(top = top)
                    .height(ReaderBarHeight)
                    .fillMaxWidth()
                    .padding(horizontal = ReaderBarMargin)
                    .graphicsLayer { alpha = focusAlpha },
                contentAlignment = if (centered) Alignment.Center else Alignment.CenterStart,
            ) {
                CompactHymnHeader(morph, hymn.number, hymn.title, centered, capped, reduceMotion, onTap = {
                    scope.launch { scroll.animateScrollTo(0, tween(450, easing = DS.Motion.easeInOut)) }
                })
            }
        }
        // In focus mode, four quiet bars say the accompaniment is still playing.
        val playing = hymnal != null && hymn != null && services.player.isPlaying && services.player.isHymn(hymnal.id, hymn)
        PlaybackBars(
            isAnimating = playing, color = p.tint, reduceMotion = reduceMotion,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(WindowInsets.navigationBars.asPaddingValues())
                .padding(bottom = 36.dp)
                .graphicsLayer { alpha = if (model.isFocused && playing) 0.55f else 0f },
        )
        // Mirrored without Pro: the Go Pro banner above the Lectern, which stays up in focus mode too.
        MirroringBannerSlot(
            services,
            Modifier
                .align(Alignment.BottomEnd)
                .padding(WindowInsets.navigationBars.asPaddingValues())
                .padding(start = DS.Space.l, end = DS.Space.l, bottom = LecternCollapsedHeight + DS.Space.s),
        )
        Lectern(
            services,
            wide = wide,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .graphicsLayer {
                    alpha = focusAlpha
                    translationY = (1 - focusAlpha) * 24.dp.toPx()
                },
        )
        // The globe and the menu it opens, over the reader and its bar.
        ReaderMenu(services, focusAlpha = focusAlpha)
    }
}

/** Focus mode hides the status bar, as iOS does; the text doesn't move (its inset ignores visibility). */
@Composable
private fun FocusStatusBar(focused: Boolean) {
    val view = LocalView.current
    LaunchedEffect(focused) {
        if (view.isInEditMode) return@LaunchedEffect
        val window = view.context.findActivity()?.window ?: return@LaunchedEffect
        WindowCompat.getInsetsController(window, view).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            if (focused) hide(WindowInsetsCompat.Type.statusBars()) else show(WindowInsetsCompat.Type.statusBars())
        }
    }
}

private enum class PageDirection { Forward, Back }

/**
 * The hymn's text in its scroll view, with the page swipe and pinch on it
 * (HymnReaderView's body). Horizontal swipes only: the axis is decided on the
 * first few points of movement, before the scroll view starts its own pan; a
 * horizontal drag then stops the text scrolling, so it moves on x alone. Past
 * the threshold the edge arrow fills and a haptic marks the point of no
 * return; letting go there changes the hymn, before it springs back. Under
 * Reduce Motion the text stays put while dragging and the page cross-fades.
 */
@Composable
private fun HymnPage(services: AppServices, hymnal: Hymnal, hymn: Hymn, morph: HeaderMorph, scroll: ScrollState) {
    val model = services.reader
    val settings = services.settings
    val navigator = LocalAppNavigator.current
    val reduceMotion = rememberReduceMotion()
    val density = LocalDensity.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val pinch = remember { PinchZoom() }
    var liveSize by remember { mutableStateOf<Float?>(null) }
    val pageOffset = remember { Animatable(0f) }
    val pageDrag = remember { Animatable(0f) }
    val pageFade = remember { Animatable(1f) }
    var isPaging by remember { mutableStateOf(false) }
    var pageArmed by remember { mutableStateOf(false) }
    var dragging by remember { mutableStateOf(false) }
    var pageWidth by remember { mutableFloatStateOf(390f * density.density) }
    var viewport by remember { mutableFloatStateOf(0f) }
    val threshold = PageSwipe.threshold(pageWidth, density.density)

    // The saved style, with the live pinch size while a pinch is under way.
    val saved = settings.readingStyle
    val style: ReadingStyle = liveSize?.let { saved.copy(pinchedPointSize = it) } ?: saved
    val blocks = if (settings.repeatChorus) hymn.sungSequence else hymn.blocks
    val items = remember(blocks) { ReaderBlock.list(blocks) }
    // While the accompaniment plays this hymn, the verse it is on is current and the rest dim.
    val player = services.player
    val isFollowing = player.isActive && player.isHymn(hymnal.id, hymn)
    val position = if (isFollowing) player.position else null
    val playing = isFollowing && player.isPlaying

    // A new hymn opens at the top; scrolling drives the header.
    LaunchedEffect(hymnal.id, hymn.number) { scroll.scrollTo(0) }
    LaunchedEffect(scroll) { snapshotFlow { scroll.value }.collect { morph.update(it.toFloat()) } }

    // Keep the verse being played in view as the accompaniment moves on.
    val blockTops = remember(hymnal.id, hymn.number) { mutableStateMapOf<String, Float>() }
    val followed = items.firstOrNull { ReaderBlock.state(it, position, settings.repeatChorus) == BlockState.Current }?.id
    LaunchedEffect(followed) {
        val id = followed ?: return@LaunchedEffect
        if (!playing) return@LaunchedEffect
        val y = blockTops[id] ?: return@LaunchedEffect
        scroll.animateScrollTo((y - viewport * 0.2f).toInt().coerceAtLeast(0), DS.Motion.adaptive(DS.Motion.verse(), reduceMotion))
    }

    /** Slides the hymn out, swaps it, and slides the new one in from the other side. */
    fun page(direction: PageDirection) {
        if (isPaging) return
        if ((if (direction == PageDirection.Forward) model.upcomingHymn else model.precedingHymn) == null) return
        isPaging = true
        // The compact header leaves with the old hymn; the new one opens at rest.
        morph.isHidden = true
        val exit = if (direction == PageDirection.Forward) -pageWidth else pageWidth
        scope.launch {
            launch { pageDrag.animateTo(0f, tween(160, easing = DS.Motion.easeIn)) }
            if (reduceMotion) {
                pageOffset.snapTo(0f)
                pageFade.animateTo(0f, tween(150, easing = DS.Motion.easeOut))
            } else {
                pageOffset.animateTo(exit, tween(160, easing = DS.Motion.easeIn))
            }
            val next = if (direction == PageDirection.Forward) model.goToNext(HymnSource.Swipe) else model.goToPrevious(HymnSource.Swipe)
            if (next != null) announce(context, "Hymn ${next.number}, ${next.title}")
            if (!reduceMotion) pageOffset.snapTo(-exit)
            // Let the off-screen position render before sliding in.
            delay(16)
            if (reduceMotion) pageFade.animateTo(1f, tween(150, easing = DS.Motion.easeIn))
            else pageOffset.animateTo(0f, swiftSpring(0.35f, 0.12f))
            isPaging = false
            morph.isHidden = false
        }
    }

    fun springBack() {
        scope.launch {
            launch { pageDrag.animateTo(0f, swiftSpring(0.3f, 0.2f)) }
            pageOffset.animateTo(0f, swiftSpring(0.3f, 0.2f))
        }
    }

    fun resetZoom() {
        if (settings.readingStyle.isDefaultSize) return
        AppearanceReporting.nextSizeMethod = TextSizeMethod.Reset
        settings.resetSize()
        Haptics.play(HapticEvent.SoftImpact)
    }

    // The reader's TalkBack actions, on every element in the text column.
    val actions = listOf(
        CustomAccessibilityAction(if (model.isFocused) "Show controls" else "Read full screen") { model.toggleFocus(); true },
        CustomAccessibilityAction("Next hymn") { page(PageDirection.Forward); true },
        CustomAccessibilityAction("Previous hymn") { page(PageDirection.Back); true },
        CustomAccessibilityAction("Church mode") { navigator.openChurchMode("voiceover"); true },
    )

    val top = statusBarTop()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Box(
        Modifier
            .fillMaxSize()
            .onSizeChanged { pageWidth = it.width.toFloat(); viewport = it.height.toFloat() }
            .pointerInput(hymnal.id) {
                // Pinch and the page swipe, seen before the scroll view (the Initial pass).
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                    var horizontal: Boolean? = null
                    var pinching = false
                    var startSpan = 0f
                    var dx = 0f
                    val slop = 8.dp.toPx()
                    while (true) {
                        val event = awaitPointerEvent(PointerEventPass.Initial)
                        val pressed = event.changes.filter { it.pressed }
                        if (pressed.isEmpty()) break
                        if (pressed.size >= 2) {
                            // Two fingers can't scroll, so pinching and scrolling never compete.
                            val span = (pressed[0].position - pressed[1].position).getDistance()
                            if (!pinching) {
                                pinching = true
                                startSpan = span
                                dragging = false
                                if (!isPaging && (pageOffset.value != 0f || pageDrag.value != 0f)) {
                                    scope.launch { pageOffset.snapTo(0f); pageDrag.snapTo(0f) }
                                }
                            } else if (startSpan > 0f) {
                                val base = settings.readingStyle
                                liveSize = pinch.update(span / startSpan, base.basePointSize, base.scale.pinchRange)
                            }
                            event.changes.forEach { it.consume() }
                            continue
                        }
                        if (pinching) continue
                        val change = pressed.first()
                        dx = change.position.x - down.position.x
                        val dy = change.position.y - down.position.y
                        if (horizontal == null) {
                            if (hypot(dx, dy) < slop) continue
                            horizontal = PageSwipe.isHorizontal(down.position.x, dx, dy, density.density)
                            if (horizontal == true) dragging = true
                        }
                        if (horizontal != true || pinch.isActive || isPaging) continue
                        change.consume()
                        val hasTarget = if (dx < 0) model.upcomingHymn != null else model.precedingHymn != null
                        val offset = PageSwipe.offset(dx, hasTarget)
                        scope.launch {
                            if (!reduceMotion) pageOffset.snapTo(offset)
                            pageDrag.snapTo(if (hasTarget) dx else 0f)
                        }
                        val armed = hasTarget && abs(dx) >= PageSwipe.threshold(pageWidth, density.density)
                        if (armed != pageArmed) {
                            pageArmed = armed
                            if (armed) Haptics.play(HapticEvent.ThresholdCrossed)
                        }
                    }
                    if (pinching) {
                        pinch.end()?.let { size ->
                            AppearanceReporting.nextSizeMethod = TextSizeMethod.Pinch
                            settings.pinch(size)
                        }
                        liveSize = null
                        scope.launch { delay(300); pinch.settle() }
                    } else if (horizontal == true && !isPaging) {
                        if (!pinch.isActive && pageArmed) {
                            page(if (dx < 0) PageDirection.Forward else PageDirection.Back)
                        } else {
                            // Nothing further that way.
                            if (!pinch.isActive && abs(dx) >= PageSwipe.threshold(pageWidth, density.density)) Haptics.play(HapticEvent.Limit)
                            springBack()
                        }
                    }
                    dragging = false
                    pageArmed = false
                }
            },
    ) {
        Column(
            Modifier
                .fillMaxSize()
                // A page swipe owns the drag: the hymn can't scroll under it.
                .verticalScroll(scroll, enabled = !dragging),
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .graphicsLayer {
                        translationX = pageOffset.value
                        alpha = pageFade.value * (1 - min(abs(pageOffset.value) / max(pageWidth, 1f), 1f) * 0.5f)
                    }
                    // Double-tap resets a zoomed size. Only listening while zoomed,
                    // so the single tap for focus mode isn't delayed otherwise.
                    .pointerInput(saved.isDefaultSize) {
                        detectTapGestures(
                            onDoubleTap = if (saved.isDefaultSize) null else ({ resetZoom() }),
                            onTap = { model.toggleFocus() },
                        )
                    }
                    .padding(top = top + ReaderBarHeight + DS.Space.m, bottom = bottom + LecternCollapsedHeight + DS.Space.l)
                    .wrapContentWidth(Alignment.CenterHorizontally)
                    .widthIn(max = DS.Space.readingMeasure)
                    .padding(horizontal = DS.Space.gutter),
                verticalArrangement = Arrangement.spacedBy(DS.Space.block),
                horizontalAlignment = if (style.centered) Alignment.CenterHorizontally else Alignment.Start,
            ) {
                val lift = with(density) { 10.dp.toPx() }
                val spaceM = with(density) { DS.Space.m.toPx() }
                HymnHeader(
                    hymnal, hymn, style.centered,
                    Modifier
                        // It collapses over its own height (plus the space above it).
                        .onSizeChanged { morph.range = it.height + spaceM }
                        .headerCollapse(morph, style.centered, reduceMotion, lift)
                        .semantics { customActions = actions },
                )
                items.forEach { item ->
                    val state = ReaderBlock.state(item, position, settings.repeatChorus)
                    val line = if (state == BlockState.Current) position?.line else null
                    val m = Modifier
                        .onPlaced { blockTops[item.id] = it.positionInParent().y }
                        .semantics { customActions = actions }
                    when (val block = item.block) {
                        is Block.Verse -> ChapterVerseBlock(block.number, block.lines, m, style = style, state = state, currentLine = line)
                        is Block.Chorus -> ChorusBlock(block.lines, m, label = hymnal.chorusLabel, style = style, state = state, currentLine = line)
                    }
                }
            }
        }
        // The round arrow at the edge the next hymn comes from.
        val drag = pageDrag.value
        if (drag != 0f) {
            PageArrow(
                forward = drag < 0,
                progress = abs(drag) / threshold,
                reduceMotion = reduceMotion,
                modifier = Modifier
                    .align(if (drag < 0) Alignment.CenterEnd else Alignment.CenterStart)
                    .padding(horizontal = DS.Space.s),
            )
        }
    }
}

/** Speaks the new hymn for TalkBack after a swipe. */
private fun announce(context: Context, text: String) {
    val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return
    if (!manager.isEnabled) return
    @Suppress("DEPRECATION")
    val event = AccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT)
    event.text.add(text)
    runCatching { manager.sendAccessibilityEvent(event) }
}

/**
 * The large header: the hymn number first, then the title. Centred reads as a
 * title page (the hymnal, its number and a balanced title, the other hymnals'
 * numbers below); left-aligned puts the hymnal and references in one eyebrow.
 */
@Composable
private fun HymnHeader(hymnal: Hymnal, hymn: Hymn, centered: Boolean, modifier: Modifier) {
    val p = LocalSurface.current
    val numeral = TextStyle(fontFamily = FontFamily.Serif, fontSize = 46.sp, lineHeight = 55.sp, fontFeatureSettings = "tnum")
    val title = DS.Type.hymnTitle
    Column(
        modifier
            .fillMaxWidth()
            .padding(bottom = if (centered) DS.Space.xs else 0.dp)
            .semantics(mergeDescendants = true) { heading(); contentDescription = "Hymn ${hymn.number}, ${hymn.title}" },
        horizontalAlignment = if (centered) Alignment.CenterHorizontally else Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        if (centered) {
            BalancedText(hymnal.name.uppercase(), DS.Type.eyebrow(1.6f), color = p.brass)
            Text(hymn.number.toString(), style = numeral, color = p.brass)
            BalancedText(hymn.title, title, color = p.foreground)
            if (hymn.references.isNotEmpty()) {
                BalancedText(hymn.references.joinToString(" · ").uppercase(), DS.Type.eyebrow(1.1f), Modifier.padding(top = DS.Space.xxs), color = p.secondary)
            }
        } else {
            Text(hymn.number.toString(), style = numeral, color = p.brass)
            Text(hymn.title, style = title, color = p.foreground)
            Eyebrow((listOf(hymnal.name) + hymn.references).joinToString(" · "), p.secondary, Modifier.padding(top = DS.Space.xxs), tracking = 1.1f)
        }
    }
}
