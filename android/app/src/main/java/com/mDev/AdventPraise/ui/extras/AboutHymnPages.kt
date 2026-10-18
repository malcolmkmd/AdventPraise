// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.FilterNone
import androidx.compose.material.icons.rounded.FormatListNumbered
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.ScriptureSurface
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.BibleBook
import com.mDev.AdventPraise.extras.HymnCollection
import com.mDev.AdventPraise.extras.HymnCollections
import com.mDev.AdventPraise.extras.HymnStories
import com.mDev.AdventPraise.extras.HymnStory
import com.mDev.AdventPraise.extras.Passage
import com.mDev.AdventPraise.extras.ScriptureConfidence
import com.mDev.AdventPraise.extras.ScriptureLink
import com.mDev.AdventPraise.extras.ScriptureLinks
import com.mDev.AdventPraise.extras.ScriptureSource
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/*
 * The pages inside the About this hymn drawer (Extras/AboutHymnDrawer.swift,
 * DrawerPages.swift, HymnStories.swift). The drawer draws the bar with Back and
 * the page title; these draw the page. A passage's hymns and a collection's are
 * also More pages.
 */

/** What the app knows about the hymn on the reader, for About this hymn's pages (HymnFacts). */
data class HymnFacts(
    val hymnal: Hymnal,
    val hymn: Hymn,
    val story: HymnStory?,
    val links: List<ScriptureLink>,
    val collections: List<HymnCollection>,
) {
    val storyText: String? get() = story?.story?.takeIf { it.isNotEmpty() }
    val sources: List<String> get() = story?.sources.orEmpty()

    data class Credit(val label: String, val value: String)

    /** Words, Music and Year, those that are known. */
    val credits: List<Credit>
        get() = listOf("Words" to story?.words, "Music" to story?.music, "Year" to story?.year)
            .mapNotNull { (label, value) -> value?.takeIf { it.isNotEmpty() }?.let { Credit(label, it) } }

    val scriptureFooter: String
        get() {
            val kinds = links.map { it.source }.toSet()
            val labels = listOf(ScriptureSource.Lyric, ScriptureSource.Hymnal, ScriptureSource.Hymnary).filter { it in kinds }.map { it.label }
            var text = "Opens in the Bible app."
            if (links.any { it.confidence == ScriptureConfidence.Medium }) text += " ≈ marks a passage the hymn echoes rather than quotes."
            return text + " Source: " + labels.joinToString("; ") + "."
        }

    companion object {
        fun of(hymnal: Hymnal, hymn: Hymn, stories: HymnStories, scripture: ScriptureLinks, collections: HymnCollections) = HymnFacts(
            hymnal, hymn,
            story = stories.story(hymnal.id, hymn.number),
            links = scripture.links(hymnal.id, hymn.number),
            collections = collections.containing(hymn.number, hymnal.id),
        )

        /** The open hymn's facts, or null while the reader is still loading. */
        fun of(services: AppServices): HymnFacts? {
            val hymnal = services.reader.hymnal ?: return null
            val hymn = services.reader.hymn ?: return null
            val c = services.catalogs
            return of(hymnal, hymn, c.stories, c.scripture, c.collections)
        }
    }
}

/** A passage the hymn cites that other hymns cite too ("Also on …"). */
data class OtherHymnsOn(val passage: Passage, val count: Int)

/** The passages of [facts] that other hymns of its hymnal also draw on. */
fun otherHymnsOn(facts: HymnFacts, scripture: ScriptureLinks): List<OtherHymnsOn> = facts.links.mapNotNull { link ->
    val numbers = scripture.hymns(link.passage, facts.hymnal.id, excluding = facts.hymn.number)
    if (numbers.isEmpty()) null else OtherHymnsOn(link.passage, numbers.size)
}

/** `scripture_opened`, as every scripture chip sends it. */
fun trackScriptureOpened(hymnal: String, number: Int?, passage: Passage, confidence: ScriptureConfidence?, surface: ScriptureSurface) =
    Analytics.track(AnalyticsEvent.ScriptureOpened(hymnal, number, BibleBook.usfm(passage.book) ?: "", confidence, surface))

// MARK: - Story

/** The hymn's story (HymnStories): its credits on one line, then the story. */
@Composable
fun HymnStoryPage(services: AppServices, navigator: AppNavigator) {
    HymnFacts.of(services)?.let { HymnStoryContent(it) }
}

@Composable
fun HymnStoryContent(facts: HymnFacts) {
    val p = LocalSurface.current
    DrawerPageLayout {
        val credits = facts.credits.map { it.value }
        if (credits.isNotEmpty()) Text(credits.joinToString(" · "), style = DS.Type.caption, color = p.secondary)
        SelectionContainer { Text(facts.storyText.orEmpty(), style = serif(17f), color = p.foreground) }
    }
}

// MARK: - Words and music

/** Words and music: authors, composers, dates. */
@Composable
fun HymnCreditsPage(services: AppServices, navigator: AppNavigator) {
    HymnFacts.of(services)?.let { HymnCreditsContent(it) }
}

@Composable
fun HymnCreditsContent(facts: HymnFacts) {
    val credits = facts.credits
    DrawerPageLayout {
        ExtrasGroup {
            credits.forEachIndexed { i, credit -> FactRow(credit.label, credit.value, isLast = i == credits.lastIndex) }
        }
    }
}

@Composable
private fun FactRow(title: String, value: String, isLast: Boolean) {
    val p = LocalSurface.current
    Box(Modifier.semantics(mergeDescendants = true) {}) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 46.dp).padding(horizontal = DS.Space.m, vertical = DS.Space.s),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = DS.Type.label, color = p.foreground)
            Spacer(Modifier.widthIn(min = DS.Space.s).weight(1f))
            SelectionContainer {
                Text(value, style = DS.Type.label, color = p.secondary, textAlign = TextAlign.End)
            }
        }
        if (!isLast) RowDivider(Modifier.align(Alignment.BottomStart))
    }
}

// MARK: - Sources

@Composable
fun HymnSourcesPage(services: AppServices, navigator: AppNavigator) {
    HymnFacts.of(services)?.let { HymnSourcesContent(it) }
}

@Composable
fun HymnSourcesContent(facts: HymnFacts) {
    val p = LocalSurface.current
    val sources = facts.sources
    DrawerPageLayout {
        ExtrasGroup {
            sources.forEachIndexed { i, source ->
                Box(Modifier.fillMaxWidth().heightIn(min = 46.dp), contentAlignment = Alignment.CenterStart) {
                    SelectionContainer(Modifier.padding(horizontal = DS.Space.m, vertical = DS.Space.xs)) {
                        Text(source, style = DS.Type.caption, color = p.foreground)
                    }
                    if (i < sources.lastIndex) RowDivider(Modifier.align(Alignment.BottomStart))
                }
            }
        }
        DrawerNote("Where the story, the names and the year come from.")
    }
}

// MARK: - Scripture

/** The passages the hymn cites; other hymns on each open [PassageHymnsPage]. */
@Composable
fun HymnScripturePage(services: AppServices, navigator: AppNavigator) {
    val facts = HymnFacts.of(services) ?: return
    HymnScriptureContent(
        facts = facts,
        others = remember(facts.hymnal.id, facts.hymn.number) { otherHymnsOn(facts, services.catalogs.scripture) },
        onOpenPassage = { navigator.navigate(Destination.HymnPassage(it.id, it.reference)) },
    )
}

@Composable
fun HymnScriptureContent(facts: HymnFacts, others: List<OtherHymnsOn>, onOpenPassage: (Passage) -> Unit) {
    DrawerPageLayout {
        ExtrasFlow {
            facts.links.forEach { link ->
                ScriptureChip(link.passage, isEcho = link.confidence == ScriptureConfidence.Medium) {
                    trackScriptureOpened(facts.hymnal.id, facts.hymn.number, link.passage, link.confidence, ScriptureSurface.AboutHymn)
                }
            }
        }
        DrawerNote(facts.scriptureFooter)
        if (others.isNotEmpty()) {
            ExtrasGroup("Other hymns") {
                others.forEachIndexed { i, other ->
                    ExtrasRow(
                        title = "Also on ${other.passage.reference}",
                        icon = Icons.AutoMirrored.Rounded.MenuBook,
                        detail = hymnCount(other.count),
                        isLast = i == others.lastIndex,
                        onClick = { onOpenPassage(other.passage) },
                    )
                }
            }
        }
    }
}

// MARK: - A passage's hymns

/**
 * A passage, then the hymns that cite it (PassageHymnsPage): in the drawer it
 * leaves out the hymn being read; as a More page, it lists them all.
 */
@Composable
fun PassageHymnsPage(services: AppServices, navigator: AppNavigator, passageId: String, reference: String) {
    val hymnal = services.reader.hymnal ?: return
    val passage = remember(passageId) { Passage.parse(passageId) ?: Passage.parse(reference) } ?: return
    val inDrawer = navigator.stack.any { it is Destination.HymnPassage && it.passageId == passageId }
    val excluding = if (inDrawer) services.reader.hymn?.number else null
    val numbers = remember(hymnal.id, passageId, excluding) { services.catalogs.scripture.hymns(passage, hymnal.id, excluding) }
    PassageHymnsContent(hymnal, passage, numbers, excludesOne = excluding != null, morePage(!inDrawer)) {
        navigator.openHymn(it, HymnSource.Scripture.key)
    }
}

@Composable
fun PassageHymnsContent(
    hymnal: Hymnal,
    passage: Passage,
    numbers: List<Int>,
    excludesOne: Boolean,
    modifier: Modifier = Modifier,
    onOpen: (Int) -> Unit,
) {
    DrawerPageLayout(modifier) {
        if (passage.bibleUrl != null) {
            ScriptureChip(passage, title = "Read ${passage.reference}") {
                trackScriptureOpened(hymnal.id, null, passage, null, ScriptureSurface.Passage)
            }
        }
        if (numbers.isEmpty()) {
            DrawerNote(
                if (excludesOne) "No other hymn in ${hymnal.name} is linked to ${passage.reference}."
                else "No hymn in ${hymnal.name} is linked to ${passage.reference}.",
            )
        } else {
            HymnNumberGroup("Hymns on ${passage.reference}", hymnal, numbers, onOpen)
        }
    }
}

// MARK: - A collection's hymns

/**
 * A collection's hymns in the open hymnal (CollectionHymnsPage), to sing in
 * church mode or copy into a service plan. As a More page the copy opens the
 * new plan; in the drawer the row says the copy was made.
 */
@Composable
fun CollectionHymnsPage(services: AppServices, navigator: AppNavigator, collectionId: String, title: String) {
    val hymnal = services.reader.hymnal ?: return
    val collection = services.catalogs.collections.all.firstOrNull { it.id == collectionId } ?: return
    val numbers = remember(hymnal.id, collectionId) { collection.numbers(hymnal.id).filter { hymnal.hymn(it) != null } }
    val inMore = navigator.stack.any { it is Destination.Collection && it.collectionId == collectionId }
    val view = LocalView.current
    var copied by remember { mutableStateOf(false) }
    CollectionHymnsContent(
        hymnal = hymnal,
        collection = collection,
        numbers = numbers,
        copied = copied,
        onSing = { ExtrasActions.startChurchMode(services, navigator, numbers, collection.title, ExtrasActions.Queue.Collection) },
        onCopy = {
            if (!copied) {
                val plan = services.planner.newPlan(hymnal.id, numbers)
                Haptics.play(HapticEvent.Selection)
                if (inMore) {
                    navigator.openServicePlan(plan.id)
                } else {
                    copied = true
                    @Suppress("DEPRECATION") view.announceForAccessibility("Copied to a new service plan")
                }
            }
        },
        onOpen = { navigator.openHymn(it, HymnSource.Collection.key) },
        modifier = morePage(inMore),
    )
}

/** A More page sits in More's scroller with a margin above and below (MorePageScroll). */
internal fun morePage(isMorePage: Boolean): Modifier = if (isMorePage) Modifier.padding(vertical = DS.Space.m) else Modifier

@Composable
fun CollectionHymnsContent(
    hymnal: Hymnal,
    collection: HymnCollection,
    numbers: List<Int>,
    copied: Boolean,
    onSing: () -> Unit,
    onCopy: () -> Unit,
    onOpen: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    DrawerPageLayout(modifier) {
        if (numbers.isEmpty()) {
            DrawerNote("${hymnal.name} has no hymns from the SDA Hymnal’s ${collection.title} section.")
        } else {
            ExtrasGroup {
                ExtrasRow("Sing in church mode", Icons.Rounded.FilterNone, onSing)
                ExtrasRow(
                    if (copied) "Copied to a new service plan" else "Copy to a new service plan",
                    if (copied) Icons.Rounded.Check else Icons.Rounded.FormatListNumbered,
                    onCopy, isLast = true,
                )
            }
            HymnNumberGroup(hymnCount(numbers.size), hymnal, numbers, onOpen)
        }
        DrawerNote("SDA Hymnal ${collection.sdahRange}")
    }
}
