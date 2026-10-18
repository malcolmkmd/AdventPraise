// OWNER: music
package com.mDev.AdventPraise.ui.sheetmusic

import android.view.accessibility.AccessibilityManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsIgnoringVisibility
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsIgnoringVisibility
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.accompanimentPasses
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.HymnOfTheDayPicker
import com.mDev.AdventPraise.data.SheetMusicLayout
import com.mDev.AdventPraise.data.SheetMusicViewMode
import com.mDev.AdventPraise.extras.SheetMusicAccess
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.GlassButtonKind
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate

/**
 * The open hymn's sheet music on the whole screen (SheetMusicView). The page
 * is vector: the phone width in portrait, the pad width once the music has
 * 700 dp. It is inked in the reading surface's text colour. Pinch or
 * double-tap to zoom; a tap hides the controls and the system bars for the
 * music alone, and another brings them back.
 *
 * Page | System (remembered): System shows one line of music at a time, as
 * large as fits, with swipes and arrows to the next or previous line and
 * "System 3 of 8".
 *
 * While the accompaniment plays this hymn the page follows it: the measure,
 * the melody note and the syllable being sung are marked, the page scrolls
 * (or the system advances) to keep them in view, and a tap on a measure
 * plays from there. That needs the player unlocked (Pro or MIDI Piano).
 *
 * Sheet music is Pro; Hymn of the Day's is free. Anyone else sees the top of
 * the page fading out, with a Pro button pinned to the bottom of the screen.
 */
@Composable
fun SheetMusicScreen(services: AppServices, navigator: AppNavigator, source: String, onClose: () -> Unit) {
    val hymnal = services.reader.hymnal ?: return
    val hymn = services.reader.hymn ?: return
    val player = services.player
    val store = services.store
    val isHymnOfTheDay = remember(hymnal.id, hymn.number) {
        hymnal.hymns.isNotEmpty() && hymnal.hymns[HymnOfTheDayPicker.index(LocalDate.now(), hymnal.hymns.size)].number == hymn.number
    }
    val access = SheetMusicAccess.resolve(store.unlocks(ProFeature.SheetMusic), isHymnOfTheDay)
    val canPlay = hymn.hasAccompaniment && player.isAvailable
    val model = remember(hymnal.id, hymn.number) {
        SheetMusicModel(AccompanimentState.key(hymnal.id, hymn.number), access, hymn.accompanimentPasses,
            store.isPlayerUnlocked, canPlay, services.appSettings.sheetMusicViewMode)
    }
    model.access = access
    model.playerUnlocked = store.isPlayerUnlocked
    model.canPlay = canPlay
    model.viewMode = services.appSettings.sheetMusicViewMode

    val pages = remember(hymnal.id, hymn.number) { mutableStateMapOf<Pair<SheetMusicLayout, ReadingSurface>, SheetMusicArt>() }
    val unreadable = remember(hymnal.id, hymn.number) { mutableStateMapOf<SheetMusicLayout, Boolean>() }
    val surface = services.settings.surface
    val status = player.status

    LaunchedEffect(model) {
        model.timing = withContext(Dispatchers.Default) { services.catalogs.sheetMusic.timing(hymnal.id, hymn.number) }
        model.follow(player.status)
    }
    // System by system follows the accompaniment from line to line.
    val cueMeasure = model.cueMeasure(status)
    LaunchedEffect(cueMeasure) { if (cueMeasure != null) model.systemMeasure = cueMeasure }
    LaunchedEffect(Unit) {
        Analytics.screen(AnalyticsScreen.SheetMusic)
        Analytics.track(AnalyticsEvent.SheetMusicOpened(hymn.number, access))
    }

    val context = LocalContext.current
    val screenReader = remember {
        (context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager)?.isTouchExplorationEnabled == true
    }
    SystemBarsHidden(!model.showsControls(screenReader))

    SheetMusicContent(
        model = model,
        status = status,
        surface = surface,
        hymnNumber = hymn.number,
        hymnTitle = hymn.title,
        proCount = remember(hymnal.id) { services.catalogs.sheetMusic.count(hymnal.id, hymnal.info.maxNumber) },
        isPlayingHere = player.isPlaying && player.isHymn(hymnal.id, hymn),
        screenReader = screenReader,
        art = { layout -> pages[layout to surface] },
        isUnreadable = { layout -> unreadable[layout] == true },
        onNeedPage = { layout ->
            if (pages[layout to surface] == null && unreadable[layout] != true) {
                val art = withContext(Dispatchers.Default) {
                    services.catalogs.sheetMusic.page(hymnal.id, hymn.number, layout)?.let { SheetMusicArt.render(it, surface.sheetMusicInk()) }
                }
                if (art != null) pages[layout to surface] = art else unreadable[layout] = true
            }
        },
        onClose = onClose,
        onMode = { mode ->
            services.appSettings.updateSheetMusicViewMode(mode)
            model.viewMode = mode
            Haptics.play(HapticEvent.Selection)
        },
        onTogglePlay = {
            if (player.isHymn(hymnal.id, hymn) && player.isActive) player.toggle() else player.start(hymn, hymnal.info)
        },
        onSeek = { ms -> player.seek(ms / 1000.0) },
        onPro = {
            Analytics.track(AnalyticsEvent.SheetMusicPaywallOpened(hymn.number))
            navigator.openPaywall(ProFeature.SheetMusic, "sheet_music")
        },
    )
}

/** Hides the status and navigation bars while `hidden` (a swipe from the edge shows them for a moment). */
@Composable
private fun SystemBarsHidden(hidden: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    DisposableEffect(hidden) {
        val window = view.context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (hidden) controller?.hide(WindowInsetsCompat.Type.systemBars()) else controller?.show(WindowInsetsCompat.Type.systemBars())
        onDispose { controller?.show(WindowInsetsCompat.Type.systemBars()) }
    }
}

/** The close button's row. */
private val BarHeight = 56.dp
/** Room under the music for "System 3 of 8". */
private val SystemFooter = 64.dp

/**
 * The viewer from its state (also the screenshot tests'): the top bar, the
 * page or the system, the system controls, or the preview with its Pro bar.
 * [onNeedPage] loads a layout's page (it runs in a coroutine).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SheetMusicContent(
    model: SheetMusicModel,
    status: AccompanimentState,
    surface: ReadingSurface,
    hymnNumber: Int,
    hymnTitle: String,
    proCount: Int,
    isPlayingHere: Boolean,
    screenReader: Boolean,
    art: (SheetMusicLayout) -> SheetMusicArt?,
    isUnreadable: (SheetMusicLayout) -> Boolean,
    onNeedPage: suspend (SheetMusicLayout) -> Unit,
    onClose: () -> Unit,
    onMode: (SheetMusicViewMode) -> Unit,
    onTogglePlay: () -> Unit,
    onSeek: (Long) -> Unit,
    onPro: () -> Unit,
) {
    val p = LocalSurface.current
    val density = LocalDensity.current
    val accent = surface.sheetMusicAccent()
    val topInset = with(density) { WindowInsets.statusBarsIgnoringVisibility.getTop(this).toDp() }
    val bottomInset = with(density) { WindowInsets.navigationBarsIgnoringVisibility.getBottom(this).toDp() }
    val showsControls = model.showsControls(screenReader)
    BoxWithConstraints(Modifier.fillMaxSize().background(p.background)) {
        val width = maxWidth
        val height = maxHeight
        val narrow = width < 520.dp
        val bar = if (narrow) BarHeight + 22.dp else BarHeight
        val layout = model.pageLayout(width.value.toDouble())
        LaunchedEffect(layout, surface) { onNeedPage(layout) }
        val page = art(layout)
        when {
            page != null && model.access.showsWholePage -> {
                val highlight = model.highlight(layout, status)
                val following = model.following(status)
                if (model.systemMode) {
                    SheetSystemView(
                        art = page,
                        geometry = model.timing?.geometry?.get(layout),
                        systemIndex = model.systemIndex(layout),
                        top = topInset + if (showsControls) bar else DS.Space.l,
                        bottom = bottomInset + if (showsControls) SystemFooter else DS.Space.l,
                        highlight = highlight,
                        accent = accent,
                        description = "Sheet music for hymn $hymnNumber, $hymnTitle",
                        onTap = { point -> tap(model, point, layout, status, onSeek) },
                        onSwipe = { step -> model.goToSystem(model.systemIndex(layout) + step, layout) },
                    )
                    AnimatedVisibility(showsControls, enter = fadeIn(DS.Motion.quick()), exit = fadeOut(DS.Motion.quick()),
                        modifier = Modifier.align(Alignment.BottomCenter)) {
                        SystemControls(model, layout, Modifier.padding(bottom = bottomInset + DS.Space.s))
                    }
                } else {
                    SheetPageView(
                        art = page,
                        topInset = topInset + bar,
                        bottomInset = bottomInset + DS.Space.l,
                        highlight = highlight,
                        follows = following && status.isPlaying,
                        accent = accent,
                        description = "Sheet music for hymn $hymnNumber, $hymnTitle",
                        onTap = { point -> tap(model, point, layout, status, onSeek) },
                    )
                }
            }
            page != null -> {
                // The top of the page fades out; the Pro button stays pinned to the
                // bottom of the screen, over the faded music, in Page and System alike.
                Column(Modifier.fillMaxSize()) {
                    Spacer(Modifier.height(topInset + bar))
                    val geometry = model.timing?.geometry?.get(layout)
                    val system = if (model.systemMode) previewSystemFrame(page, geometry, width.value.toDouble()) else null
                    if (system != null) {
                        SheetPreview(page, Modifier.fillMaxWidth().height(minOf(system.second.dp, height * 0.7f)), system.first,
                            "Sheet music for hymn $hymnNumber, $hymnTitle")
                    } else {
                        val shown = width * (page.height / maxOf(page.width, 1.0)).toFloat() * SheetMusicAccess.PREVIEW_FRACTION.toFloat() + 32.dp
                        SheetPreview(page, Modifier.fillMaxWidth().height(minOf(shown, height * 0.7f)), null,
                            "Sheet music for hymn $hymnNumber, $hymnTitle")
                    }
                }
                ProBar(proCount, onPro, Modifier.align(Alignment.BottomCenter), bottomInset)
            }
            isUnreadable(layout) -> Column(
                Modifier.fillMaxSize().padding(DS.Space.l),
                verticalArrangement = Arrangement.spacedBy(DS.Space.s, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = p.secondary, modifier = Modifier.size(44.dp))
                Text("No sheet music", style = DS.Type.panelTitle, color = p.foreground)
                Text("This hymn’s sheet music couldn’t be opened.", style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
            }
            else -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = p.tint)
        }
        AnimatedVisibility(showsControls, enter = fadeIn(DS.Motion.quick()), exit = fadeOut(DS.Motion.quick())) {
            TopBar(
                narrow = narrow,
                topInset = topInset,
                title = "$hymnNumber · $hymnTitle",
                hymnOfTheDay = model.access == SheetMusicAccess.HymnOfTheDay,
                viewMode = model.viewMode,
                canFollow = model.canFollow,
                isPlayingHere = isPlayingHere,
                onClose = onClose,
                onMode = onMode,
                onTogglePlay = onTogglePlay,
            )
        }
    }
}

private fun tap(model: SheetMusicModel, point: Pair<Double, Double>?, layout: SheetMusicLayout, status: AccompanimentState, onSeek: (Long) -> Unit) {
    when (val result = model.tapped(point, layout, status)) {
        is SheetMusicModel.Tap.Seek -> { onSeek(result.ms); Haptics.play(HapticEvent.LightImpact) }
        SheetMusicModel.Tap.ToggleControls -> Unit
    }
}

/** A preview, system by system: the first system, the next fading into the Pro button. */
private fun previewSystemFrame(
    art: SheetMusicArt,
    geometry: com.mDev.AdventPraise.data.SheetMusicTiming.Geometry?,
    width: Double,
): Pair<com.mDev.AdventPraise.data.SheetMusicSystemFrame, Double>? {
    val g = geometry ?: return null
    val first = g.systems.firstOrNull() ?: return null
    val (extentX, extentWidth) = g.systemExtent
    if (extentWidth <= 0) return null
    var band = first
    if (g.systems.size > 1) {
        val next = g.systems[1]
        val left = minOf(first.x, next.x)
        band = com.mDev.AdventPraise.data.SheetMusicTiming.Box(left, first.y,
            maxOf(first.x + first.width, next.x + next.width) - left, next.y + next.height * 0.7 - first.y)
    }
    val height = band.height * width / extentWidth
    val frame = com.mDev.AdventPraise.data.SheetMusicSystemFrame.fit(band, extentX, extentWidth, art.width, art.height,
        0.0, 0.0, width, height) ?: return null
    return frame to height
}

// MARK: - Bars

@Composable
private fun TopBar(
    narrow: Boolean,
    topInset: Dp,
    title: String,
    hymnOfTheDay: Boolean,
    viewMode: SheetMusicViewMode,
    canFollow: Boolean,
    isPlayingHere: Boolean,
    onClose: () -> Unit,
    onMode: (SheetMusicViewMode) -> Unit,
    onTogglePlay: () -> Unit,
) {
    val p = LocalSurface.current
    Column(
        Modifier
            .fillMaxWidth()
            // The music scrolls under the controls, fading out behind them.
            .background(Brush.verticalGradient(
                0f to p.background, 0.7f to p.background.copy(alpha = 0.92f), 1f to p.background.copy(alpha = 0f),
            ))
            .padding(top = topInset)
            .padding(horizontal = DS.Space.l)
            .padding(bottom = DS.Space.m),
    ) {
        Row(Modifier.fillMaxWidth().height(BarHeight), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            GlassButton("Close", onClose, icon = Icons.Rounded.Close, kind = GlassButtonKind.Icon)
            if (narrow) {
                Spacer(Modifier.weight(1f))
                ModePicker(viewMode, onMode)
                Spacer(Modifier.weight(1f))
            } else {
                Box(Modifier.weight(1f)) { TitleBlock(title, hymnOfTheDay) }
                ModePicker(viewMode, onMode)
            }
            if (canFollow) {
                GlassButton(if (isPlayingHere) "Pause" else "Play", onTogglePlay,
                    icon = if (isPlayingHere) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, kind = GlassButtonKind.Icon)
            } else if (narrow) {
                // Keeps the picker centred.
                Spacer(Modifier.width(DS.Size.hitTarget))
            }
        }
        if (narrow) Box(Modifier.height(22.dp)) { TitleBlock(title, hymnOfTheDay) }
    }
}

@Composable
private fun TitleBlock(title: String, hymnOfTheDay: Boolean) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(title, style = DS.Type.detail.copy(fontWeight = FontWeight.SemiBold), color = p.foreground,
            maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (hymnOfTheDay) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.WbSunny, contentDescription = null, tint = p.secondary, modifier = Modifier.size(12.dp))
                Text("Hymn of the Day: free for everyone today", style = DS.Type.caption, color = p.secondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** Page | System, a segmented control. */
@Composable
private fun ModePicker(mode: SheetMusicViewMode, onMode: (SheetMusicViewMode) -> Unit) {
    val p = LocalSurface.current
    val shape = RoundedCornerShape(9.dp)
    Row(
        Modifier.clip(shape).background(p.primary(DS.Fill.stroke * 0.8f), shape).padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        for (option in SheetMusicViewMode.entries) {
            val on = option == mode
            val segment = RoundedCornerShape(7.dp)
            Box(
                Modifier
                    .then(if (on) Modifier.shadow(1.dp, segment).background(p.elevated, segment) else Modifier)
                    .clip(segment)
                    .clickable(role = Role.Tab) { if (!on) onMode(option) }
                    .semantics { selected = on }
                    .widthIn(min = 64.dp)
                    .height(28.dp)
                    .padding(horizontal = DS.Space.m),
                contentAlignment = Alignment.Center,
            ) {
                Text(if (option == SheetMusicViewMode.Page) "Page" else "System",
                    style = DS.Type.detail.copy(fontWeight = if (on) FontWeight.SemiBold else FontWeight.Medium),
                    color = p.foreground)
            }
        }
    }
}

/** "‹  System 3 of 8  ›" under the music, leaving it the whole width. */
@Composable
private fun SystemControls(model: SheetMusicModel, layout: SheetMusicLayout, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val count = model.systemCount(layout)
    val index = model.systemIndex(layout)
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.l)) {
        GlassButton("Previous system", { model.goToSystem(index - 1, layout); Haptics.play(HapticEvent.Selection) },
            icon = Icons.Rounded.ChevronLeft, kind = GlassButtonKind.Icon, enabled = index > 0)
        Text("System ${index + 1} of $count", textAlign = TextAlign.Center, color = p.secondary,
            style = DS.Type.detail.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
            modifier = Modifier.widthIn(min = 110.dp))
        GlassButton("Next system", { model.goToSystem(index + 1, layout); Haptics.play(HapticEvent.Selection) },
            icon = Icons.Rounded.ChevronRight, kind = GlassButtonKind.Icon, enabled = index < count - 1)
    }
}

/** The preview's way to Pro, floating over the faded music, clear of the navigation bar. */
@Composable
private fun ProBar(count: Int, onPro: () -> Unit, modifier: Modifier, bottomInset: Dp) {
    val p = LocalSurface.current
    Box(
        modifier
            .fillMaxWidth()
            // The page colour rises behind it so the line above the button stays readable.
            .background(Brush.verticalGradient(
                0f to p.background.copy(alpha = 0f), 0.35f to p.background.copy(alpha = 0.92f), 1f to p.background,
            )),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Column(
            Modifier.widthIn(max = 560.dp).fillMaxWidth()
                .padding(horizontal = DS.Space.l).padding(top = DS.Space.gutter, bottom = DS.Space.l + bottomInset),
            verticalArrangement = Arrangement.spacedBy(DS.Space.s),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Sheet music for $count hymns comes with Pro. Hymn of the Day’s is free every day.",
                style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center)
            GlassButton("See the whole page with Pro", onPro, icon = Icons.AutoMirrored.Rounded.QueueMusic,
                tint = p.brass, fullWidth = true)
        }
    }
}
