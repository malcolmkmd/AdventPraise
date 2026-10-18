// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.HymnalSource
import com.mDev.AdventPraise.analytics.ScriptureSurface
import com.mDev.AdventPraise.analytics.ToolSource
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.extras.ExtraSheet
import com.mDev.AdventPraise.extras.ScriptureConfidence
import com.mDev.AdventPraise.reader.ReaderMenuPanel
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.ui.design.DSHymnal
import com.mDev.AdventPraise.ui.design.DSHymnalAccess
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.HapticOnChange
import com.mDev.AdventPraise.ui.design.LanguageTile
import com.mDev.AdventPraise.ui.design.LanguageTileGrid
import com.mDev.AdventPraise.ui.design.LanguageTileRingInset
import com.mDev.AdventPraise.ui.design.ReadingFontPicker
import com.mDev.AdventPraise.ui.design.ReadingLayoutControls
import com.mDev.AdventPraise.ui.design.ReadingSizeControl
import com.mDev.AdventPraise.ui.design.ReadingSurfacePicker
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.extras.ExtrasFlow
import com.mDev.AdventPraise.ui.extras.HymnFacts
import com.mDev.AdventPraise.ui.extras.ScriptureChip
import com.mDev.AdventPraise.ui.extras.extrasIcon
import com.mDev.AdventPraise.ui.extras.trackScriptureOpened
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.readingStyle

/*
 * The panels that unfold under the reader menu's bar (ReaderMenuPanels.swift):
 * Translation, Theme, Text and About. They sit inside the menu's glass, so
 * nothing in here draws glass of its own. Each scrolls once it would pass
 * `maxHeight`, which leaves the Lectern and some lyrics in view.
 */

@Composable
fun ReaderMenuPanelContent(services: AppServices, panel: ReaderMenuPanel, maxHeight: Dp) {
    val model = services.reader
    when (panel) {
        // "Hymn N in…" heads the list, inside the same height.
        ReaderMenuPanel.Translation -> TranslationSwitcher(
            model, HymnalSource.Translation, maxHeight = maxHeight - 44.dp, onSwitched = { model.closeMenu() },
        )
        ReaderMenuPanel.Theme -> ThemePanel(services)
        ReaderMenuPanel.Text -> TextPanel(services, maxHeight)
        ReaderMenuPanel.About -> AboutHymnPanel(services, maxHeight)
    }
}

/** A hymnal as the design components take it (designHymnal). */
val HymnalInfo.design: DSHymnal get() = DSHymnal(id, name, language, isOwnBook = isOwnBook)

/** Every hymnal is free: the open one is current, the rest are owned (PurchaseStore.access). */
fun ReaderModel.access(hymnal: DSHymnal): DSHymnalAccess =
    if (hymnal.id == hymnalInfo?.id) DSHymnalAccess.Current else DSHymnalAccess.Owned

/**
 * Under a tile: nil shows the hymnal's title. Across numberings, where the
 * hymn is, or that it isn't there (TranslationSwitcher.detail).
 */
fun ReaderModel.translationDetail(info: HymnalInfo): String? {
    val current = hymnalInfo ?: return null
    val number = hymn?.number ?: return null
    if (info.id == current.id) return null
    if (info.numbering == current.numbering) {
        return if (number <= info.maxNumber) null else "No hymn $number · opens the first hymn"
    }
    val there = crossReference?.number(number, current, info) ?: return "${info.name} · not in this hymnal"
    return "${info.name} · hymn $there"
}

/** Switches to the hymnal; [onSwitched] runs once the reader shows it (ReaderModel.select). */
fun ReaderModel.select(hymnal: DSHymnal, source: HymnalSource, onSwitched: () -> Unit = {}) {
    val info = catalogs.hymnal(hymnal.id) ?: return
    switchHymnal(info, source, then = onSwitched)
}

/**
 * "Hymn N in…" and every hymnal (all free) as colour tiles: the reader menu's
 * Translation panel, and church mode's globe popover. One tap switches straight
 * away and keeps the hymn: the same number among Christ In Song and its
 * translations, and across to the SDA Hymnal (its own numbers, its own
 * full-width tile) the cross-referenced hymn, whose number the tile shows.
 */
@Composable
fun TranslationSwitcher(
    model: ReaderModel,
    source: HymnalSource,
    modifier: Modifier = Modifier,
    maxHeight: Dp = 420.dp,
    onSwitched: () -> Unit = {},
) {
    val p = LocalSurface.current
    val number = model.hymn?.number ?: return
    ScreenEffect(AnalyticsScreen.Translations)
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Eyebrow(
            "Hymn $number in…", p.secondary,
            Modifier.padding(start = DS.Space.panel, end = DS.Space.panel, top = DS.Space.panel).semantics { heading() },
        )
        FittingScroll(maxHeight) {
            LanguageTileGrid(
                model.catalogue.map { it.design },
                // Tiles line up with the heading; their ring padding makes up the rest.
                Modifier.padding(start = DS.Space.panel - LanguageTileRingInset, end = DS.Space.panel - LanguageTileRingInset, bottom = DS.Space.xs),
            ) { hymnal, m ->
                val info = model.catalogs.hymnal(hymnal.id)
                LanguageTile(
                    hymnal,
                    model.access(hymnal),
                    onClick = { model.select(hymnal, source, onSwitched) },
                    modifier = m,
                    detail = info?.let(model::translationDetail),
                    switchHint = "Shows this hymn in ${if (hymnal.isOwnBook) hymnal.name else hymnal.language}",
                )
            }
        }
    }
}

// MARK: - Theme

@Composable
private fun ThemePanel(services: AppServices) {
    val settings = services.settings
    ScreenEffect(AnalyticsScreen.Appearance)
    HapticOnChange(HapticEvent.Selection, settings.surface)
    ReadingSurfacePicker(settings.surface, onChange = settings::updateSurface, modifier = Modifier.padding(DS.Space.panel))
}

// MARK: - Text

@Composable
private fun TextPanel(services: AppServices, maxHeight: Dp) {
    val settings = services.settings
    val style = settings.readingStyle
    ScreenEffect(AnalyticsScreen.Appearance)
    HapticOnChange(HapticEvent.Selection, style)
    FittingScroll(maxHeight) {
        Column(Modifier.padding(DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.panel)) {
            ReadingSizeControl(style, onChange = settings::apply)
            ReadingFontPicker(style, onChange = settings::apply)
            ReadingLayoutControls(style, onChange = settings::apply)
        }
    }
}

// MARK: - About

/**
 * A summary of About this hymn: who wrote it and when, the start of its story,
 * the passages it draws on and the collections it's in. The full story and the
 * links between hymns are one tap away, in the About this hymn drawer.
 */
@Composable
private fun AboutHymnPanel(services: AppServices, maxHeight: Dp) {
    val model = services.reader
    val navigator = LocalAppNavigator.current
    val p = LocalSurface.current
    val facts = HymnFacts.of(services) ?: return
    ScreenEffect(AnalyticsScreen.AboutHymnPanel)
    // "Words Fanny Crosby · Music Phoebe Knapp · 1873"
    val story = facts.story
    val credits = listOfNotNull(story?.words?.let { "Words $it" }, story?.music?.let { "Music $it" }, story?.year)
        .filter { it.isNotEmpty() }.takeIf { it.isNotEmpty() }?.joinToString(" · ")
    FittingScroll(maxHeight) {
        Column(Modifier.fillMaxWidth().padding(DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                Eyebrow("${facts.hymnal.name} ${facts.hymn.number}", p.brass, tracking = 1.1f)
                Text(facts.hymn.title, style = DS.Type.panelTitle, color = p.foreground, modifier = Modifier.semantics { heading() })
                if (credits != null) Text(credits, style = DS.Type.caption, color = p.secondary)
                facts.storyText?.let {
                    Text(
                        it, style = DS.Type.rowBody.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 21.sp),
                        color = p.foreground, maxLines = 5, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = DS.Space.xxs),
                    )
                }
            }
            if (facts.links.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    PanelLabel("Scripture")
                    ExtrasFlow {
                        facts.links.forEach { link ->
                            ScriptureChip(link.passage, isEcho = link.confidence == ScriptureConfidence.Medium) {
                                trackScriptureOpened(facts.hymnal.id, facts.hymn.number, link.passage, link.confidence, ScriptureSurface.ReaderMenu)
                            }
                        }
                    }
                }
            }
            if (facts.collections.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    PanelLabel("In collections")
                    ExtrasFlow {
                        facts.collections.forEach { collection ->
                            Row(
                                Modifier
                                    .heightIn(min = 32.dp)
                                    .background(p.primary(DS.Fill.inset), RoundedCornerShape(50))
                                    .padding(horizontal = DS.Space.m)
                                    .clearAndSetSemantics { contentDescription = collection.title },
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
                            ) {
                                Icon(extrasIcon(collection.symbol), null, tint = p.foreground, modifier = Modifier.size(14.dp))
                                Text(collection.title, style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = p.foreground)
                            }
                        }
                    }
                }
            }
            val interaction = remember { MutableInteractionSource() }
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = DS.Size.hitTarget)
                    .dsPress(interaction)
                    .background(p.primary(DS.Fill.inset), dsShape(DS.Radius.tile))
                    .clickable(interaction, null, role = Role.Button) {
                        model.closeMenu()
                        Analytics.track(AnalyticsEvent.ToolOpened(ExtraSheet.About, ToolSource.ReaderMenu))
                        navigator.openAboutHymn("reader_menu")
                    }
                    .semantics { role = Role.Button }
                    .padding(horizontal = DS.Space.m),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(if (facts.storyText != null) "Read the full story" else "More about this hymn", style = DS.Type.label, color = p.tint)
                Spacer(Modifier.weight(1f).width(0.dp))
                Icon(Icons.Rounded.ChevronRight, null, tint = p.tint, modifier = Modifier.size(18.dp))
            }
        }
    }
}

@Composable
private fun PanelLabel(text: String) {
    Eyebrow(text, LocalSurface.current.secondary, Modifier.semantics { heading() })
}
