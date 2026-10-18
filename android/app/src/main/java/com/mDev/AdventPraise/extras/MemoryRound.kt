package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.settings.KeyValueStore
import java.text.Normalizer
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.random.Random

/** How many of the verse's words each level hides; the rounds of a stanza (MemoryRound.Level on iOS). */
enum class MemoryLevel(val rawValue: Int, val label: String, val fraction: Double) {
    Few(0, "A few", 0.25),
    Half(1, "Half", 0.5),
    Most(2, "Most", 0.75),
    All(3, "All", 1.0);

    /** 1 to 4: how the picker and the completion card count the rounds. */
    val round: Int get() = rawValue + 1
    val harder: MemoryLevel? get() = entries.getOrNull(rawValue + 1)
    /** iOS sends `String(describing:)`: "few", "half", "most", "all". */
    val analyticsName: String get() = name.lowercase()
}

/**
 * The rules of the Memorise game, apart from the view (MemoryRound.swift).
 * A round is one verse or chorus with some words hidden. The singer fills
 * the blanks in reading order by picking the next word from four chips: the
 * right word and three tempting others.
 *
 * Nothing is given away by default. Hints are earned: a round starts with
 * one; every third word in a row earns another (up to three). A hint shows
 * the next letter and rules out every chip that can't fit; the word then
 * scores less but the streak holds. A wrong chip is ruled out and ends the
 * streak; the second wrong pick on one blank shows its first letter free.
 *
 * Scoring: right first time scores 10, plus 2 per word of the current
 * streak (bonus capped at 10); after a hint or a mistake, 5. A finished
 * stanza earns one to three stars by its first-try share.
 *
 * A mutable game state (iOS's is a mutating struct); `random` makes rounds
 * repeatable in tests.
 */
class MemoryRound(
    lines: List<String>,
    val level: MemoryLevel,
    hymnWords: List<String>,
    /** The hidden words of the round this one replaces: a new round never hides exactly those again when it can. */
    avoiding: List<Int> = emptyList(),
    private val random: Random = Random.Default,
) {
    data class Token(
        /** Position across the whole block. */
        val index: Int,
        /** As printed, with its punctuation: "Lord,". */
        val text: String,
        /** What the chips show and the answer is matched on: "Lord". */
        val answer: String,
    ) {
        val isWord: Boolean get() = answer.any { it.isLetter() }
    }

    sealed interface Outcome {
        /** Right. `milestone`: the streak reached a multiple of three; `earnedHint`: and there was room for another. */
        data class Right(val milestone: Boolean, val earnedHint: Boolean) : Outcome
        /** Wrong. `revealed`: a second miss showed the first letter. */
        data class Wrong(val revealed: Boolean) : Outcome
    }

    val lines: List<List<Token>>
    /** Hidden word positions, in reading order. */
    val targets: List<Int>
    /** Every distinct word in the hymn, for distractors. */
    private val pool: List<String>
    /** Keys of the words in this stanza. */
    private val stanzaKeys: Set<String>
    private val tokens: Map<Int, Token>

    private val filledSet = mutableSetOf<Int>()
    private val revealedMap = mutableMapOf<Int, Int>()
    private val ruledOutSet = mutableSetOf<String>()

    val filled: Set<Int> get() = filledSet
    /** Letters revealed per hidden word, by hint or by a second miss. */
    val revealed: Map<Int, Int> get() = revealedMap
    /** Hints in hand. */
    var hints = STARTING_HINTS; private set
    var hintsUsed = 0; private set
    var hintsEarned = 0; private set
    var choices: List<String> = emptyList(); private set
    var score = 0; private set
    var streak = 0; private set
    var bestStreak = 0; private set
    var firstTry = 0; private set
    /** Wrong picks on the current blank. */
    var missesOnCurrent = 0; private set
    /** The current word has had a hint (it still scores, less). */
    var isCurrentHinted = false; private set

    init {
        var next = 0
        this.lines = lines.map { line ->
            line.split(' ').filter { it.isNotEmpty() }.map { word -> Token(next++, word, answer(word)) }
        }
        tokens = this.lines.flatten().associateBy { it.index }
        val words = this.lines.flatten().filter { it.isWord }.map { it.index }
        val count = if (words.isEmpty()) 0 else maxOf(1, ceil(words.size * level.fraction).toInt())
        targets = pickTargets(words, count, avoiding, random)
        val seen = mutableSetOf<String>()
        pool = hymnWords.map(::answer).filter { w -> w.any { it.isLetter() } && seen.add(key(w)) }
        stanzaKeys = this.lines.flatten().filter { it.isWord }.map { key(it.answer) }.toSet()
        makeChoices()
    }

    // State

    /** The blank to fill next. */
    val current: Int? get() = targets.firstOrNull { it !in filledSet }
    val isComplete: Boolean get() = targets.isNotEmpty() && current == null
    val progress: Double get() = if (targets.isEmpty()) 0.0 else filledSet.size.toDouble() / targets.size
    /** The share of hidden words found first time, with no hint. */
    val accuracy: Double get() = if (targets.isEmpty()) 0.0 else firstTry.toDouble() / targets.size
    /** One to three stars for a finished stanza; none before. */
    val stars: Int
        get() = if (!isComplete) 0 else if (accuracy >= 0.9) 3 else if (accuracy >= 0.6) 2 else 1
    val canHint: Boolean get() = current != null && hints > 0 && !isCurrentFullyShown
    /** `first_try_percent`: the first-try share, rounded. */
    val firstTryPercent: Int get() = Math.round(accuracy * 100).toInt()

    /** All but the last letter is showing: a hint would give the word away. */
    private val isCurrentFullyShown: Boolean
        get() {
            val current = current ?: return true
            return (revealedMap[current] ?: 0) >= maxOf(letterCount(current) - 1, 1)
        }

    fun token(index: Int): Token? = tokens[index]

    fun isHidden(index: Int): Boolean = index in targets && index !in filledSet

    /** Letters to show in a blank: those revealed by hints or misses, never the whole word. */
    fun shownLetters(index: Int): Int = minOf(revealedMap[index] ?: 0, maxOf(letterCount(index) - 1, 1))

    /** The letters shown so far of a hidden word: "Lo" for "Lord" after two hints. */
    fun shownPrefix(index: Int): String {
        val token = token(index) ?: return ""
        return token.answer.filter { it.isLetter() || it.isDigit() }.take(shownLetters(index))
    }

    private fun letterCount(index: Int): Int = token(index)?.answer?.count { it.isLetter() || it.isDigit() } ?: 0

    fun isRuledOut(choice: String): Boolean = key(choice) in ruledOutSet

    // Moves

    /** Picks `word` for the current blank. */
    fun choose(word: String): Outcome {
        val current = current ?: return Outcome.Wrong(false)
        val token = token(current) ?: return Outcome.Wrong(false)
        if (key(word) != key(token.answer)) {
            streak = 0
            missesOnCurrent += 1
            ruledOutSet += key(word)
            var revealedLetter = false
            if (missesOnCurrent == 2 && (revealedMap[current] ?: 0) == 0) {
                revealedMap[current] = 1
                revealedLetter = true
                ruleOutMismatches()
            }
            return Outcome.Wrong(revealedLetter)
        }
        filledSet += current
        var milestone = false
        var earned = false
        if (missesOnCurrent > 0 || isCurrentHinted) {
            score += 5
        } else {
            score += 10 + 2 * minOf(streak, 5)
            streak += 1
            firstTry += 1
            bestStreak = maxOf(bestStreak, streak)
            milestone = streak % STREAK_PER_HINT == 0
            if (milestone && hints < MAX_HINTS) {
                hints += 1
                hintsEarned += 1
                earned = true
            }
        }
        missesOnCurrent = 0
        isCurrentHinted = false
        makeChoices()
        return Outcome.Right(milestone, earned)
    }

    /** Spends a hint: reveals the next letter and rules out chips that can't fit. False when none can be spent. */
    fun hint(): Boolean {
        if (!canHint) return false
        val current = current ?: return false
        hints -= 1
        hintsUsed += 1
        isCurrentHinted = true
        revealedMap[current] = (revealedMap[current] ?: 0) + 1
        ruleOutMismatches()
        return true
    }

    private fun ruleOutMismatches() {
        val current = current ?: return
        val prefix = key(shownPrefix(current))
        if (prefix.isEmpty()) return
        for (choice in choices) if (!key(choice).startsWith(prefix)) ruledOutSet += key(choice)
    }

    // Chips

    /**
     * The right word and three others that could pass for it, scored by
     * [temptation]. One of the verse's later hidden words is always in the
     * running; the words beside the blank are left out; distractors take
     * the answer's capital, so case never gives it away.
     */
    private fun makeChoices() {
        ruledOutSet.clear()
        val current = current
        val answer = current?.let { token(it)?.answer }
        if (current == null || answer == null) {
            choices = emptyList()
            return
        }
        val answerKey = key(answer)
        val neighbours = listOfNotNull(token(current - 1), token(current + 1)).map { key(it.answer) }.toSet()
        val upcoming = targets.filter { it > current && it !in filledSet }.mapNotNull { token(it) }.map { key(it.answer) }.toSet()

        val seen = mutableSetOf(answerKey)
        val ranked = mutableListOf<Pair<String, Int>>()
        for (word in pool.shuffled(random)) {
            val k = key(word)
            if (k in neighbours || !seen.add(k)) continue
            ranked += word to temptation(k, answerKey, k in upcoming, k in stanzaKeys)
        }
        // Stable on a shuffled list: ties fall in a fresh order every blank.
        val sorted = ranked.sortedByDescending { it.second }

        val picks = mutableListOf<String>()
        sorted.firstOrNull { key(it.first) in upcoming }?.let { picks += it.first }
        // The best few, then chance among them, so a verse's chips vary.
        val rest = sorted.filter { it.first !in picks }
        picks += rest.take(5).shuffled(random).take(3 - picks.size).map { it.first }
        for (candidate in rest.drop(5)) if (picks.size < 3) picks += candidate.first

        choices = (picks.map { matchCase(it, answer) } + answer).shuffled(random)
    }

    companion object {
        /** Hints in hand at the start of a round. */
        const val STARTING_HINTS = 1
        /** The most hints that can be held. */
        const val MAX_HINTS = 3
        /** Every streak of this many first-try words earns a hint. */
        const val STREAK_PER_HINT = 3

        /** How much `word` could pass for `answer` (both folded keys). */
        fun temptation(word: String, answer: String, upcoming: Boolean, stanza: Boolean): Int {
            var score = 0
            if (word.firstOrNull() == answer.firstOrNull()) score += 3
            val gap = abs(word.length - answer.length)
            score += if (gap <= 1) 2 else if (gap == 2) 1 else 0
            if (answer.length >= 3 && word.length >= 3 && word.takeLast(2) == answer.takeLast(2)) score += 2
            if (upcoming) score += 2
            if (stanza) score += 1
            return score
        }

        /** `count` random positions from `words`, in reading order. If that repeats `previous`, one is swapped. */
        fun pickTargets(words: List<Int>, count: Int, previous: List<Int>, random: Random = Random.Default): List<Int> {
            val picked = words.shuffled(random).take(count).toMutableList()
            if (picked.sorted() == previous.sorted() && picked.isNotEmpty()) {
                val unused = words.filter { it !in picked }
                if (unused.isNotEmpty()) picked[random.nextInt(picked.size)] = unused[random.nextInt(unused.size)]
            }
            return picked.sorted()
        }

        /** "Lord," → "Lord"; "o’er" keeps its apostrophe. */
        fun answer(text: String): String = text.trim { trimmable(it) }

        /** Matching ignores case and accents. */
        fun key(word: String): String =
            Normalizer.normalize(word.lowercase(), Normalizer.Form.NFD).replace(marks, "")

        private val marks = Regex("\\p{M}+")

        private fun trimmable(c: Char): Boolean {
            if (c.isWhitespace()) return true
            return when (Character.getType(c).toByte()) {
                Character.CONNECTOR_PUNCTUATION, Character.DASH_PUNCTUATION, Character.START_PUNCTUATION,
                Character.END_PUNCTUATION, Character.INITIAL_QUOTE_PUNCTUATION, Character.FINAL_QUOTE_PUNCTUATION,
                Character.OTHER_PUNCTUATION, Character.MATH_SYMBOL, Character.CURRENCY_SYMBOL,
                Character.MODIFIER_SYMBOL, Character.OTHER_SYMBOL -> true
                else -> false
            }
        }

        private fun matchCase(word: String, answer: String): String {
            val first = word.firstOrNull() ?: return word
            val target = answer.firstOrNull() ?: return word
            if (word == "I") return word
            val head = if (target.isUpperCase()) first.uppercase() else first.lowercase()
            return head + word.drop(1)
        }
    }
}

/**
 * What a singer has earned on each stanza: the best stars at each level,
 * and whether the stanza is learned by heart (finished with every word
 * hidden). Keys as iOS: "memorise.stars.<hymnal>.<hymn>.<block>.<level>".
 */
class MemoryProgress(private val store: KeyValueStore, private val hymnal: String, private val hymn: Int) {
    fun stars(block: Int, level: MemoryLevel): Int = store.getInt(key(block, level)) ?: 0

    /** True once the stanza has been finished with every word hidden. */
    fun isLearned(block: Int): Boolean = stars(block, MemoryLevel.All) > 0

    /** Keeps `stars` if they beat the best so far. True when they're new. */
    fun record(stars: Int, block: Int, level: MemoryLevel): Boolean {
        if (stars <= stars(block, level)) return false
        store.putInt(key(block, level), stars)
        return true
    }

    private fun key(block: Int, level: MemoryLevel) = "memorise.stars.$hymnal.$hymn.$block.${level.rawValue}"
}
