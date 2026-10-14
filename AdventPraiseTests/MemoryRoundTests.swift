//
//  MemoryRoundTests.swift
//  AdventPraiseTests
//
//  The Memorise rules: blanks give nothing away, chips are tempting, hints
//  are earned by streaks and rule out chips that can't fit, a second miss
//  shows the first letter, and a finished stanza earns stars.
//

import Foundation
import Testing
@testable import Advent_Praise

struct MemoryRoundTests {
    private let verse = [
        "Amazing grace, how sweet the sound,",
        "That saved a wretch like me!",
        "I once was lost, but now am found,",
        "Was blind, but now I see.",
    ]
    private let hymnWords = [
        "Amazing grace how sweet the sound That saved a wretch like me",
        "I once was lost but now am found Was blind but now I see",
        "Twas grace that taught my heart to fear And grace my fears relieved",
        "How precious did that grace appear The hour I first believed",
        "Through many dangers toils and snares I have already come",
        "Tis grace hath brought me safe thus far And grace will lead me home",
    ].flatMap { $0.split(separator: " ").map(String.init) }

    private func round(_ level: MemoryRound.Level = .half) -> MemoryRound {
        MemoryRound(lines: verse, level: level, hymnWords: hymnWords)
    }

    private func answer(_ round: MemoryRound) -> String {
        round.current.flatMap(round.token)?.answer ?? ""
    }

    @Test func hidesAShareOfTheWordsAtEachLevel() {
        let words = verse.flatMap { $0.split(separator: " ") }.count
        #expect(round(.few).targets.count == Int((Double(words) * 0.25).rounded(.up)))
        #expect(round(.half).targets.count == Int((Double(words) * 0.5).rounded(.up)))
        #expect(round(.all).targets.count == words)
        #expect(round(.all).targets == round(.all).targets.sorted())
    }

    @Test func blanksShowNoLettersUntilHelped() {
        let r = round()
        for target in r.targets {
            #expect(r.shownLetters(target) == 0)
            #expect(r.shownPrefix(target).isEmpty)
        }
    }

    @Test func fourChipsIncludeTheAnswerAndNoDuplicates() {
        var r = round(.all)
        while let current = r.current {
            let answer = r.token(current)!.answer
            #expect(r.choices.count == 4)
            #expect(r.choices.contains { MemoryRound.key($0) == MemoryRound.key(answer) })
            #expect(Set(r.choices.map(MemoryRound.key)).count == r.choices.count)
            // The words beside the blank never appear: they'd read as a repeat.
            for neighbour in [current - 1, current + 1].compactMap(r.token) {
                #expect(!r.choices.contains { MemoryRound.key($0) == MemoryRound.key(neighbour.answer) })
            }
            r.choose(answer)
        }
        #expect(r.isComplete)
    }

    @Test func temptationPrefersSameLetterLengthRhymeAndStanza() {
        let base = MemoryRound.temptation(of: "glory", beside: "grace", upcoming: false, stanza: false)
        #expect(base == 3 + 2) // g, five letters
        #expect(MemoryRound.temptation(of: "place", beside: "grace", upcoming: false, stanza: false) == 2 + 2) // length, rhyme
        #expect(MemoryRound.temptation(of: "peace", beside: "grace", upcoming: true, stanza: true) == 2 + 2 + 2 + 1)
        #expect(MemoryRound.temptation(of: "hallelujah", beside: "grace", upcoming: false, stanza: false) == 0)
    }

    @Test func rightFirstTimeScoresAndBuildsAStreak() {
        var r = round(.all)
        let first = r.choose(answer(r))
        #expect(first == .right(milestone: false, earnedHint: false))
        #expect(r.score == 10)
        #expect(r.streak == 1)
        r.choose(answer(r))
        #expect(r.score == 10 + 12)
        let third = r.choose(answer(r))
        #expect(third == .right(milestone: true, earnedHint: true))
        #expect(r.streak == 3)
        #expect(r.hints == MemoryRound.startingHints + 1)
        #expect(r.hintsEarned == 1)
    }

    @Test func hintsCapAtThreeButMilestonesStillCount() {
        var r = round(.all)
        for _ in 0..<6 { r.choose(answer(r)) }
        #expect(r.hints == 3)
        for _ in 0..<2 { r.choose(answer(r)) }
        let ninth = r.choose(answer(r))
        #expect(ninth == .right(milestone: true, earnedHint: false))
        #expect(r.hints == MemoryRound.maxHints)
    }

    @Test func wrongPickEndsTheStreakAndIsRuledOut() {
        var r = round(.all)
        r.choose(answer(r))
        let wrong = r.choices.first { MemoryRound.key($0) != MemoryRound.key(answer(r)) }!
        let miss = r.choose(wrong)
        #expect(miss == .wrong(revealed: false))
        #expect(r.streak == 0)
        #expect(r.isRuledOut(wrong))
        #expect(r.shownLetters(r.current!) == 0)
        r.choose(answer(r))
        #expect(r.score == 10 + 5)
        #expect(r.firstTry == 1)
    }

    @Test func secondMissShowsTheFirstLetterFree() {
        var r = round(.all)
        let wrong = r.choices.filter { MemoryRound.key($0) != MemoryRound.key(answer(r)) }
        r.choose(wrong[0])
        let second = r.choose(wrong[1])
        #expect(second == .wrong(revealed: true))
        let current = r.current!
        #expect(r.shownLetters(current) == 1)
        #expect(r.hints == MemoryRound.startingHints) // free, not spent
        let first = MemoryRound.key(r.shownPrefix(current))
        for choice in r.choices where !MemoryRound.key(choice).hasPrefix(first) {
            #expect(r.isRuledOut(choice))
        }
        #expect(!r.isRuledOut(answer(r)))
    }

    @Test func hintRevealsALetterRulesOutMismatchesAndKeepsTheStreak() {
        var r = round(.all)
        r.choose(answer(r))
        r.choose(answer(r))
        #expect(r.canHint)
        let hinted = r.hint()
        #expect(hinted)
        #expect(r.hints == MemoryRound.startingHints - 1)
        #expect(r.hintsUsed == 1)
        #expect(r.streak == 2)
        let current = r.current!
        #expect(r.shownPrefix(current).count == 1)
        for choice in r.choices where !MemoryRound.key(choice).hasPrefix(MemoryRound.key(r.shownPrefix(current))) {
            #expect(r.isRuledOut(choice))
        }
        #expect(!r.canHint) // none left
        r.choose(answer(r))
        #expect(r.score == 10 + 12 + 5)
        #expect(r.streak == 2) // kept, not extended
    }

    @Test func hintNeverShowsTheWholeWord() {
        var r = MemoryRound(lines: ["To God be the glory"], level: .all, hymnWords: hymnWords + ["To", "God", "be", "the", "glory"])
        // "To": one letter at most, whatever is spent.
        while r.canHint { r.hint() }
        #expect(r.shownLetters(r.current!) <= 1)
    }

    @Test func starsFollowFirstTryShare() {
        var perfect = round(.all)
        while let current = perfect.current { perfect.choose(perfect.token(current)!.answer) }
        #expect(perfect.stars == 3)
        #expect(perfect.accuracy == 1)

        var helped = round(.all)
        var misses = 0
        while let current = helped.current {
            let right = helped.token(current)!.answer
            if misses < helped.targets.count / 2,
               let wrong = helped.choices.first(where: { MemoryRound.key($0) != MemoryRound.key(right) }) {
                helped.choose(wrong)
                misses += 1
            }
            helped.choose(right)
        }
        #expect(helped.stars == 1)
        #expect(round().stars == 0) // not finished
    }

    @Test func progressKeepsTheBestStarsAndMarksLearned() {
        let defaults = UserDefaults(suiteName: "MemoryRoundTests.\(UUID().uuidString)")!
        let progress = MemoryProgress(hymnal: "english", hymn: 108, defaults: defaults)
        #expect(!progress.isLearned(block: 0))
        #expect(progress.record(stars: 2, block: 0, level: .half))
        #expect(!progress.record(stars: 1, block: 0, level: .half))
        #expect(progress.stars(block: 0, level: .half) == 2)
        #expect(!progress.isLearned(block: 0))
        #expect(progress.record(stars: 1, block: 0, level: .all))
        #expect(progress.isLearned(block: 0))
        #expect(!progress.isLearned(block: 1))
    }
}
