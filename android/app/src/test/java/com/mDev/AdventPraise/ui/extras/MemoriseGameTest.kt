package com.mDev.AdventPraise.ui.extras

import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.MemoryReplay
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.MemoryProgress
import com.mDev.AdventPraise.extras.MemoryRound
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.ui.design.HapticEvent
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** Memorise's view model (MemoryGameView's actions): picks, hints, scoring beats, rounds and replays. */
@OptIn(ExperimentalCoroutinesApi::class)
class MemoriseGameTest {
    private val hymn = Hymn(
        number = 30, title = "Amazing Grace", references = emptyList(), midiAsset = null,
        blocks = listOf(
            Block.Verse(1, listOf("Amazing grace, how sweet the sound,", "That saved a wretch like me!")),
            Block.Chorus(listOf("I once was lost, but now am found,", "Was blind, but now I see.")),
            Block.Verse(2, listOf("Twas grace that taught my heart to fear", "And grace my fears relieved")),
        ),
    )

    private class Recorder : MemoriseEffects {
        val haptics = mutableListOf<HapticEvent>()
        val lines = mutableListOf<String>()
        val events = mutableListOf<AnalyticsEvent>()
        override fun haptic(event: HapticEvent) { haptics += event }
        override fun announce(message: String) { lines += message }
        override fun track(event: AnalyticsEvent) { events += event }
        fun names() = events.map { it.name }
    }

    private val store = MemoryStore()
    private val scope = TestScope()
    private val effects = Recorder()

    private fun game(reduceMotion: Boolean = false, seed: Int = 3) = MemoriseGame(
        hymn, "Chorus", MemoryProgress(store, "english", 30), scope, effects, reduceMotion, Random(seed),
    ).also { it.start() }

    private fun MemoriseGame.answer(): String = round.current!!.let { round.token(it)!!.answer }
    private fun MemoriseGame.wrong(): String = round.choices.first { MemoryRound.key(it) != MemoryRound.key(answer()) && !round.isRuledOut(it) }
    private fun MemoriseGame.finishRound() { while (round.current != null) pick(answer()) }

    @Test fun aRoundStartsOnTheFirstVerseWithAFewWordsHidden() {
        val g = game()
        assertEquals(0, g.blockIndex)
        assertEquals(MemoryLevel.Few, g.level)
        assertEquals("Verse 1", g.blockName)
        assertTrue(g.round.targets.isNotEmpty())
        val started = effects.events.single()
        assertEquals("memory_game_started", started.name)
        assertEquals(mapOf("part" to "verse", "level" to "few", "word_count" to g.round.targets.size), started.properties)
    }

    @Test fun aRightWordScoresGlowsThenFades() {
        val g = game()
        val blank = g.round.current!!
        g.pick(g.answer())
        assertEquals(10, g.round.score)
        assertEquals(1, g.round.streak)
        assertEquals(blank, g.justFilled)
        assertEquals(HapticEvent.LightImpact, effects.haptics.last())
        assertTrue(effects.lines.last().endsWith("Streak 1."))
        scope.advanceTimeBy(MemoriseGame.GLOW_MS + 1)
        assertNull(g.justFilled)
    }

    @Test fun threeInARowEarnsAHintWithANoteThatGoes() {
        val g = game(seed = 11)
        g.changeToLevel(MemoryLevel.All)
        repeat(3) { g.pick(g.answer()) }
        assertEquals(2, g.round.hints)
        assertEquals("3 in a row, +1 hint", g.note?.text)
        assertEquals(MemoriseGame.Note.Symbol.Hint, g.note?.symbol)
        assertEquals(HapticEvent.ThresholdCrossed, effects.haptics.last())
        assertTrue("memory_streak_reached" in effects.names())
        assertTrue(effects.lines.last().endsWith("Hint earned."))
        scope.advanceTimeBy(MemoriseGame.GLOW_MS + MemoriseGame.NOTE_MS + 1)
        assertNull(g.note)
    }

    @Test fun aWrongWordShakesIsRuledOutAndASecondShowsTheFirstLetter() {
        val g = game(seed = 5)
        g.changeToLevel(MemoryLevel.All)
        val first = g.wrong()
        g.pick(first)
        assertEquals(1, g.shakes[first])
        assertTrue(g.round.isRuledOut(first))
        assertEquals(0, g.round.streak)
        assertEquals(HapticEvent.Error, effects.haptics.last())
        assertEquals("Not $first.", effects.lines.last())
        assertNull(g.note)

        val second = g.wrong()
        g.pick(second)
        assertEquals("First letter shown", g.note?.text)
        assertEquals(g.round.current, g.note?.blank)
        assertTrue(effects.lines.last().startsWith("Not $second. It starts "))

        // Filling that blank takes its note away, and scores 5.
        g.pick(g.answer())
        assertNull(g.note)
        assertEquals(5, g.round.score)
        assertTrue(g.shakes.isEmpty())
    }

    @Test fun aHintShowsALetterRulesOutChipsAndIsCounted() {
        val g = game(seed = 9)
        g.changeToLevel(MemoryLevel.All)
        val blank = g.round.current!!
        g.hint()
        assertEquals(0, g.round.hints)
        assertEquals(1, g.round.shownLetters(blank))
        assertEquals(HapticEvent.SoftImpact, effects.haptics.last())
        val used = effects.events.last()
        assertEquals("memory_hint_used", used.name)
        assertEquals(0, used.properties["hints_left"])
        assertTrue(effects.lines.last().matches(Regex("It starts .+\\. \\d words left to choose from\\.")))
        // None left: nothing happens.
        val before = effects.events.size
        g.hint()
        assertEquals(before, effects.events.size)
        // The hinted word scores less but keeps no streak broken.
        g.pick(g.answer())
        assertEquals(5, g.round.score)
    }

    @Test fun finishingAStanzaRecordsStarsAndRevealsThemOneByOne() {
        val g = game()
        g.finishRound()
        assertTrue(g.round.isComplete)
        assertEquals(3, g.round.stars)
        assertTrue(g.isNewBest)
        assertEquals("Word perfect, or near enough. A new best.", g.verdict)
        assertEquals(3, MemoryProgress(store, "english", 30).stars(0, MemoryLevel.Few))
        assertEquals(HapticEvent.Success, effects.haptics.last())
        val completed = effects.events.last { it.name == "memory_game_completed" }
        assertEquals(100, completed.properties["first_try_percent"])
        assertEquals(3, completed.properties["stars"])
        assertTrue(effects.lines.last().startsWith("Verse 1 finished, round 1 of 4. 3 stars. Score "))

        assertEquals(0, g.starsShown)
        scope.advanceTimeBy(MemoriseGame.FIRST_STAR_MS + 1)
        assertEquals(1, g.starsShown)
        scope.advanceTimeBy(MemoriseGame.NEXT_STAR_MS * 2 + 1)
        assertEquals(3, g.starsShown)
        assertEquals(listOf(HapticEvent.Success, HapticEvent.LightImpact, HapticEvent.LightImpact, HapticEvent.LightImpact), effects.haptics.takeLast(4))
    }

    @Test fun withAnimationsOffTheStarsShowAtOnce() {
        val g = game(reduceMotion = true)
        g.finishRound()
        assertEquals(3, g.starsShown)
    }

    @Test fun aBestIsKeptAndNotBeatenByAWorseRound() {
        val g = game()
        g.finishRound()
        g.replay(MemoryReplay.Again)
        g.pick(g.wrong())
        g.finishRound()
        assertTrue(g.round.stars < 3)
        assertFalse(g.isNewBest)
        assertEquals(3, g.bestStars(MemoryLevel.Few))
        scope.runCurrent()
    }

    @Test fun nextRoundHidesMoreAndPlayAgainDealsFreshBlanks() {
        val g = game()
        g.finishRound()
        val targets = g.round.targets
        g.replay(MemoryReplay.Again)
        assertNotEquals(targets, g.round.targets)
        assertEquals(MemoryLevel.Few, g.level)
        assertEquals(0, g.starsShown)

        g.finishRound()
        g.replay(MemoryReplay.NextLevel)
        assertEquals(MemoryLevel.Half, g.level)
        val replayed = effects.events.last { it.name == "memory_round_replayed" }
        assertEquals(mapOf("part" to "verse", "level" to "half", "reason" to "next_level"), replayed.properties)
        assertEquals("memory_game_started", effects.events.last().name)
        assertEquals(HapticEvent.Selection, effects.haptics.last())
    }

    @Test fun allHiddenLearnsTheStanzaThenStartOverOrNextVerse() {
        val g = game()
        g.changeToLevel(MemoryLevel.All)
        g.finishRound()
        assertTrue(g.isLearned(0))
        assertTrue("memory_verse_learned" in effects.names())
        assertTrue(effects.lines.last().startsWith("Verse 1 learned by heart."))

        g.replay(MemoryReplay.StartOver)
        assertEquals(MemoryLevel.Few, g.level)
        assertEquals("few", effects.events.last { it.name == "memory_round_replayed" }.properties["level"])

        g.changeToLevel(MemoryLevel.All)
        g.finishRound()
        g.replay(MemoryReplay.NextBlock)
        assertEquals(1, g.blockIndex)
        assertEquals("Chorus", g.blockName)
        assertEquals("chorus", effects.events.last().properties["part"])
    }

    @Test fun choosingTheOpenStanzaOnlyTicks() {
        val g = game()
        val round = g.round
        g.selectBlock(0)
        assertTrue(round === g.round)
        assertEquals(HapticEvent.Selection, effects.haptics.last())
        g.selectBlock(2)
        assertEquals("Verse 2", g.blockName)
        assertTrue(round !== g.round)
    }

    @Test fun blanksGiveNothingAwayUntilLettersAreShown() {
        val g = game(seed = 4)
        g.changeToLevel(MemoryLevel.All)
        val token = g.round.token(g.round.current!!)!!
        assertTrue(g.blank(token).startsWith("_____"))
        g.pick(g.wrong()); g.pick(g.wrong())
        val shown = g.blank(token)
        assertEquals(token.text.length, shown.length)
        assertEquals(token.answer.first(), shown.first())
        assertTrue(g.spokenVerse.startsWith("next blank starting ${token.answer.first()}"))
    }

    @Test fun memoriseIsUnlimitedAsOnIOS() {
        // iOS gates nothing in MemoryGameView: round after round plays on.
        val g = game()
        repeat(12) {
            g.finishRound()
            g.replay(MemoryReplay.Again)
        }
        assertEquals(13, effects.names().count { it == "memory_game_started" })
        assertTrue(g.round.choices.isNotEmpty())
    }

    /** Changes level as the picker does. */
    private fun MemoriseGame.changeToLevel(level: MemoryLevel) = selectLevel(level)
}
