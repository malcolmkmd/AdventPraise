//
//  MemoryRound.swift
//  Advent Praise
//
//  The rules of the Memorise game, apart from the view. A round is one verse
//  or chorus with some of its words hidden. The singer fills the blanks in
//  reading order by picking the next word from a few chips: the right word
//  and plausible others from the same hymn.
//
//  Scoring: a word right first time scores 10, plus 2 for each word of the
//  current streak (bonus capped at 10). A word found after a mistake or a
//  hint scores 5 and ends the streak. Each mistake reveals one more letter.
//

import Foundation

struct MemoryRound {
    /// How many of the verse's words each level hides.
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

    let lines: [[Token]]
    /// Hidden word positions, in reading order.
    let targets: [Int]
    /// Every distinct word in the hymn, for distractors.
    private let pool: [String]

    private(set) var filled: Set<Int> = []
    /// Letters revealed per hidden word beyond the first-letter setting.
    private(set) var hints: [Int: Int] = [:]
    private(set) var choices: [String] = []
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var firstTry = 0
    /// The current word has had a mistake or a hint.
    private(set) var isCurrentMissed = false

    static let empty = MemoryRound(lines: [], level: .few, hymnWords: [])

    init(lines: [String], level: Level, hymnWords: [String]) {
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
        targets = Array(words.shuffled().prefix(count)).sorted()

        var seen = Set<String>()
        pool = hymnWords.map(Self.answer).filter { $0.contains { $0.isLetter } && seen.insert(Self.key($0)).inserted }
        makeChoices()
    }

    // MARK: State

    /// The blank to fill next.
    var current: Int? { targets.first { !filled.contains($0) } }
    var isComplete: Bool { !targets.isEmpty && current == nil }
    var progress: Double { targets.isEmpty ? 0 : Double(filled.count) / Double(targets.count) }

    func token(_ index: Int) -> Token? {
        for line in lines { if let token = line.first(where: { $0.index == index }) { return token } }
        return nil
    }

    func isHidden(_ index: Int) -> Bool { targets.contains(index) && !filled.contains(index) }

    /// Letters to show in a blank: the first (if asked for) plus any hints,
    /// never the whole word.
    func shownLetters(_ index: Int, firstLetters: Bool) -> Int {
        let letters = token(index)?.answer.filter { $0.isLetter || $0.isNumber }.count ?? 0
        let wanted = (firstLetters ? 1 : 0) + hints[index, default: 0]
        return min(wanted, max(letters - 1, firstLetters ? 1 : 0))
    }

    // MARK: Moves

    /// Picks `word` for the current blank. True if it was right.
    mutating func choose(_ word: String) -> Bool {
        guard let current, let token = token(current) else { return false }
        guard Self.key(word) == Self.key(token.answer) else {
            isCurrentMissed = true
            streak = 0
            hints[current, default: 0] += 1
            return false
        }
        filled.insert(current)
        if isCurrentMissed {
            score += 5
        } else {
            score += 10 + 2 * min(streak, 5)
            streak += 1
            firstTry += 1
            bestStreak = max(bestStreak, streak)
        }
        isCurrentMissed = false
        makeChoices()
        return true
    }

    /// Reveals one more letter of the current word. Ends the streak.
    mutating func hint() {
        guard let current else { return }
        isCurrentMissed = true
        streak = 0
        hints[current, default: 0] += 1
    }

    /// The right word and up to three others: at most one later hidden word
    /// of this verse (it's coming, so it tempts), then hymn words of a
    /// similar length, then any. Distractors take the answer's capital, so
    /// case never gives it away.
    private mutating func makeChoices() {
        guard let current, let answer = token(current)?.answer else { choices = []; return }
        var seen: Set<String> = [Self.key(answer)]
        var picks: [String] = []
        let upcoming = targets.filter { $0 > current && !filled.contains($0) }.compactMap { token($0)?.answer }
        let similar = pool.filter { abs($0.count - answer.count) <= 2 }
        for word in Array(upcoming.shuffled().prefix(1)) + similar.shuffled() + pool.shuffled() where picks.count < 3 {
            if seen.insert(Self.key(word)).inserted { picks.append(Self.matchCase(word, to: answer)) }
        }
        choices = (picks + [answer]).shuffled()
    }

    // MARK: Words

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
