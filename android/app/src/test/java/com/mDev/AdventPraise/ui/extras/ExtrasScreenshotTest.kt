package com.mDev.AdventPraise.ui.extras

import android.app.Application
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.extras.HymnCollections
import com.mDev.AdventPraise.extras.HymnStories
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.MemoryProgress
import com.mDev.AdventPraise.extras.MemoryRound
import com.mDev.AdventPraise.extras.ScriptureLinks
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.AdventDrawer
import com.mDev.AdventPraise.ui.design.AdventDrawerStyle
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.root.SheetContainer
import com.mDev.AdventPraise.ui.theme.SurfaceGround
import com.mDev.AdventPraise.ui.theme.VesperTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.LocalDate
import kotlin.random.Random

/**
 * JVM screenshots of the extras, light (Paper) and dark (Black), on the shipped
 * data: About this hymn's story and scripture pages in the drawer, Collections,
 * the Scripture index, Memorise mid-round and at the end of a round, and the
 * service planner's list and editor in More's sheet.
 * `./gradlew recordRoborazziDebug --tests '*ExtrasScreenshotTest'` records them.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi", application = Application::class)
class ExtrasScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val assets = DirectoryAssets.iosResources()
    private val english: Hymnal = Hymnal.load(assets, HymnalInfo.catalogue(assets).first { it.id == "english" })!!
    private val scripture = ScriptureLinks(assets)
    private val collections = HymnCollections(assets)
    private val facts = HymnFacts.of(english, english.hymn(218)!!, HymnStories(assets, SdahTunes(assets)), scripture, collections)
    private val today = LocalDate.of(2026, 10, 21)

    private fun shot(name: String, dark: Boolean, content: @Composable () -> Unit) {
        compose.setContent {
            VesperTheme(if (dark) ReadingSurface.Black else ReadingSurface.Paper) {
                SurfaceGround(Modifier.fillMaxSize()) { content() }
            }
        }
        // The settled state: glows faded, notes gone, stars revealed.
        compose.mainClock.advanceTimeBy(3_000)
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("src/test/screenshots/extras_${name}_${if (dark) "dark" else "light"}.png")
    }

    @Composable
    private fun InDrawer(pageTitle: String, content: @Composable () -> Unit) {
        AdventDrawer("About this hymn", onDismissRequest = {}, style = AdventDrawerStyle(showsClose = false),
            pageTitle = pageTitle, onBack = {}) { content() }
    }

    @Composable
    private fun InMore(title: String, scrolls: Boolean = true, content: @Composable () -> Unit) {
        SheetContainer(title, visible = true, onDismissRequest = {}, onGone = {}, onBack = {}) {
            if (scrolls) Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) { content() } else content()
        }
    }

    // About this hymn

    private fun story(dark: Boolean) = shot("about_story", dark) { InDrawer("Story") { HymnStoryContent(facts) } }
    @Test fun storyLight() = story(false)
    @Test fun storyDark() = story(true)

    private fun scripturePage(dark: Boolean) = shot("about_scripture", dark) {
        InDrawer("Scripture") { HymnScriptureContent(facts, otherHymnsOn(facts, scripture)) {} }
    }
    @Test fun scriptureLight() = scripturePage(false)
    @Test fun scriptureDark() = scripturePage(true)

    // More pages

    private fun collectionsPage(dark: Boolean) = shot("collections", dark) {
        InMore("Collections") { CollectionsContent(english, collections.available(english.id), loaded = true) {} }
    }
    @Test fun collectionsLight() = collectionsPage(false)
    @Test fun collectionsDark() = collectionsPage(true)

    private fun collection(dark: Boolean) = shot("collection_gospel", dark) {
        val gospel = collections.all.first { it.id == "gospel" }
        InMore(gospel.title) {
            CollectionHymnsContent(english, gospel, gospel.numbers(english.id).filter { english.hymn(it) != null }, copied = false, {}, {}, {},
                morePage(true))
        }
    }
    @Test fun collectionLight() = collection(false)
    @Test fun collectionDark() = collection(true)

    private fun scriptureIndex(dark: Boolean) = shot("scripture_index", dark) {
        InMore("Scripture index") { ScriptureIndexContent(english, scripture.index(english.id), "", {}) {} }
    }
    @Test fun scriptureIndexLight() = scriptureIndex(false)
    @Test fun scriptureIndexDark() = scriptureIndex(true)

    // Memorise

    private object Silent : MemoriseEffects {
        override fun haptic(event: HapticEvent) {}
        override fun announce(message: String) {}
        override fun track(event: AnalyticsEvent) {}
    }

    @Composable
    private fun rememberGame(reduceMotion: Boolean, play: MemoriseGame.() -> Unit): MemoriseGame {
        val scope = rememberCoroutineScope()
        return remember {
            MemoriseGame(english.hymn(1)!!, english.chorusLabel, MemoryProgress(MemoryStore(), "english", 1), scope, Silent,
                reduceMotion, Random(7)).apply { start(); play() }
        }
    }

    private fun MemoriseGame.answer() = round.current!!.let { round.token(it)!!.answer }

    private fun memoriseMidRound(dark: Boolean) = shot("memorise_mid_round", dark) {
        val game = rememberGame(reduceMotion = false) {
            selectLevel(MemoryLevel.Half)
            repeat(4) { pick(answer()) }
            pick(round.choices.first { MemoryRound.key(it) != MemoryRound.key(answer()) })
        }
        InMore("Memorise", scrolls = false) { MemoriseContent(game) }
    }
    @Test fun memoriseMidRoundLight() = memoriseMidRound(false)
    @Test fun memoriseMidRoundDark() = memoriseMidRound(true)

    private fun memoriseEnd(dark: Boolean) = shot("memorise_end_of_round", dark) {
        val game = rememberGame(reduceMotion = true) {
            pick(round.choices.first { MemoryRound.key(it) != MemoryRound.key(answer()) })
            while (round.current != null) pick(answer())
        }
        InMore("Memorise", scrolls = false) { MemoriseContent(game) }
    }
    @Test fun memoriseEndOfRoundLight() = memoriseEnd(false)
    @Test fun memoriseEndOfRoundDark() = memoriseEnd(true)

    // Service planner

    private val planner = ServicePlanner(MemoryStore(), today = { today }).apply {
        newPlan("english", listOf(1, 30, 218, 100, 254, 12)).also { update(it.copy(name = "Communion Sabbath")) }
        val later = newPlan("english", listOf(18))
        update(later.copy(name = "Youth Sabbath", date = today.plusDays(24)))
        val past = newPlan("english", listOf(5, 9))
        update(past.copy(name = "Harvest thanksgiving", date = today.minusDays(11)))
    }

    private fun plans(dark: Boolean) = shot("service_planner", dark) {
        InMore("Service planner") {
            ServicePlansContent(english, english.hymn(218)!!, planner.plans("english"), today, {}, {}, {}, {})
        }
    }
    @Test fun servicePlannerLight() = plans(false)
    @Test fun servicePlannerDark() = plans(true)

    private fun planEditor(dark: Boolean) {
        val plan = planner.plans("english").first { it.name == "Communion Sabbath" }
        planner.update(plan.copy(items = plan.items.mapIndexed { i, item ->
            item.copy(role = when (i) { 0 -> "Opening hymn"; 2 -> "Before the sermon"; 5 -> "Closing hymn"; else -> null })
        }))
        val editor = ServicePlanEditor(planner, plan.id, english) {}
        shot("service_plan", dark) {
            InMore("Service plan") { ServicePlanContent(editor, english, english.hymn(2)!!, today, {}, {}, {}) }
        }
    }
    @Test fun servicePlanLight() = planEditor(false)
    @Test fun servicePlanDark() = planEditor(true)
}
