package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.settings.MemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.ceil
import kotlin.random.Random

/** The Memorise rules (MemoryRoundTests on iOS), on a seeded random so every run is the same. */
class MemoryRoundTest {
    private val verse = listOf(
        "Amazing grace, how sweet the sound,",
        "That saved a wretch like me!",
        "I once was lost, but now am found,",
        "Was blind, but now I see.",
    )
    private val hymnWords = listOf(
        "Amazing grace how sweet the sound That saved a wretch like me",
        "I once was lost but now am found Was blind but now I see",
        "Twas grace that taught my heart to fear And grace my fears relieved",
        "How precious did that grace appear The hour I first believed",
        "Through many dangers toils and snares I have already come",
        "Tis grace hath brought me safe thus far And grace will lead me home",
    ).flatMap { it.split(' ') }

    private fun round(level: MemoryLevel = MemoryLevel.Half, seed: Int = 7) =
        MemoryRound(verse, level, hymnWords, random = Random(seed))

    private fun answer(r: MemoryRound) = r.current?.let(r::token)?.answer ?: ""

    @Test fun hidesAShareOfTheWordsAtEachLevel() {
        val words = verse.flatMap { it.split(' ') }.size
        assertEquals(ceil(words * 0.25).toInt(), round(MemoryLevel.Few).targets.size)
        assertEquals(ceil(words * 0.5).toInt(), round(MemoryLevel.Half).targets.size)
        assertEquals(words, round(MemoryLevel.All).targets.size)
        assertEquals(round(MemoryLevel.All).targets.sorted(), round(MemoryLevel.All).targets)
    }

    @Test fun answersDropPunctuationButKeepApostrophes() {
        assertEquals("Lord", MemoryRound.answer("Lord,"))
        assertEquals("o’er", MemoryRound.answer("o’er"))
        assertEquals("me", MemoryRound.answer("me!"))
        assertEquals("cafe", MemoryRound.key("Café"))
    }

    @Test fun blanksShowNoLettersUntilHelped() {
        val r = round()
        for (t in r.targets) {
            assertEquals(0, r.shownLetters(t))
            assertTrue(r.shownPrefix(t).isEmpty())
        }
    }

    @Test fun fourChipsIncludeTheAnswerAndNoDuplicates() {
        for (seed in 1..20) {
            val r = round(MemoryLevel.All, seed)
            while (true) {
                val current = r.current ?: break
                val answer = r.token(current)!!.answer
                assertEquals(4, r.choices.size)
                assertTrue(r.choices.any { MemoryRound.key(it) == MemoryRound.key(answer) })
                assertEquals(r.choices.size, r.choices.map(MemoryRound::key).toSet().size)
                for (neighbour in listOfNotNull(r.token(current - 1), r.token(current + 1))) {
                    if (MemoryRound.key(neighbour.answer) == MemoryRound.key(answer)) continue
                    assertFalse(r.choices.any { MemoryRound.key(it) == MemoryRound.key(neighbour.answer) })
                }
                r.choose(answer)
            }
            assertTrue(r.isComplete)
        }
    }

    @Test fun temptationPrefersSameLetterLengthRhymeAndStanza() {
        assertEquals(5, MemoryRound.temptation("glory", "grace", upcoming = false, stanza = false))
        assertEquals(4, MemoryRound.temptation("place", "grace", upcoming = false, stanza = false))
        assertEquals(7, MemoryRound.temptation("peace", "grace", upcoming = true, stanza = true))
        assertEquals(0, MemoryRound.temptation("hallelujah", "grace", upcoming = false, stanza = false))
    }

    @Test fun rightFirstTimeScoresAndBuildsAStreak() {
        val r = round(MemoryLevel.All)
        assertEquals(MemoryRound.Outcome.Right(milestone = false, earnedHint = false), r.choose(answer(r)))
        assertEquals(10, r.score)
        assertEquals(1, r.streak)
        r.choose(answer(r))
        assertEquals(22, r.score)
        assertEquals(MemoryRound.Outcome.Right(milestone = true, earnedHint = true), r.choose(answer(r)))
        assertEquals(3, r.streak)
        assertEquals(MemoryRound.STARTING_HINTS + 1, r.hints)
        assertEquals(1, r.hintsEarned)
    }

    @Test fun hintsCapAtThreeButMilestonesStillCount() {
        val r = round(MemoryLevel.All)
        repeat(6) { r.choose(answer(r)) }
        assertEquals(3, r.hints)
        repeat(2) { r.choose(answer(r)) }
        assertEquals(MemoryRound.Outcome.Right(milestone = true, earnedHint = false), r.choose(answer(r)))
        assertEquals(MemoryRound.MAX_HINTS, r.hints)
    }

    @Test fun wrongPickEndsTheStreakAndIsRuledOut() {
        val r = round(MemoryLevel.All)
        r.choose(answer(r))
        val wrong = r.choices.first { MemoryRound.key(it) != MemoryRound.key(answer(r)) }
        assertEquals(MemoryRound.Outcome.Wrong(revealed = false), r.choose(wrong))
        assertEquals(0, r.streak)
        assertTrue(r.isRuledOut(wrong))
        assertEquals(0, r.shownLetters(r.current!!))
        r.choose(answer(r))
        assertEquals(15, r.score)
        assertEquals(1, r.firstTry)
    }

    @Test fun secondMissShowsTheFirstLetterFree() {
        val r = round(MemoryLevel.All)
        val wrong = r.choices.filter { MemoryRound.key(it) != MemoryRound.key(answer(r)) }
        r.choose(wrong[0])
        assertEquals(MemoryRound.Outcome.Wrong(revealed = true), r.choose(wrong[1]))
        val current = r.current!!
        assertEquals(1, r.shownLetters(current))
        assertEquals(MemoryRound.STARTING_HINTS, r.hints)
        val first = MemoryRound.key(r.shownPrefix(current))
        for (choice in r.choices) if (!MemoryRound.key(choice).startsWith(first)) assertTrue(r.isRuledOut(choice))
        assertFalse(r.isRuledOut(answer(r)))
    }

    @Test fun hintRevealsALetterRulesOutMismatchesAndKeepsTheStreak() {
        val r = round(MemoryLevel.All)
        r.choose(answer(r))
        r.choose(answer(r))
        assertTrue(r.canHint)
        assertTrue(r.hint())
        assertEquals(MemoryRound.STARTING_HINTS - 1, r.hints)
        assertEquals(1, r.hintsUsed)
        assertEquals(2, r.streak)
        val current = r.current!!
        assertEquals(1, r.shownPrefix(current).length)
        for (choice in r.choices) if (!MemoryRound.key(choice).startsWith(MemoryRound.key(r.shownPrefix(current)))) assertTrue(r.isRuledOut(choice))
        assertFalse(r.canHint)
        r.choose(answer(r))
        assertEquals(10 + 12 + 5, r.score)
        assertEquals(2, r.streak)
    }

    @Test fun hintNeverShowsTheWholeWord() {
        val r = MemoryRound(listOf("To God be the glory"), MemoryLevel.All, hymnWords + listOf("To", "God", "be", "the", "glory"), random = Random(3))
        while (r.canHint) r.hint()
        assertTrue(r.shownLetters(r.current!!) <= 1)
    }

    @Test fun starsFollowFirstTryShare() {
        val perfect = round(MemoryLevel.All)
        while (true) { val c = perfect.current ?: break; perfect.choose(perfect.token(c)!!.answer) }
        assertEquals(3, perfect.stars)
        assertEquals(1.0, perfect.accuracy, 0.0)
        assertEquals(100, perfect.firstTryPercent)

        val helped = round(MemoryLevel.All)
        var misses = 0
        while (true) {
            val c = helped.current ?: break
            val right = helped.token(c)!!.answer
            if (misses < helped.targets.size / 2) {
                helped.choices.firstOrNull { MemoryRound.key(it) != MemoryRound.key(right) }?.let { helped.choose(it); misses++ }
            }
            helped.choose(right)
        }
        assertEquals(1, helped.stars)
        assertEquals(0, round().stars)
    }

    @Test fun aNewRoundNeverHidesExactlyTheSameWords() {
        val first = round(MemoryLevel.Half, seed = 11)
        for (seed in 1..30) {
            val next = MemoryRound(verse, MemoryLevel.Half, hymnWords, avoiding = first.targets, random = Random(seed))
            assertTrue(next.targets != first.targets)
        }
    }

    @Test fun progressKeepsTheBestStarsAndMarksLearned() {
        val store = MemoryStore()
        val progress = MemoryProgress(store, "english", 108)
        assertFalse(progress.isLearned(0))
        assertTrue(progress.record(2, 0, MemoryLevel.Half))
        assertFalse(progress.record(1, 0, MemoryLevel.Half))
        assertEquals(2, progress.stars(0, MemoryLevel.Half))
        assertTrue(progress.record(1, 0, MemoryLevel.All))
        assertTrue(progress.isLearned(0))
        assertFalse(progress.isLearned(1))
        assertEquals(1, store.getInt("memorise.stars.english.108.0.3"))
        assertEquals(listOf("few", "half", "most", "all"), MemoryLevel.entries.map { it.analyticsName })
    }
}
