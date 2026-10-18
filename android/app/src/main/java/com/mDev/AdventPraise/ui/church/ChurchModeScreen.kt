// OWNER: church
package com.mDev.AdventPraise.ui.church

import android.Manifest
import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.church.ChurchState
import com.mDev.AdventPraise.church.notification.ChurchNotifier
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.settings.LyricScale
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.ChorusRule
import com.mDev.AdventPraise.ui.design.DSHymnSummary
import com.mDev.AdventPraise.ui.design.DSHymnal
import com.mDev.AdventPraise.ui.design.DSHymnalAccess
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.HymnNumberPad
import com.mDev.AdventPraise.ui.design.LanguageTile
import com.mDev.AdventPraise.ui.design.LanguageTileGrid
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.root.SystemBarsAppearance
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.VesperTheme
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import com.mDev.AdventPraise.ui.tour.TourSignal
import kotlinx.coroutines.delay
import kotlin.math.abs

/**
 * Church mode (ChurchModeView): one verse or chorus at a time, large, on
 * the maximum-contrast black ground, with the screen kept awake. Tap the
 * right side to go forward, the left third to go back, or swipe; pinch to
 * size the text, double-tap to reset it. The controls hide after a few
 * seconds and a tap brings them back. With Pro a TV (a second display now,
 * Cast later) gets the worship display and this screen becomes its remote,
 * with Next hymn and Blank too; without Pro a connected screen mirrors this
 * one and the Go Pro banner sits under the controls.
 */
@Composable
fun ChurchModeScreen(services: AppServices, navigator: AppNavigator, source: String, onClose: () -> Unit) {
    val session = services.church
    val reader = services.reader
    val queue = services.queue
    val state by session.state.collectAsState()
    val context = LocalContext.current
    val presenter = remember(session) {
        ChurchPresenter(
            session, services.settings, services.appSettings,
            openPaywall = { navigator.openPaywall(it, "church_mode") },
            close = onClose,
        )
    }

    // Started once per visit (a rotation keeps it); stopped when church mode leaves the stack.
    LaunchedEffect(Unit) {
        if (!session.current.isActive) session.start(churchModeSource(source))
    }
    DisposableEffect(Unit) {
        onDispose { if (navigator.stack.none { it is Destination.ChurchMode }) session.stop() }
    }
    // The notification's End button.
    LaunchedEffect(state.endRequested) {
        if (state.endRequested) { session.acknowledgeEnd(); onClose() }
    }
    // The ongoing notification starts with Pro (iOS's Live Activity): ask to post it then, once.
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    LaunchedEffect(state.isPro) {
        if (state.isPro && Build.VERSION.SDK_INT >= 33 && ChurchNotifier.shouldAsk(context)) {
            ChurchNotifier.markAsked(context)
            permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    KeepsScreenAwake()
    SystemBarsAppearance(dark = true)
    HidesSystemBars()

    var popover by rememberSaveable { mutableStateOf<WorshipPopover?>(null) }
    var digits by remember { mutableStateOf("") }
    val hymnal = reader.hymnal
    val hymn = state.hymn
    val running = if (hymnal != null && hymn != null) queue.runningQueue(hymnal, hymn) else null
    val upcoming = if (hymnal != null && hymn != null) queue.upcomingHymn(hymnal, hymn) != null else state.hasNextHymn
    val settings = services.settings

    ChurchModeContent(
        state = state,
        worshipPointSize = settings.worshipPointSize,
        largePrint = settings.largePrint,
        isDefaultSize = settings.isDefaultWorshipSize,
        canShrinkText = settings.worshipStepTarget(-1) != null,
        canEnlargeText = settings.worshipStepTarget(1) != null,
        language = hymnal?.info?.shortLabel.orEmpty(),
        hasUpcomingHymn = upcoming,
        presenter = presenter,
        popover = popover,
        onPopover = { next ->
            if (next == WorshipPopover.NumberPad) { digits = ""; Analytics.screen(AnalyticsScreen.NumberPad) }
            if (next == WorshipPopover.Translations) Analytics.screen(AnalyticsScreen.Translations)
            popover = next
        },
        onExit = onClose,
        onTv = { if (state.isPro) navigator.navigate(Destination.ScreenMirroringHelp) else presenter.tvLocked() },
        onAnnouncement = { navigator.navigate(Destination.ChurchAnnouncement) },
        onImage = { navigator.navigate(Destination.ChurchImage) },
        banner = { MirroringBannerSlot(services, it, inChurchMode = true) },
        tourActive = services.tour.isActive,
        onActionsOpen = { services.tour.observe(TourSignal.ChurchActionsOpen(it)) },
        numberPad = {
            Column(Modifier.width(340.dp)) {
                if (running != null && hymnal != null && hymn != null) {
                    ChurchQueueList(running, title = { hymnal.hymn(it)?.title }, onSelect = { index ->
                        popover = null
                        queue.jump(index, hymnal, hymn)?.let { (target, src) ->
                            reader.show(target, src.key)
                            Haptics.play(HapticEvent.PageTurn)
                        }
                    }, modifier = Modifier.padding(start = DS.Space.panel, end = DS.Space.panel, top = DS.Space.panel))
                }
                HymnNumberPad(
                    digits = digits,
                    onDigitsChange = { proposed ->
                        // Never a number past the end of the hymnal (like the Lectern pad).
                        val value = proposed.toIntOrNull()
                        if (proposed.length > digits.length && (value == null || value > maxOf(hymnal?.info?.maxNumber ?: 1, 1))) {
                            Haptics.play(HapticEvent.Limit)
                        } else digits = proposed
                    },
                    title = { hymnal?.hymn(it)?.title },
                    onGo = { number ->
                        popover = null
                        val index = if (hymnal != null && hymn != null) queue.runningQueue(hymnal, hymn)?.index(number) else null
                        // A number on the running list jumps within it; any other leaves it.
                        if (index != null && hymnal != null && hymn != null) {
                            queue.jump(index, hymnal, hymn)?.let { (target, src) -> reader.show(target, src.key) }
                        } else if (reader.open(number, "numpad")) {
                            queue.stop()
                        }
                        Haptics.play(HapticEvent.PageTurn)
                    },
                    recents = if (running == null && hymnal != null) {
                        reader.recents.mapNotNull { n -> hymnal.hymn(n)?.let { DSHymnSummary(n, it.title) } }
                    } else emptyList(),
                    isStandalone = false,
                )
            }
        },
        translations = {
            ChurchTranslations(
                catalogue = reader.catalogue,
                current = hymnal?.info,
                number = hymn?.number,
                numberIn = reader::numberIn,
            ) { info ->
                reader.switchHymnal(info, "church_mode")
                Haptics.play(HapticEvent.MediumImpact)
                popover = null
            }
        },
    )
}

private fun churchModeSource(key: String): ChurchModeSource =
    ChurchModeSource.entries.firstOrNull { it.key == key } ?: ChurchModeSource.Tray

/**
 * Church mode drawn from plain values, for the screen and its screenshot
 * tests. Always the black, maximum-contrast surface, whatever the reader's.
 */
@Composable
internal fun ChurchModeContent(
    state: ChurchState,
    worshipPointSize: Float,
    largePrint: Boolean,
    isDefaultSize: Boolean,
    canShrinkText: Boolean,
    canEnlargeText: Boolean,
    language: String,
    hasUpcomingHymn: Boolean,
    presenter: ChurchPresenter,
    popover: WorshipPopover?,
    onPopover: (WorshipPopover?) -> Unit,
    onExit: () -> Unit,
    onTv: () -> Unit,
    onAnnouncement: () -> Unit,
    onImage: () -> Unit,
    banner: @Composable (Modifier) -> Unit,
    numberPad: @Composable () -> Unit,
    translations: @Composable () -> Unit,
    initialControlsVisible: Boolean = true,
    /** The tour points at the controls: they stay up. */
    tourActive: Boolean = false,
    /** The presenter actions opened or closed (the tour's church step follows it). */
    onActionsOpen: (Boolean) -> Unit = {},
) {
    VesperTheme(ReadingSurface.Black, worshipMode = true) {
        val p = LocalSurface.current
        var controlsVisible by remember { mutableStateOf(initialControlsVisible) }
        var hideGeneration by remember { mutableIntStateOf(0) }
        var topBarHeight by remember { mutableStateOf(92.dp) }
        var bannerHeight by remember { mutableStateOf(0.dp) }
        var liveSize by remember { mutableStateOf<Float?>(null) }
        val talkBack = rememberTalkBack()
        val focus = remember { FocusRequester() }
        val density = LocalDensity.current
        fun showControls() { controlsVisible = true; hideGeneration++ }

        // Each showControls() restarts the countdown. They stay up while a popover
        // is open, and always for TalkBack.
        val actionsOpen = popover == WorshipPopover.Actions
        OnChange(actionsOpen, onActionsOpen)
        LaunchedEffect(hideGeneration, popover, talkBack, tourActive) {
            if (popover == null) runCatching { focus.requestFocus() }
            if (tourActive) controlsVisible = true
            if (!controlsVisible || popover != null || talkBack || tourActive) return@LaunchedEffect
            delay(4000)
            controlsVisible = false
        }

        val isOnTV = state.isOnExternalScreen
        val actions = WorshipActions(
            isBlanked = state.isBlanked, hasAnnouncement = state.announcement != null, hasImage = state.image != null,
            isLocked = !state.isPro,
            onToggleBlank = { presenter.presenterAction { presenter.toggleBlank(); showControls() } },
            onAnnouncement = { presenter.presenterAction(onAnnouncement) },
            onImage = { presenter.presenterAction(onImage) },
            onClear = { presenter.clearSpecial(); showControls() },
        )
        val advance = { presenter.advance(); showControls() }
        val previous = { presenter.previous(); showControls() }
        val canGoForward = !state.isLast || hasUpcomingHymn
        val bannerInset = if (bannerHeight > 0.dp) bannerHeight + DS.Space.s else 0.dp

        Box(
            Modifier
                .fillMaxSize()
                .background(p.highContrastBackground)
                .focusRequester(focus)
                .focusable()
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.DirectionRight, Key.DirectionDown, Key.Spacebar, Key.PageDown -> { if (canGoForward) advance(); canGoForward }
                        Key.DirectionLeft, Key.DirectionUp, Key.PageUp -> { if (state.canGoBack) previous(); state.canGoBack }
                        Key.Escape -> { onExit(); true }
                        else -> false
                    }
                }
                .semantics {
                    customActions = listOf(
                        CustomAccessibilityAction("Next verse") { advance(); true },
                        CustomAccessibilityAction("Previous verse") { previous(); true },
                        CustomAccessibilityAction("Jump to hymn number") { showControls(); onPopover(WorshipPopover.NumberPad); true },
                        CustomAccessibilityAction("Change translation") { showControls(); onPopover(WorshipPopover.Translations); true },
                    )
                },
        ) {
            val dim by animateFloatAsState(if (state.isBlanked || state.isShowingSpecial) 0.35f else 1f, DS.Motion.quick(), label = "dim")
            Lyric(
                state = state,
                lyricSize = lyricSize(liveSize ?: worshipPointSize, largePrint, density.fontScale),
                topInset = topBarHeight + DS.Space.s + DS.Space.l,
                bottomInset = 112.dp + bannerInset,
                modifier = Modifier
                    .fillMaxSize()
                    // The phone is the remote: dimmed while the big screen is blank.
                    .alpha(dim)
                    .pointerInput(controlsVisible, isDefaultSize) {
                        detectTapGestures(
                            onDoubleTap = if (isDefaultSize) null else { _ -> presenter.resetTextSize(); showControls() },
                            onTap = { offset ->
                                if (!controlsVisible) showControls()
                                else if (offset.x < size.width * 0.33f) previous() else advance()
                            },
                        )
                    }
                    .lyricGestures(
                        base = { worshipPointSize },
                        onPinch = { liveSize = it },
                        onPinchEnd = { size -> liveSize = null; size?.let(presenter::pinched) },
                        onSwipe = { forward -> if (forward) advance() else previous() },
                    ),
            )

            WorshipModeControls(
                hymnNumber = state.hymn?.number ?: 0,
                title = state.hymn?.title.orEmpty(),
                position = state.tvStatus ?: state.position,
                step = state.index,
                stepCount = state.sequence.size,
                language = language,
                canGoBack = state.canGoBack,
                canGoForward = canGoForward,
                canShrinkText = canShrinkText,
                canEnlargeText = canEnlargeText && lyricSize(worshipPointSize, largePrint, density.fontScale) < MAX_POINT_SIZE,
                isVisible = controlsVisible,
                tv = if (state.isPro) WorshipTv.Available else WorshipTv.Locked,
                isOnExternalScreen = isOnTV,
                remote = if (isOnTV) WorshipRemote(state.isBlanked, hasUpcomingHymn,
                    onToggleBlank = { presenter.toggleBlank(); showControls() },
                    onNextHymn = { presenter.nextHymnFromRemote(); showControls() }) else null,
                actions = actions,
                popover = popover,
                onPopover = { onPopover(it); if (it == null) showControls() },
                onTv = onTv,
                onPrevious = previous,
                onNext = advance,
                onExit = onExit,
                onTextSmaller = { presenter.changeTextSize(-1); showControls() },
                onTextLarger = { presenter.changeTextSize(1); showControls() },
                onTopBarHeight = { topBarHeight = it },
                modifier = Modifier.padding(bottom = bannerInset),
                numberPad = numberPad,
                translations = translations,
            )

            // Mirrored without Pro: under the controls, and up even when they hide.
            Box(
                Modifier
                    .fillMaxSize()
                    .windowInsetsPadding(WindowInsets.safeDrawing)
                    .padding(horizontal = DS.Space.l, vertical = DS.Space.s),
                contentAlignment = Alignment.BottomEnd,
            ) {
                banner(Modifier.onSizeChanged { bannerHeight = with(density) { it.height.toDp() } })
            }
        }
    }
}

private const val MIN_POINT_SIZE = 28f
private const val MAX_POINT_SIZE = 96f

/** The chosen size × the font scale (capped like the reader) × large print, clamped. */
internal fun lyricSize(base: Float, largePrint: Boolean, fontScale: Float): Float {
    val print = if (largePrint) 1.2f else 1f
    return (base * minOf(fontScale, LyricScale.Worship.fontScaleCap) * print).coerceIn(MIN_POINT_SIZE, MAX_POINT_SIZE)
}

/**
 * The verse being sung, as large as chosen; a verse too long for the screen
 * scrolls rather than shrinking. The chorus gets the reader's chorus face
 * and its brass rule. A new block slides in from the right.
 */
@Composable
private fun Lyric(state: ChurchState, lyricSize: Float, topInset: Dp, bottomInset: Dp, modifier: Modifier) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val density = LocalDensity.current
    val fontScale = density.fontScale
    val shift = with(density) { 24.dp.roundToPx() }
    val key = "${state.hymnalId}-${state.hymn?.number}-${state.index}"
    AnimatedContent(
        targetState = key to state.block,
        modifier = modifier,
        contentKey = { it.first },
        transitionSpec = {
            val spec = tween<Float>(220, easing = DS.Motion.easeOut)
            if (reduceMotion) fadeIn(spec) togetherWith fadeOut(spec)
            else (fadeIn(spec) + slideInHorizontally(tween(220, easing = DS.Motion.easeOut)) { shift }) togetherWith
                (fadeOut(spec) + slideOutHorizontally(tween(220, easing = DS.Motion.easeOut)) { shift })
        },
        label = "lyric",
    ) { (_, block) ->
        if (block == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("This hymn has no text yet.", style = DS.Type.sheetTitle.copy(fontStyle = FontStyle.Italic), color = p.secondary)
            }
            return@AnimatedContent
        }
        val isChorus = block is Block.Chorus
        val size = (lyricSize / fontScale).sp
        val description = "${if (isChorus) "Chorus" else state.position}. ${block.lines.joinToString(" ")}"
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val measure = minOf(maxWidth - DS.Space.gutter * 2, DS.Space.readingMeasure)
            Box(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .windowInsetsPadding(WindowInsets.safeDrawing)
                    .padding(top = topInset, bottom = bottomInset, start = DS.Space.gutter, end = DS.Space.gutter),
                contentAlignment = Alignment.TopCenter,
            ) {
                Row(
                    Modifier
                        .widthIn(max = measure)
                        .fillMaxWidth()
                        .height(IntrinsicSize.Min)
                        .semantics(mergeDescendants = true) {
                            contentDescription = description
                            liveRegion = LiveRegionMode.Polite
                        },
                ) {
                    if (isChorus) {
                        ChorusRule(DS.Palette.brassOnDark, Modifier.width(3.dp).fillMaxHeight())
                        Spacer(Modifier.width(DS.Space.l - 3.dp))
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
                        if (isChorus) Eyebrow(state.chorusLabel, DS.Palette.brassOnDark, tracking = 2f)
                        Text(
                            block.lines.joinToString("\n"),
                            style = if (isChorus) TextStyle(
                                fontFamily = DS.Chorus.family(ReadingFont.Serif), fontWeight = DS.Chorus.weight, fontStyle = DS.Chorus.style,
                                fontSize = size * DS.Chorus.sizeRatio(ReadingFont.Serif), lineHeight = (1.2f + 0.18f * 0.6f).em,
                            ) else TextStyle(
                                fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = size,
                                lineHeight = (1.2f + 0.18f * 0.6f).em,
                            ),
                            color = p.highContrastForeground,
                        )
                    }
                }
            }
        }
    }
}

/**
 * Horizontal swipes (past 50 dp) turn verses; two fingers size the text
 * between the worship pinch limits, with the limit haptic at either end.
 * Both claim their touches first, so the verse's own scroll and the taps
 * don't also act on them.
 */
private fun Modifier.lyricGestures(
    base: () -> Float,
    onPinch: (Float) -> Unit,
    onPinchEnd: (Float?) -> Unit,
    onSwipe: (forward: Boolean) -> Unit,
): Modifier = pointerInput(Unit) {
    val range = LyricScale.Worship.pinchRange
    val slop = viewConfiguration.touchSlop
    awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        var pinching = false
        var start = 0f
        var scale = 1f
        var live: Float? = null
        var atLimit = false
        var dx = 0f
        var dy = 0f
        var horizontal = false
        do {
            val event = awaitPointerEvent(PointerEventPass.Initial)
            if (event.changes.count { it.pressed } >= 2) {
                if (!pinching) { pinching = true; start = base() }
                scale *= event.calculateZoom()
                val raw = start * scale
                val limited = raw < range.start || raw > range.endInclusive
                if (limited && !atLimit) Haptics.play(HapticEvent.Limit)
                atLimit = limited
                val clamped = raw.coerceIn(range)
                live = clamped
                onPinch(clamped)
                event.changes.forEach { it.consume() }
            } else if (!pinching) {
                val change = event.changes.first()
                val delta = change.positionChange()
                dx += delta.x
                dy += delta.y
                if (!horizontal && abs(dx) > slop && abs(dx) > abs(dy)) horizontal = true
                if (horizontal) change.consume()
            } else {
                event.changes.forEach { it.consume() }
            }
        } while (event.changes.any { it.pressed })
        if (pinching) onPinchEnd(live)
        else if (horizontal && abs(dx) > 50.dp.toPx()) onSwipe(dx < 0)
    }
}

/**
 * "Hymn N in…" and every hymnal as colour tiles (TranslationSwitcher, as
 * church mode's globe shows it): one tap switches and keeps the hymn.
 */
@Composable
private fun ChurchTranslations(
    catalogue: List<HymnalInfo>,
    current: HymnalInfo?,
    number: Int?,
    numberIn: (HymnalInfo) -> Int?,
    onSelect: (HymnalInfo) -> Unit,
) {
    val p = LocalSurface.current
    Column(Modifier.width(320.dp), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Eyebrow(if (number != null) "Hymn $number in…" else "Hymnals", p.secondary,
            Modifier.padding(start = DS.Space.panel, end = DS.Space.panel, top = DS.Space.panel))
        Box(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
            LanguageTileGrid(
                catalogue.map { DSHymnal(it.id, it.name, it.language, isOwnBook = it.isOwnBook) },
                Modifier.padding(start = DS.Space.panel - 5.dp, end = DS.Space.panel - 5.dp, bottom = DS.Space.xs),
            ) { hymnal, modifier ->
                val info = catalogue.first { it.id == hymnal.id }
                LanguageTile(
                    hymnal,
                    if (info.id == current?.id) DSHymnalAccess.Current else DSHymnalAccess.Owned,
                    onClick = { if (info.id != current?.id) onSelect(info) },
                    modifier = modifier,
                    detail = detail(info, current, number, numberIn),
                    switchHint = "Shows this hymn in ${if (hymnal.isOwnBook) hymnal.name else hymnal.language}",
                )
            }
        }
    }
}

/** Null shows the hymnal's title. Across numberings: where the hymn is, or that it isn't there. */
private fun detail(info: HymnalInfo, current: HymnalInfo?, number: Int?, numberIn: (HymnalInfo) -> Int?): String? {
    if (current == null || number == null || info.id == current.id) return null
    if (info.numbering == current.numbering) {
        return if (number <= info.maxNumber) null else "No hymn $number · opens the first hymn"
    }
    val there = numberIn(info) ?: return "${info.name} · not in this hymnal"
    return "${info.name} · hymn $there"
}

/** Calls [onChange] when [value] changes (not on the first composition). */
@Composable
private fun OnChange(value: Boolean, onChange: (Boolean) -> Unit) {
    val first = remember { booleanArrayOf(true) }
    LaunchedEffect(value) { if (first[0]) first[0] = false else onChange(value) }
}

/** Disables auto-lock while church mode is up (`dsKeepsScreenAwake`). */
@Composable
private fun KeepsScreenAwake() {
    val view = LocalView.current
    DisposableEffect(view) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
}

/** No status or navigation bar over the words; a swipe from the edge shows them for a moment. */
@Composable
private fun HidesSystemBars() {
    val view = LocalView.current
    DisposableEffect(view) {
        val window = view.context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller?.hide(WindowInsetsCompat.Type.systemBars())
        onDispose { controller?.show(WindowInsetsCompat.Type.systemBars()) }
    }
}

/** TalkBack (touch exploration) is on: the controls never hide. */
@Composable
private fun rememberTalkBack(): Boolean {
    val context = LocalContext.current
    val manager = remember { context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager }
    var on by remember { mutableStateOf(manager?.isTouchExplorationEnabled == true) }
    DisposableEffect(manager) {
        val listener = AccessibilityManager.TouchExplorationStateChangeListener { on = it }
        manager?.addTouchExplorationStateChangeListener(listener)
        onDispose { manager?.removeTouchExplorationStateChangeListener(listener) }
    }
    return on
}
