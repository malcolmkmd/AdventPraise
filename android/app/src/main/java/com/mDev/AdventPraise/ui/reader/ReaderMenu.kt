// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Contrast
import androidx.compose.material.icons.rounded.FormatSize
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.reader.ReaderMenuPanel
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.ui.design.OnGlass
import com.mDev.AdventPraise.ui.design.dsGlass
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/*
 * The reader menu (ReaderMenu.swift): the globe at the top of the reader grows
 * into a glass bar holding the hymn's settings, and its panels unfold downward
 * out of the bar, as the Lectern's unfold upward at the bottom.
 *
 *          [ 🌐 English | ◐ Theme | Aa Text | ⓘ About ]   [ ✕ ]
 *          ┌──────────────── panel ────────────────┐
 *
 * The bar is laid out where it opens; one animated shape goes from the globe's
 * circle to the bar on the Lectern's spring and clips it, so the glass uncovers
 * the bar from the globe outward and the close button lands where the globe
 * was. Beside the globe, the same size and glass, the sheet music button (only
 * when the hymn has sheet music, hidden while the menu is open).
 */

/** The bar's height (MenuGeometry.rowHeight). */
private val MenuRowHeight = 52.dp
/** The globe's circle. */
private val ChipSize = DS.Size.hitTarget
/** The globe sits this far inside the bar's top trailing corner. */
private val ChipInset = (MenuRowHeight - ChipSize) / 2
/** Clear of the reader's leading edge. */
private val MenuMargin = 12.dp
/** What the menu leaves visible below it: a look at the lyrics and the Lectern. */
private val MenuBottomClearance = 132.dp

/** Where the globe's sheet music neighbour shows (ReaderMenuOverlay). */
object ReaderMenuRules {
    /** Only while the hymn has sheet music in this hymnal, and the menu is closed. */
    fun showsSheetMusicButton(hasSheetMusic: Boolean, isMenuOpen: Boolean): Boolean = hasSheetMusic && !isMenuOpen
}

/** Opens the full-screen sheet music viewer (which gates the full page on Pro). */
fun ReaderModel.openSheetMusic(navigator: AppNavigator) {
    if (!hasSheetMusic) return
    closeLectern()
    navigator.openSheetMusic("reader_menu")
}

/** The globe, the sheet music button beside it, and the menu the globe opens, over the reader. */
@Composable
fun ReaderMenu(services: AppServices, focusAlpha: Float) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val open = model.isMenuOpen
    val progress by animateFloatAsState(if (open) 1f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "menu-morph")
    // The globe goes with the rest of the chrome in focus mode.
    if (focusAlpha <= 0f) return
    BoxWithConstraints(Modifier.fillMaxSize().graphicsLayer { alpha = focusAlpha }) {
        val top = statusBarTop()
        val chipRight = maxWidth - ReaderBarMargin
        val trailing = chipRight + ChipInset
        val barWidth = minOf(DS.Space.lecternMaxWidth, trailing - MenuMargin).coerceAtLeast(ChipSize)
        val barX = trailing - barWidth
        val barY = top
        val panelMaxHeight = (maxHeight - (barY + MenuRowHeight) - MenuBottomClearance).coerceAtLeast(180.dp)

        // A light dim that closes the menu when tapped. The lyrics stay readable
        // beneath it, so Theme and Text changes can be judged as they're made.
        AnimatedVisibility(open, enter = fadeIn(), exit = fadeOut()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = if (p.isDark) 0.24f else 0.07f))
                    .clickable(remember { MutableInteractionSource() }, null) { model.closeMenu() }
                    .clearAndSetSemantics { },
            )
        }
        AnimatedVisibility(
            ReaderMenuRules.showsSheetMusicButton(model.hasSheetMusic, open),
            enter = fadeIn(), exit = fadeOut(),
            modifier = Modifier.offset(chipRight - ChipSize - DS.Space.s - ChipSize, top + ChipInset),
        ) {
            SheetMusicButton { model.openSheetMusic(navigator) }
        }
        val shape = MenuMorphShape(progress, ChipSize, ChipInset)
        Box(
            Modifier
                .offset(barX, barY)
                .width(barWidth)
                .dsGlass(shape, DS.GlassDepth.Capsule),
        ) {
            OnGlass {
                if (open || progress > 0f) {
                    Box(Modifier.graphicsLayer { alpha = if (reduceMotion) (if (open) 1f else 0f) else progress }) {
                        ReaderMenuBar(services, panelMaxHeight, reduceMotion, enabled = open)
                    }
                }
                if (!open || progress < 1f) {
                    Globe(
                        model,
                        Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = ChipInset, end = ChipInset)
                            .graphicsLayer { alpha = 1f - progress },
                        enabled = !open,
                    )
                }
            }
        }
    }
}

/**
 * The globe's circle at `progress` 0, the whole bar (and its panel) at 1. The
 * closed circle sits `inset` inside the top trailing corner; corners go from
 * the circle's radius to the row's.
 */
@Immutable
private data class MenuMorphShape(val progress: Float, val closedSize: Dp, val inset: Dp) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline = with(density) {
        val closed = closedSize.toPx()
        val i = inset.toPx()
        fun mix(a: Float, b: Float) = a + (b - a) * progress
        val left = mix(size.width - i - closed, 0f)
        val top = mix(i, 0f)
        val width = mix(closed, size.width)
        val height = mix(closed, size.height)
        val radius = mix(closed / 2, MenuRowHeight.toPx() / 2)
        Outline.Rounded(RoundRect(left, top, left + width, top + height, CornerRadius(radius)))
    }
}

@Composable
private fun Globe(model: ReaderModel, modifier: Modifier, enabled: Boolean) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val info = model.hymnalInfo
    Box(
        modifier
            .size(ChipSize)
            .dsPress(interaction)
            .clip(CircleShape)
            .clickable(interaction, null, enabled = enabled, role = Role.Button) { model.openMenu() }
            .clearAndSetSemantics {
                if (enabled) {
                    contentDescription = "Reading options"
                    stateDescription = info?.let { "${it.language}, ${it.name}" } ?: ""
                    role = Role.Button
                }
            },
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.Rounded.Language, null, tint = p.foreground, modifier = Modifier.size(22.dp)) }
}

/** Sheet music, beside the globe and like it: the same size and glass. */
@Composable
private fun SheetMusicButton(onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    Box(
        Modifier
            .size(ChipSize)
            .dsPress(interaction)
            .dsGlass(CircleShape, DS.GlassDepth.Capsule)
            .clickable(interaction, null, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Sheet music. Shows this hymn’s sheet music"
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.foreground, modifier = Modifier.size(22.dp)) }
}

/** The open menu: the row of tabs and a close button, and the open tab's panel unfolding beneath it. */
@Composable
private fun ReaderMenuBar(services: AppServices, panelMaxHeight: Dp, reduceMotion: Boolean, enabled: Boolean) {
    val model = services.reader
    val p = LocalSurface.current
    val panel = model.menuPanel
    val divider by animateFloatAsState(if (panel == null) 0f else 0.6f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "menu-divider")
    val fade = DS.Motion.adaptive(DS.Motion.lectern<Float>(), reduceMotion) as FiniteAnimationSpec<Float>
    val slide = DS.Motion.adaptive(DS.Motion.lectern<IntOffset>(), reduceMotion) as FiniteAnimationSpec<IntOffset>
    val resize = DS.Motion.adaptive(DS.Motion.lectern<IntSize>(), reduceMotion) as FiniteAnimationSpec<IntSize>
    Column(Modifier.fillMaxWidth().then(if (enabled) Modifier else Modifier.clearAndSetSemantics { })) {
        MenuRow(model, reduceMotion, enabled)
        Box(Modifier.fillMaxWidth().height(1.dp).graphicsLayer { alpha = divider }.background(p.primary(DS.Fill.stroke)))
        // Panels unfold from the row: out of its lower edge, fading, while the
        // glass grows around them. The slot clips, so a panel never crosses the row.
        AnimatedContent(
            targetState = panel,
            transitionSpec = {
                val enter = if (reduceMotion) fadeIn(fade) else fadeIn(fade) + slideInVertically(slide) { -it / 3 }
                val exit = if (reduceMotion) fadeOut(fade) else fadeOut(fade) + slideOutVertically(slide) { -it / 3 }
                (enter togetherWith exit).using(SizeTransform(clip = true) { _, _ -> resize })
            },
            label = "menu-panel",
        ) { shown ->
            if (shown != null) ReaderMenuPanelContent(services, shown, panelMaxHeight) else Box(Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun MenuRow(model: ReaderModel, reduceMotion: Boolean, enabled: Boolean) {
    val p = LocalSurface.current
    val info = model.hymnalInfo
    val tabs = listOf(
        MenuTabSpec(ReaderMenuPanel.Translation, info?.shortLabel ?: "Translation", Icons.Rounded.Language, "Translation",
            info?.let { "${it.language}, ${it.name}" }),
        MenuTabSpec(ReaderMenuPanel.Theme, "Theme", Icons.Rounded.Contrast, "Theme", null),
        MenuTabSpec(ReaderMenuPanel.Text, "Text", Icons.Rounded.FormatSize, "Text size and font", null),
        MenuTabSpec(ReaderMenuPanel.About, "About", Icons.Outlined.Info, "About this hymn", null),
    )
    Row(
        Modifier
            .fillMaxWidth()
            .height(MenuRowHeight)
            .padding(start = DS.Space.xs, end = (MenuRowHeight - DS.Size.hitTarget) / 2),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs),
    ) {
        BoxWithConstraints(Modifier.weight(1f)) {
            val spacing = DS.Space.xxs
            val tabWidth = (maxWidth - spacing * (tabs.size - 1)) / tabs.size
            // The open tab's highlight slides between tabs; under Reduce Motion it fades in place.
            val index = tabs.indexOfFirst { it.panel == model.menuPanel }
            var last by remember { mutableIntStateOf(0) }
            if (index >= 0 && index != last) last = index
            val x by animateDpAsState((tabWidth + spacing) * last, if (reduceMotion) snap() else DS.Motion.lectern(), label = "tab-wash")
            val washAlpha by animateFloatAsState(if (index >= 0) 1f else 0f, DS.Motion.adaptive(DS.Motion.lectern(), reduceMotion), label = "tab-wash-a")
            Box(
                Modifier
                    .offset(x = x)
                    .width(tabWidth)
                    .heightIn(min = DS.Size.hitTarget)
                    .align(Alignment.CenterStart)
                    .graphicsLayer { alpha = washAlpha }
                    .background(p.tint.copy(alpha = DS.Fill.tintOn), dsShape(DS.Radius.key)),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.CenterVertically) {
                tabs.forEach { tab ->
                    MenuTab(tab, isOn = model.menuPanel == tab.panel, enabled = enabled, modifier = Modifier.width(tabWidth)) {
                        model.toggleMenuPanel(tab.panel)
                    }
                }
            }
        }
        // Where the globe was, so the same spot opens and closes the menu.
        val interaction = remember { MutableInteractionSource() }
        Box(
            Modifier
                .size(DS.Size.hitTarget)
                .dsPress(interaction)
                .clip(CircleShape)
                .background(p.primary(DS.Fill.inset))
                .clickable(interaction, null, enabled = enabled, role = Role.Button) { model.closeMenu() }
                .clearAndSetSemantics { contentDescription = "Close. Closes reading options"; role = Role.Button },
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Rounded.Close, null, tint = p.foreground, modifier = Modifier.size(20.dp)) }
    }
}

private data class MenuTabSpec(val panel: ReaderMenuPanel, val caption: String, val icon: ImageVector, val spoken: String, val value: String?)

/** A tab: its glyph over a short caption; the tint wash shows while its panel does. */
@Composable
private fun MenuTab(tab: MenuTabSpec, isOn: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val color = if (isOn) p.tint else p.foreground
    val fontScale = LocalDensity.current.fontScale
    // The bar is a fixed 52 dp; the captions stop growing before they'd need more.
    val caption = 11f * minOf(fontScale, 1.3f) / fontScale
    Column(
        modifier
            .heightIn(min = DS.Size.hitTarget)
            .dsPress(interaction)
            .clip(dsShape(DS.Radius.key))
            .clickable(interaction, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = tab.spoken
                tab.value?.let { stateDescription = it }
                role = Role.Button
                selected = isOn
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.hair, Alignment.CenterVertically),
    ) {
        Box(Modifier.height(22.dp), contentAlignment = Alignment.Center) { Icon(tab.icon, null, tint = color, modifier = Modifier.size(20.dp)) }
        Text(
            tab.caption,
            style = DS.Type.caption.copy(fontSize = caption.sp, lineHeight = (caption * 1.2f).sp, fontWeight = FontWeight.SemiBold),
            color = color, maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
    }
}
