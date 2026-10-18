// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.MemoryPart
import com.mDev.AdventPraise.analytics.MemoryReplay
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.MemoryProgress
import com.mDev.AdventPraise.extras.MemoryRound
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.random.Random

/** What the game does beyond its own state: haptics, VoiceOver/TalkBack lines and analytics. */
interface MemoriseEffects {
    fun haptic(event: HapticEvent)
    fun announce(message: String)
    fun track(event: AnalyticsEvent)

    companion object {
        /** The app's haptics and analytics; [announce] posts to the screen reader. */
        fun live(announce: (String) -> Unit) = object : MemoriseEffects {
            override fun haptic(event: HapticEvent) = Haptics.play(event)
            override fun announce(message: String) = announce(message)
            override fun track(event: AnalyticsEvent) = Analytics.track(event)
        }
    }
}

/**
 * Memorise a verse (MemoryGameView's state and actions, apart from drawing):
 * the stanza and level, the round in play, the note under the scoreboard, the
 * word that just dropped in, the chips' shakes and the stars revealed on the
 * completion card. Rules and scoring are [MemoryRound]'s.
 *
 * Timed beats (the glow fading, the note going, stars one by one) run on
 * [scope]; [reduceMotion] shows the stars at once.
 */
class MemoriseGame(
    val hymn: Hymn,
    /** The hymnal's word for its refrain ("Chorus", "Refrain"…). */
    private val chorusLabel: String,
    private val progress: MemoryProgress,
    private val scope: CoroutineScope,
    private val effects: MemoriseEffects,
    private val reduceMotion: Boolean = false,
    private val random: Random = Random.Default,
) {
    /** A short line under the scoreboard: a streak milestone, a free letter. */
    data class Note(
        val text: String,
        val symbol: Symbol,
        /** The blank the note is about; it goes when that blank is filled. */
        val blank: Int? = null,
        val id: String = UUID.randomUUID().toString(),
    ) {
        enum class Symbol { Hint, Streak, Letter }
    }

    var blockIndex by mutableIntStateOf(0)
        private set
    var level by mutableStateOf(MemoryLevel.Few)
        private set
    var round by mutableStateOf(MemoryRound(emptyList(), MemoryLevel.Few, emptyList(), random = random))
        private set
    /** Bumped on every move: the round is mutable, so readers observe this. */
    var moves by mutableIntStateOf(0)
        private set
    /** The word that just dropped in, glowing for a moment. */
    var justFilled by mutableStateOf<Int?>(null)
        private set
    /** Shakes per chip for the current blank, counted up on each wrong pick. */
    val shakes = mutableStateMapOf<String, Int>()
    var note by mutableStateOf<Note?>(null)
        private set
    /** Stars revealed so far on the completion card. */
    var starsShown by mutableIntStateOf(0)
        private set
    /** The round's stars beat the stanza's best. */
    var isNewBest by mutableStateOf(false)
        private set

    val blocks: List<Block> get() = hymn.blocks
    val block: Block? get() = blocks.getOrNull(blockIndex)
    val blockName: String get() = block?.let(::name) ?: ""

    fun name(block: Block): String = when (block) {
        is Block.Verse -> "Verse ${block.number}"
        is Block.Chorus -> chorusLabel
    }

    fun isLearned(block: Int): Boolean = progress.isLearned(block)
    fun bestStars(level: MemoryLevel): Int = progress.stars(blockIndex, level)

    private val part: MemoryPart get() = if (block is Block.Chorus) MemoryPart.Chorus else MemoryPart.Verse

    // MARK: Pickers

    /** Starts the first round (`onAppear`). */
    fun start() = newRound()

    fun selectBlock(index: Int) {
        effects.haptic(HapticEvent.Selection)
        if (index == blockIndex || index !in blocks.indices) return
        blockIndex = index
        newRound()
    }

    fun selectLevel(option: MemoryLevel) {
        effects.haptic(HapticEvent.Selection)
        changeLevel(option)
    }

    private fun changeLevel(option: MemoryLevel) {
        if (option == level) return
        level = option
        newRound()
    }

    // MARK: Rounds

    fun newRound() {
        val lines = block?.lines.orEmpty()
        val words = blocks.flatMap { it.lines }.flatMap { line -> line.split(' ').filter { it.isNotEmpty() } }
        // Fresh blanks every start: Play again never deals the same hidden words
        // twice running. Another verse just starts clean.
        val sameVerse = round.lines.map { line -> line.joinToString(" ") { it.text } } == lines
        round = MemoryRound(lines, level, words, avoiding = if (sameVerse) round.targets else emptyList(), random = random)
        shakes.clear()
        justFilled = null
        note = null
        starsShown = 0
        isNewBest = false
        moves++
        if (round.targets.isNotEmpty()) effects.track(AnalyticsEvent.MemoryGameStarted(part, level, round.targets.size))
    }

    /** A button on the completion card. */
    fun replay(reason: MemoryReplay) {
        effects.haptic(HapticEvent.Selection)
        when (reason) {
            MemoryReplay.Again -> {
                effects.track(AnalyticsEvent.MemoryRoundReplayed(part, level, reason))
                newRound()
            }
            MemoryReplay.NextLevel -> {
                val next = level.harder ?: return
                effects.track(AnalyticsEvent.MemoryRoundReplayed(part, next, reason))
                changeLevel(next)
            }
            MemoryReplay.NextBlock -> {
                effects.track(AnalyticsEvent.MemoryRoundReplayed(part, level, reason))
                if (blockIndex + 1 < blocks.size) {
                    blockIndex += 1
                    newRound()
                }
            }
            MemoryReplay.StartOver -> {
                effects.track(AnalyticsEvent.MemoryRoundReplayed(part, MemoryLevel.Few, reason))
                changeLevel(MemoryLevel.Few)
            }
        }
    }

    // MARK: Moves

    /** Picks [choice] for the next blank. */
    fun pick(choice: String) {
        val current = round.current ?: return
        val playing = round
        when (val outcome = playing.choose(choice)) {
            is MemoryRound.Outcome.Right -> {
                shakes.clear()
                justFilled = current
                if (outcome.milestone) {
                    note = Note(
                        if (outcome.earnedHint) "${playing.streak} in a row, +1 hint" else "${playing.streak} in a row",
                        if (outcome.earnedHint) Note.Symbol.Hint else Note.Symbol.Streak,
                    )
                } else if (note?.blank == current) {
                    note = null
                }
                moves++
                if (outcome.milestone) effects.track(AnalyticsEvent.MemoryStreakReached(part, level, playing.streak))
                // A tap per word, a firmer one for a milestone; success is kept for the stanza.
                if (playing.isComplete) {
                    finish()
                } else {
                    effects.haptic(if (outcome.milestone) HapticEvent.ThresholdCrossed else HapticEvent.LightImpact)
                    val streakPhrase = "$choice. Streak ${playing.streak}."
                    effects.announce(if (outcome.earnedHint) "$streakPhrase Hint earned." else streakPhrase)
                }
                val shownNote = note?.id
                scope.launch {
                    delay(GLOW_MS)
                    if (justFilled == current) justFilled = null
                    delay(NOTE_MS)
                    if (outcome.milestone && note?.id == shownNote) note = null
                }
            }
            is MemoryRound.Outcome.Wrong -> {
                shakes[choice] = (shakes[choice] ?: 0) + 1
                if (outcome.revealed) note = Note("First letter shown", Note.Symbol.Letter, blank = current)
                moves++
                effects.haptic(HapticEvent.Error)
                effects.announce(if (outcome.revealed) "Not $choice. ${hintPhrase(current)}" else "Not $choice.")
            }
        }
    }

    /** Spends a hint on the next blank. */
    fun hint() {
        val current = round.current ?: return
        if (!round.hint()) return
        moves++
        effects.haptic(HapticEvent.SoftImpact)
        effects.track(AnalyticsEvent.MemoryHintUsed(part, level, round.hints))
        val left = round.choices.count { !round.isRuledOut(it) }
        effects.announce(hintPhrase(current) + " " + "$left words left to choose from.")
    }

    /** The stanza is done: stars one by one, the best kept, learned noted. */
    private fun finish() {
        val finished = round
        val stars = finished.stars
        isNewBest = progress.record(stars, blockIndex, level)
        effects.track(AnalyticsEvent.MemoryGameCompleted(part, level, finished.score, finished.bestStreak,
            finished.firstTryPercent, finished.hintsUsed, stars))
        if (level == MemoryLevel.All) effects.track(AnalyticsEvent.MemoryVerseLearned(part, stars))
        effects.haptic(HapticEvent.Success)
        val headline = if (level == MemoryLevel.All) "$blockName learned by heart." else "$blockName finished, round ${level.round} of 4."
        effects.announce("$headline ${if (stars == 1) "1 star." else "$stars stars."} Score ${finished.score}.")
        if (reduceMotion) {
            starsShown = stars
            return
        }
        scope.launch {
            for (shown in 1..stars) {
                delay(if (shown == 1) FIRST_STAR_MS else NEXT_STAR_MS)
                if (round !== finished || !finished.isComplete) return@launch
                starsShown = shown
                effects.haptic(HapticEvent.LightImpact)
            }
        }
    }

    private fun hintPhrase(index: Int): String {
        val shown = round.shownPrefix(index)
        return if (shown.isEmpty()) "" else "It starts $shown."
    }

    // MARK: Text

    /**
     * A hidden word. Nothing shown: a fixed-width blank, so its length gives
     * nothing away. Letters revealed: "Lo__," at the word's true length.
     */
    fun blank(token: MemoryRound.Token): String {
        var remaining = round.shownLetters(token.index)
        if (remaining <= 0) {
            val trailing = token.text.reversed().takeWhile { !it.isLetter() && !it.isDigit() }.reversed()
            return "_____$trailing"
        }
        val out = StringBuilder()
        for (c in token.text) {
            if (c.isLetter() || c.isDigit()) {
                if (remaining > 0) { out.append(c); remaining-- } else out.append('_')
            } else {
                out.append(c)
            }
        }
        return out.toString()
    }

    /** What the screen reader says for the verse: "blank" for each hidden word. */
    val spokenVerse: String
        get() = round.lines.flatten().joinToString(" ") { token ->
            if (!round.isHidden(token.index)) return@joinToString token.text
            val shown = round.shownPrefix(token.index)
            val blank = if (token.index == round.current) "next blank" else "blank"
            if (shown.isEmpty()) blank else "$blank starting $shown"
        }

    /** A line under the stars: what they mean, and whether they're a best. */
    val verdict: String
        get() {
            val line = when (round.stars) {
                3 -> "Word perfect, or near enough."
                2 -> "Well remembered. Three stars for nine in ten first time."
                else -> "Finished. Play again for more first-time words."
            }
            return if (isNewBest) "$line A new best." else line
        }

    companion object {
        const val GLOW_MS = 650L
        const val NOTE_MS = 1_600L
        const val FIRST_STAR_MS = 500L
        const val NEXT_STAR_MS = 320L
    }
}
