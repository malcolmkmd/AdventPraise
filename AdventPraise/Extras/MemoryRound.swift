//
//  MemoryRound.swift
//  Advent Praise
//
//  The rules of the Memorise game, apart from the view. A round is one verse
//  or chorus with some of its words hidden. The singer fills the blanks in
//  reading order by picking the next word from four chips: the right word
//  and three others chosen to be tempting (the same first letter, a similar
//  length, a rhyme, a word from the same stanza, a word that is coming up).
//
//  Nothing is given away by default: a blank shows no letters and no
//  length. Hints are earned. A round starts with one; every third word in
//  a row earns another (up to three in hand). A hint reveals the next
//  letter of the current word and rules out every chip that can't fit it,
//  so the chips stay honest. A hint keeps the streak but the word scores
//  less. A wrong chip is ruled out and ends the streak; the second wrong
//  pick on one blank shows its first letter free, so nobody gets stuck.
//
//  Scoring: a word right first time scores 10, plus 2 for each word of the
//  current streak (bonus capped at 10). A word found after a hint or a
//  mistake scores 5. A finished stanza earns one to three stars by its
//  first-try share. The four levels hide more words each round; finishing
//  a stanza with every word hidden counts it as learned by heart.
//

import Foundation

struct MemoryRound {
    /// How many of the verse's words each level hides. Levels are the rounds
    /// of a stanza: each one hides more than the last.
    enum Level: Int, CaseIterable, Identifiable {
        case few, half, most, all
        var id: Int { rawValue }

        var name: String {
            switch self {
            case .few: String(localized: "A few")
            case .half: String(localized: "Half")
            case .most: String(localized: "Most")
            case .all: String(localized: "All")
            }
        }

        var fraction: Double {
            switch self {
            case .few: 0.25
            case .half: 0.5
            case .most: 0.75
            case .all: 1
            }
        }

        /// 1 to 4: how the picker and the completion card count the rounds.
        var round: Int { rawValue + 1 }
        var harder: Level? { Level(rawValue: rawValue + 1) }
    }

    struct Token: Identifiable, Hashable {
        /// Position across the whole block.
        let index: Int
        /// As printed, with its punctuation: "Lord,".
        let text: String
        /// What the chips show and the answer is matched on: "Lord".
        let answer: String
        var id: Int { index }
        var isWord: Bool { answer.contains { $0.isLetter } }
    }

    /// Hints in hand at the start of a round.
    static let startingHints = 1
    /// The most hints that can be held.
    static let maxHints = 3
    /// Every streak of this many first-try words earns a hint.
    static let streakPerHint = 3

    let lines: [[Token]]
    /// Hidden word positions, in reading order.
    let targets: [Int]
    /// Every distinct word in the hymn, for distractors.
    private let pool: [String]
    /// Keys of the words in this stanza (shown or hidden).
    private let stanzaKeys: Set<String>

    private(set) var filled: Set<Int> = []
    /// Letters revealed per hidden word, by hint or by a second miss.
    private(set) var revealed: [Int: Int] = [:]
    /// Hints in hand.
    private(set) var hints = MemoryRound.startingHints
    private(set) var hintsUsed = 0
    private(set) var hintsEarned = 0
    private(set) var choices: [String] = []
    /// Chips for the current blank that can't be right: picked wrong, or
    /// ruled out by a revealed letter.
    private(set) var ruledOut: Set<String> = []
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var firstTry = 0
    /// Wrong picks on the current blank.
    private(set) var missesOnCurrent = 0
    /// The current word has had a hint (it still scores, less).
    private(set) var isCurrentHinted = false

    static let empty = MemoryRound(lines: [], level: .few, hymnWords: [])

    /// `avoiding`: the hidden words of the round this one replaces. A new
    /// round never hides exactly the same words again when another choice
    /// exists, so starting or restarting a verse always deals a fresh set.
    init(lines: [String], level: Level, hymnWords: [String], avoiding previous: [Int] = []) {
        var next = 0
        let lines = lines.map { line in
            line.split(separator: " ").map { word in
                defer { next += 1 }
                return Token(index: next, text: String(word), answer: Self.answer(String(word)))
            }
        }
        self.lines = lines
        let words = lines.flatMap { $0 }.filter(\.isWord).map(\.index)
        let count = words.isEmpty ? 0 : max(1, Int((Double(words.count) * level.fraction).rounded(.up)))
        targets = Self.pickTargets(from: words, count: count, avoiding: previous)

        var seen = Set<String>()
        pool = hymnWords.map(Self.answer).filter { $0.contains { $0.isLetter } && seen.insert(Self.key($0)).inserted }
        stanzaKeys = Set(lines.flatMap { $0 }.filter(\.isWord).map { Self.key($0.answer) })
        makeChoices()
    }

    // MARK: State

    /// The blank to fill next.
    var current: Int? { targets.first { !filled.contains($0) } }
    var isComplete: Bool { !targets.isEmpty && current == nil }
    var progress: Double { targets.isEmpty ? 0 : Double(filled.count) / Double(targets.count) }
    /// The share of hidden words found first time, with no hint.
    var accuracy: Double { targets.isEmpty ? 0 : Double(firstTry) / Double(targets.count) }
    /// One to three stars for a finished stanza; none before.
    var stars: Int {
        guard isComplete else { return 0 }
        return accuracy >= 0.9 ? 3 : accuracy >= 0.6 ? 2 : 1
    }
    var canHint: Bool { current != nil && hints > 0 && !isCurrentFullyShown }

    /// All but the last letter is showing: a hint would give the word away.
    private var isCurrentFullyShown: Bool {
        guard let current else { return true }
        return revealed[current, default: 0] >= max(letterCount(current) - 1, 1)
    }

    func token(_ index: Int) -> Token? {
        for line in lines { if let token = line.first(where: { $0.index == index }) { return token } }
        return nil
    }

    func isHidden(_ index: Int) -> Bool { targets.contains(index) && !filled.contains(index) }

    /// Letters to show in a blank: those revealed by hints or misses, never
    /// the whole word.
    func shownLetters(_ index: Int) -> Int {
        min(revealed[index, default: 0], max(letterCount(index) - 1, 1))
    }

    /// The letters shown so far of a hidden word: "Lo" for "Lord" after two hints.
    func shownPrefix(_ index: Int) -> String {
        guard let token = token(index) else { return "" }
        let letters = token.answer.filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(shownLetters(index)))
    }

    private func letterCount(_ index: Int) -> Int {
        token(index)?.answer.filter { $0.isLetter || $0.isNumber }.count ?? 0
    }

    // MARK: Moves

    enum Outcome: Equatable {
        /// Right. `milestone`: the streak reached a multiple of three;
        /// `earnedHint`: and there was room for another hint.
        case right(milestone: Bool, earnedHint: Bool)
        /// Wrong. `revealed`: a second miss showed the first letter.
        case wrong(revealed: Bool)
    }

    /// Picks `word` for the current blank.
    @discardableResult
    mutating func choose(_ word: String) -> Outcome {
        guard let current, let token = token(current) else { return .wrong(revealed: false) }
        guard Self.key(word) == Self.key(token.answer) else {
            streak = 0
            missesOnCurrent += 1
            ruledOut.insert(Self.key(word))
            var revealedLetter = false
            if missesOnCurrent == 2, revealed[current, default: 0] == 0 {
                revealed[current] = 1
                revealedLetter = true
                ruleOutMismatches()
            }
            return .wrong(revealed: revealedLetter)
        }
        filled.insert(current)
        var milestone = false
        var earned = false
        if missesOnCurrent > 0 || isCurrentHinted {
            score += 5
        } else {
            score += 10 + 2 * min(streak, 5)
            streak += 1
            firstTry += 1
            bestStreak = max(bestStreak, streak)
            milestone = streak.isMultiple(of: Self.streakPerHint)
            if milestone, hints < Self.maxHints {
                hints += 1
                hintsEarned += 1
                earned = true
            }
        }
        missesOnCurrent = 0
        isCurrentHinted = false
        makeChoices()
        return .right(milestone: milestone, earnedHint: earned)
    }

    /// Spends a hint: reveals the next letter of the current word and rules
    /// out the chips that can't fit. Keeps the streak; the word scores 5.
    @discardableResult
    mutating func hint() -> Bool {
        guard canHint, let current else { return false }
        hints -= 1
        hintsUsed += 1
        isCurrentHinted = true
        revealed[current, default: 0] += 1
        ruleOutMismatches()
        return true
    }

    private mutating func ruleOutMismatches() {
        guard let current else { return }
        let prefix = Self.key(shownPrefix(current))
        guard !prefix.isEmpty else { return }
        for choice in choices where !Self.key(choice).hasPrefix(prefix) {
            ruledOut.insert(Self.key(choice))
        }
    }

    func isRuledOut(_ choice: String) -> Bool { ruledOut.contains(Self.key(choice)) }

    // MARK: Chips

    /// The right word and three others that could pass for it. Each hymn
    /// word is scored for how tempting it is next to the answer: the same
    /// first letter counts most (so a revealed letter never leaves one chip
    /// standing), then a similar length, a rhyme, a word of this stanza.
    /// One of the verse's later hidden words is always in the running, as
    /// it's coming anyway. The words beside the blank are left out: they'd
    /// read as a plain repeat. Distractors take the answer's capital, so
    /// case never gives it away.
    private mutating func makeChoices() {
        ruledOut = []
        guard let current, let answer = token(current)?.answer else { choices = []; return }
        let answerKey = Self.key(answer)
        let neighbours = Set([current - 1, current + 1].compactMap { token($0) }.map { Self.key($0.answer) })
        let upcoming = Set(targets.filter { $0 > current && !filled.contains($0) }
            .compactMap { token($0) }.map { Self.key($0.answer) })

        var seen: Set<String> = [answerKey]
        var ranked: [(word: String, score: Int)] = []
        for word in pool.shuffled() {
            let key = Self.key(word)
            guard !neighbours.contains(key), seen.insert(key).inserted else { continue }
            ranked.append((word, Self.temptation(of: key, beside: answerKey,
                                                 upcoming: upcoming.contains(key), stanza: stanzaKeys.contains(key))))
        }
        // Stable on a shuffled list: ties fall in a fresh order every blank.
        ranked.sort { $0.score > $1.score }

        var picks: [String] = []
        if let coming = ranked.first(where: { upcoming.contains(Self.key($0.word)) }) {
            picks.append(coming.word)
        }
        // The best few, then chance among them, so a verse's chips vary.
        let rest = ranked.filter { !picks.contains($0.word) }
        let shortlist = Array(rest.prefix(5)).shuffled().prefix(3 - picks.count)
        picks += shortlist.map(\.word)
        for candidate in rest.dropFirst(5) where picks.count < 3 { picks.append(candidate.word) }

        choices = (picks.map { Self.matchCase($0, to: answer) } + [answer]).shuffled()
    }

    /// How much `word` could pass for `answer` (both folded keys).
    static func temptation(of word: String, beside answer: String, upcoming: Bool, stanza: Bool) -> Int {
        var score = 0
        if word.first == answer.first { score += 3 }
        let lengthGap = abs(word.count - answer.count)
        score += lengthGap <= 1 ? 2 : lengthGap == 2 ? 1 : 0
        if answer.count >= 3, word.count >= 3, word.suffix(2) == answer.suffix(2) { score += 2 }
        if upcoming { score += 2 }
        if stanza { score += 1 }
        return score
    }

    // MARK: Words

    /// `count` random positions from `words`, in reading order. If that
    /// repeats `previous`, one hidden word is swapped for a shown one.
    static func pickTargets(from words: [Int], count: Int, avoiding previous: [Int]) -> [Int] {
        var picked = Array(words.shuffled().prefix(count))
        if picked.sorted() == previous.sorted(),
           let out = picked.indices.randomElement(),
           let swap = words.filter({ !picked.contains($0) }).randomElement() {
            picked[out] = swap
        }
        return picked.sorted()
    }

    /// "Lord," → "Lord"; "o’er" keeps its apostrophe.
    static func answer(_ text: String) -> String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces))
    }

    /// Matching ignores case and accents.
    static func key(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func matchCase(_ word: String, to answer: String) -> String {
        guard let first = word.first, let target = answer.first, word != "I" else { return word }
        let head = target.isUppercase ? String(first).uppercased() : String(first).lowercased()
        return head + word.dropFirst()
    }
}

// MARK: - Progress kept between visits

/// What a singer has earned on each stanza: the best stars at each level,
/// and whether the stanza is learned by heart (finished with every word
/// hidden). Plain UserDefaults; a few integers per hymn ever played.
struct MemoryProgress {
    private let defaults: UserDefaults
    private let hymnal: String
    private let hymn: Int

    init(hymnal: String, hymn: Int, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hymnal = hymnal
        self.hymn = hymn
    }

    func stars(block: Int, level: MemoryRound.Level) -> Int {
        defaults.integer(forKey: key(block: block, level: level))
    }

    /// True once the stanza has been finished with every word hidden.
    func isLearned(block: Int) -> Bool { stars(block: block, level: .all) > 0 }

    /// Keeps `stars` if they beat the best so far. True when they're new.
    @discardableResult
    func record(stars: Int, block: Int, level: MemoryRound.Level) -> Bool {
        guard stars > self.stars(block: block, level: level) else { return false }
        defaults.set(stars, forKey: key(block: block, level: level))
        return true
    }

    private func key(block: Int, level: MemoryRound.Level) -> String {
        "memorise.stars.\(hymnal).\(hymn).\(block).\(level.rawValue)"
    }
}
