package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Contrast
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.Numbering
import com.mDev.AdventPraise.reader.ReaderMenuPanel
import com.mDev.AdventPraise.settings.LineSpacing
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.rememberHaptic
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfacePalette

/**
 * The reader menu (ReaderMenu.swift): the globe at the top grows into a bar
 * of the hymn's settings, and its panels unfold downward: Translation (the
 * hymnals, keeping the hymn number), Theme (the reading surface) and Text
 * (size, print, font, spacing, alignment). Both preview live on the lyrics.
 */
@Composable
fun ReaderMenu(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val haptic = rememberHaptic(services.settings.haptics)
    Box(
        Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(horizontal = DS.Space.l, vertical = DS.Space.s),
        contentAlignment = Alignment.TopStart,
    ) {
        if (!model.isMenuOpen) {
            Surface(
                shape = CircleShape,
                color = p.elevated,
                shadowElevation = 6.dp,
                modifier = Modifier.size(DS.Size.hitTarget).border(1.dp, p.foreground.copy(alpha = DS.Fill.hairline), CircleShape),
            ) {
                Box(Modifier.clickable { haptic(); model.openMenu(ReaderMenuPanel.Translation) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Language, contentDescription = "Translation, theme and text", tint = p.foreground)
                }
            }
        } else {
            val shape = RoundedCornerShape(DS.Radius.panel)
            Surface(
                shape = shape,
                color = p.elevated,
                shadowElevation = 10.dp,
                modifier = Modifier.widthIn(max = DS.Space.lecternMaxWidth).fillMaxWidth()
                    .border(1.dp, p.foreground.copy(alpha = DS.Fill.hairline), shape),
            ) {
                Column {
                    Row(
                        Modifier.fillMaxWidth().padding(DS.Space.xs),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs),
                    ) {
                        Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                            MenuTab(Icons.Rounded.Language, model.hymnal?.info?.shortLabel ?: "Translation",
                                model.menuPanel == ReaderMenuPanel.Translation) { haptic(); model.toggleMenuPanel(ReaderMenuPanel.Translation) }
                            MenuTab(Icons.Rounded.Contrast, "Theme", model.menuPanel == ReaderMenuPanel.Theme) {
                                haptic(); model.toggleMenuPanel(ReaderMenuPanel.Theme)
                            }
                            MenuTab(Icons.Rounded.TextFields, "Text", model.menuPanel == ReaderMenuPanel.Text) {
                                haptic(); model.toggleMenuPanel(ReaderMenuPanel.Text)
                            }
                        }
                        Box(
                            Modifier.size(DS.Size.hitTarget).clip(CircleShape).clickable { haptic(); model.closeMenu() },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(Icons.Rounded.Close, contentDescription = "Close", tint = p.foreground)
                        }
                    }
                    AnimatedVisibility(
                        visible = model.menuPanel != null,
                        enter = expandVertically() + fadeIn(),
                        exit = shrinkVertically() + fadeOut(),
                    ) {
                        Box(Modifier.padding(start = DS.Space.panel, end = DS.Space.panel, bottom = DS.Space.panel)) {
                            when (model.menuPanel) {
                                ReaderMenuPanel.Translation -> TranslationPanel(services)
                                ReaderMenuPanel.Theme -> ThemePanel(services.settings)
                                ReaderMenuPanel.Text -> TextPanel(services.settings)
                                null -> Unit
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MenuTab(icon: ImageVector, label: String, selected: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .clip(RoundedCornerShape(DS.Radius.capsule))
            .background(if (selected) p.tint.copy(alpha = DS.Fill.tintSelected) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Space.m, vertical = DS.Space.s),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) p.tint else p.foreground, modifier = Modifier.size(18.dp))
        Text(label, style = DS.Type.label, color = if (selected) p.tint else p.foreground, maxLines = 1)
    }
}

// MARK: - Translation

@Composable
private fun TranslationPanel(services: AppServices) {
    val model = services.reader
    val p = LocalSurface.current
    val number = model.hymn?.number
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        if (number != null) Eyebrow("This hymn in…", p.secondary, Modifier.padding(start = DS.Space.xxs, bottom = DS.Space.xxs))
        LazyColumn(Modifier.heightIn(max = 380.dp), verticalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
            items(model.catalogue, key = { it.id }) { info ->
                val current = info.id == model.hymnal?.id
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(DS.Radius.tile))
                        .background(if (current) p.tint.copy(alpha = DS.Fill.tintSelected) else Color.Transparent)
                        .clickable {
                            model.switchHymnal(info)
                            model.closeMenu()
                        }
                        .padding(DS.Space.s),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
                ) {
                    Box(
                        Modifier.size(DS.Size.numberTile).clip(RoundedCornerShape(DS.Radius.badge))
                            .background(DS.languageColor(info.id, p.isDark)),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (info.numbering == Numbering.Sdah) {
                            Icon(Icons.AutoMirrored.Rounded.MenuBook, contentDescription = null, tint = p.languageInk, modifier = Modifier.size(20.dp))
                        } else {
                            Text(info.language.take(2), style = DS.Type.label, color = p.languageInk)
                        }
                    }
                    Column(Modifier.weight(1f)) {
                        Text(info.name, style = DS.Type.rowTitle, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        // Where the hymn is there: "hymn 368", or that it isn't there.
                        val there = if (current) number else model.numberIn(info)
                        val own = if (info.numbering == Numbering.Sdah) "Own numbering · " else ""
                        Text(
                            own + (there?.let { "${info.language} · hymn $it" } ?: "${info.language} · not in this hymnal"),
                            style = DS.Type.detail, color = p.secondary,
                        )
                    }
                    if (current) Icon(Icons.Rounded.Check, contentDescription = "Current", tint = p.tint)
                }
            }
        }
    }
}

// MARK: - Theme

@Composable
private fun ThemePanel(settings: ReadingSettings) {
    val p = LocalSurface.current
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        ReadingSurface.entries.forEach { surface ->
            val swatch = SurfacePalette.of(surface)
            val selected = settings.surface == surface
            Column(
                Modifier.clip(RoundedCornerShape(DS.Radius.tile)).clickable {
                    if (!selected) {
                        settings.updateSurface(surface)
                        Analytics.track(AnalyticsEvent.AppearanceChanged("surface", surface.key))
                        Analytics.setAppearance(surface.key, settings.largePrint)
                    }
                }.padding(DS.Space.xxs),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(DS.Space.xxs),
            ) {
                Box(
                    Modifier.size(DS.Size.hitTarget).clip(CircleShape).background(swatch.background)
                        .border(if (selected) 3.dp else 1.dp, if (selected) p.tint else p.controlBorder, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("Aa", fontFamily = FontFamily.Serif, fontSize = 15.sp, color = swatch.foreground)
                }
                Text(surface.label, style = DS.Type.caption, color = if (selected) p.tint else p.secondary)
            }
        }
    }
}

// MARK: - Text

@Composable
private fun TextPanel(settings: ReadingSettings) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            SizeButton("A−", enabled = settings.step > 0) { setStep(settings, settings.step - 1, "slider") }
            Slider(
                value = settings.step.toFloat(),
                onValueChange = { v -> if (v.toInt() != settings.step) setStep(settings, v.toInt(), "slider") },
                valueRange = 0f..4f,
                steps = 3,
                modifier = Modifier.weight(1f),
            )
            SizeButton("A+", enabled = settings.step < 4) { setStep(settings, settings.step + 1, "slider") }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Large print", style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
            Switch(checked = settings.largePrint, onCheckedChange = {
                settings.updateLargePrint(it)
                Analytics.track(AnalyticsEvent.AppearanceChanged("large_print", if (it) "on" else "off"))
                Analytics.setAppearance(settings.surface.key, it)
            })
        }
        ChoiceRow("Font", ReadingFont.entries, settings.font, { it.label }) {
            settings.updateFont(it)
            Analytics.track(AnalyticsEvent.AppearanceChanged("font", it.key))
        }
        ChoiceRow("Spacing", LineSpacing.entries, settings.lineSpacing, { it.label }) {
            settings.updateLineSpacing(it)
            Analytics.track(AnalyticsEvent.AppearanceChanged("line_spacing", it.key))
        }
        ChoiceRow("Align", listOf(false, true), settings.centered, { if (it) "Centred" else "Left" }) {
            settings.updateCentered(it)
            Analytics.track(AnalyticsEvent.AppearanceChanged("alignment", if (it) "centered" else "leading"))
        }
    }
}

private fun setStep(settings: ReadingSettings, step: Int, method: String) {
    val next = step.coerceIn(0, 4)
    if (next == settings.step) return
    settings.updateStep(next)
    Analytics.track(AnalyticsEvent.TextSizeChanged("reader", method, settings.pointSize.toInt()))
}

@Composable
private fun SizeButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier.size(DS.Size.hitTarget).clip(CircleShape).background(p.foreground.copy(alpha = DS.Fill.inset))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontFamily = FontFamily.Serif, fontSize = 15.sp, color = if (enabled) p.foreground else p.secondary)
    }
}

@Composable
private fun <T> ChoiceRow(title: String, options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit) {
    val p = LocalSurface.current
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
        options.forEach { option ->
            ScopeChip(label(option), option == selected) { if (option != selected) onSelect(option) }
        }
    }
}
