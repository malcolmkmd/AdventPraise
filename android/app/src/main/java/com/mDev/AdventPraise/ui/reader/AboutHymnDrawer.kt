// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Book
import com.mDev.AdventPraise.ui.design.Glyphs
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.extras.Pitch
import com.mDev.AdventPraise.extras.PitchNotes
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.extras.ExtrasGroup
import com.mDev.AdventPraise.ui.extras.ExtrasRow
import com.mDev.AdventPraise.ui.extras.HymnFacts
import com.mDev.AdventPraise.ui.extras.andList
import com.mDev.AdventPraise.ui.extras.extrasIcon
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * The root of the About this hymn drawer (AboutHymnView): the start of its
 * story, then rows to the full story, the words and music, the sources, the
 * passages it draws on, the collections it belongs to and the pitch pipe. Each
 * is a page pushed inside the drawer (the extras area draws them); back
 * returns here. Memorise a verse wants the whole screen, so it opens in its
 * sheet. Opened from the reader menu's About panel, which is its summary.
 */
@Composable
fun AboutHymnRoot(services: AppServices, navigator: AppNavigator, source: String) {
    val p = LocalSurface.current
    val facts = HymnFacts.of(services) ?: return
    val context = LocalContext.current
    val pitch = remember(facts.hymnal.id, facts.hymn.number) {
        // The singer's own note (kept beside the other settings), else the published one.
        PitchNotes(services.catalogs.assets, SharedPreferencesStore(context, ReadingSettings.PREFS_NAME))
            .note(facts.hymnal.id, facts.hymn.number)?.let(Pitch::name)
    }
    ScreenEffect(AnalyticsScreen.AboutHymn)
    Column(
        Modifier.fillMaxWidth().padding(start = DS.Space.l, end = DS.Space.l, top = DS.Space.m),
        verticalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Column(Modifier.heightIn(min = DS.Size.hitTarget), verticalArrangement = Arrangement.spacedBy(DS.Space.hair, Alignment.CenterVertically)) {
            Eyebrow("${facts.hymnal.name} ${facts.hymn.number}", p.brass, tracking = 1.1f)
            Text(facts.hymn.title, style = DS.Type.sheetTitle, color = p.foreground, modifier = Modifier.semantics { heading() })
        }
        facts.storyText?.let {
            Text(
                it, style = DS.Type.rowBody.copy(fontFamily = FontFamily.Serif, fontSize = 17.sp, lineHeight = 22.sp),
                color = p.foreground, maxLines = 4, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = DS.Space.xxs),
            )
        }
        val hasStory = facts.storyText != null
        val hasCredits = facts.credits.isNotEmpty()
        val hasSources = facts.sources.isNotEmpty()
        if (hasStory || hasCredits || hasSources) {
            ExtrasGroup("Story") {
                if (hasStory) ExtrasRow("Read the full story", Icons.Outlined.Book, { navigator.navigate(Destination.HymnStory) },
                    isLast = !hasCredits && !hasSources)
                if (hasCredits) ExtrasRow("Words and music", Icons.Outlined.MusicNote, { navigator.navigate(Destination.HymnCredits) },
                    detail = facts.credits.first().value, isLast = !hasSources)
                if (hasSources) ExtrasRow("Sources", Icons.Rounded.FormatQuote, { navigator.navigate(Destination.HymnSources) },
                    detail = facts.sources.size.toString(), isLast = true)
            }
        }
        // Nothing at all when no passage is linked.
        if (facts.links.isNotEmpty()) {
            ExtrasGroup("Scripture") {
                ExtrasRow("Passages", Icons.AutoMirrored.Outlined.MenuBook, { navigator.navigate(Destination.HymnScripture) },
                    detail = andList(facts.links.map { it.passage.reference }), isLast = true)
            }
        }
        if (facts.collections.isNotEmpty()) {
            ExtrasGroup("In collections") {
                facts.collections.forEachIndexed { i, collection ->
                    ExtrasRow(collection.title, extrasIcon(collection.symbol),
                        { navigator.navigate(Destination.HymnCollectionPage(collection.id, collection.title)) },
                        isLast = i == facts.collections.lastIndex)
                }
            }
        }
        ExtrasGroup("Tools") {
            ExtrasRow("Pitch pipe", Glyphs.TuningFork, { navigator.navigate(Destination.HymnPitch) }, detail = pitch)
            // The game wants the whole screen: it opens in its sheet.
            ExtrasRow("Memorise a verse", Icons.Outlined.Psychology, { navigator.openMemorise(source) }, isLast = true)
        }
        Column(Modifier.heightIn(min = 8.dp)) {}
    }
}
