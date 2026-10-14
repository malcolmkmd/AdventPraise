//
//  MemoriseJourney.swift
//  APVerifyUITests
//
//  features/memorise.md: tray → Memorise; plays a whole "A few hidden"
//  round of 191 verse 1 the way a singer would (tap a chip, see whether it
//  went in), uses the starting hint, and checks the rules a user can see:
//  blanks give nothing away, a wrong chip is ruled out and ends the streak,
//  a hint shows a letter, the finished stanza earns stars, and the best is
//  kept on the level chip.
//

import XCTest

final class MemoriseJourney: JourneyCase {
    override var journeyName: String { "memorise" }

    /// Score, streak, hints, filled, total, read off the scoreboard's label:
    /// "Score 12, streak 3, 1 hints, 4 of 9 words found".
    private struct Board: CustomStringConvertible {
        var score = 0, streak = 0, hints = 0, filled = 0, total = 0
        var description: String { "score \(score) streak \(streak) hints \(hints) \(filled)/\(total)" }
    }

    private var scoreboard: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch
    }

    private func board() -> Board {
        let numbers = scoreboard.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 5 else { return Board() }
        return Board(score: numbers[0], streak: numbers[1], hints: numbers[2], filled: numbers[3], total: numbers[4])
    }

    private var verse: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'next blank'")).firstMatch
    }

    /// The word chips: one-word buttons below "Which word comes next?" other
    /// than Hint. (The reader's Lectern stays in the tree under the sheet;
    /// its labels all have spaces, a chip's word never does.)
    private func chips() -> [XCUIElement] {
        let header = app.staticTexts["Which word comes next?"]
        guard header.exists else { return [] }
        let top = header.frame.maxY
        return app.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.minY > top && $0.label != "Hint" && !$0.label.isEmpty && !$0.label.contains(" ")
        }
    }

    func testPlayARoundEarnStarsKeepBest() {
        launch()
        openHymnTray()
        tap(app.otherElements["lectern.hymnTray"].buttons["Memorise"], "the tray's Memorise tile")
        expect(app.navigationBars["Memorise"].waitForExistence(timeout: 6), "Memorise opens")
        expect(scoreboard.waitForExistence(timeout: 4), "the scoreboard is there")
        settle()
        var b = board()
        note("start: \(b)")
        expect(b.total > 0 && b.filled == 0, "a round starts with blanks to fill")
        expect(b.hints == 1, "one hint to start (got \(b.hints))")
        expect(verse.exists && !verse.label.contains("next blank starting"), "blanks give nothing away (no first letter)")
        expect(app.buttons["A few hidden"].exists, "the level chips are there (A few hidden selected)")
        expect(!app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'First letter'")).firstMatch.exists,
               "the First letters toggle is gone")
        let firstChips = chips()
        note("chips: \(firstChips.map(\.label))")
        expect(firstChips.count >= 2, "word chips are dealt")
        shot("round-start")

        var wrongSeen = false, hintUsed = false, taps = 0
        while b.filled < b.total, taps < 200 {
            // Spend the starting hint on the second blank.
            if !hintUsed, b.filled == 1, b.hints > 0 {
                let before = b
                tap(app.buttons["Hint"], "Hint")
                settle(0.5)
                b = board()
                hintUsed = true
                expect(b.hints == before.hints - 1, "a hint is spent (\(before.hints) → \(b.hints))")
                expect(verse.label.contains("next blank starting"), "the hint shows the next letter")
                let out = chips().filter { ($0.value as? String) == "ruled out" }.count
                note("chips ruled out by the hint: \(out)")
                shot("hint-used")
            }
            let candidates = chips().filter { $0.isEnabled && ($0.value as? String) != "ruled out" }
            guard let chip = candidates.first else { note("FAIL no chip left to tap at \(b)"); break }
            let label = chip.label
            let before = b
            chip.tap(); taps += 1
            settle(0.35)
            b = board()
            if b.filled > before.filled {
                note("'\(label)' right → \(b)")
            } else {
                note("'\(label)' wrong → \(b)")
                if !wrongSeen {
                    wrongSeen = true
                    let ruled = app.buttons[label]
                    expect(ruled.exists && (ruled.value as? String) == "ruled out", "a wrong chip is ruled out")
                    expect(b.streak == 0, "a wrong chip ends the streak")
                    shot("wrong-chip-ruled-out")
                }
            }
            if b.streak == 3 { shot("streak-3") }
        }
        if !wrongSeen { note("no wrong pick happened this round (chips tapped first were all right)") }
        expect(b.filled == b.total && b.total > 0, "every blank filled (\(b.filled)/\(b.total)) in \(taps) taps")

        // The completion card: stars revealed one by one, the next round offered.
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'round 1 of 4'")).firstMatch
        expect(title.waitForExistence(timeout: 5), "the card says the stanza's round 1 of 4 is done")
        settle(2.0)
        let stars = app.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH ' star' OR label ENDSWITH ' stars'")).firstMatch
        expect(stars.exists, "the card shows stars")
        note("stars: \(stars.label)")
        expect(app.buttons["Next round: half hidden"].exists, "it offers the next round (half hidden)")
        expect(app.buttons["Play again"].exists, "and Play again")
        shot("round-complete-stars")

        // The best is kept on the level chip.
        let best = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A few hidden, best '")).firstMatch
        if !best.exists { app.swipeDown() }
        expect(best.waitForExistence(timeout: 3), "the A few chip now shows the best stars")
        note("level chip: \(best.label)")
        tap(app.buttons["Next round: half hidden"], "Next round: half hidden")
        settle()
        b = board()
        expect(app.buttons["Half hidden"].isSelected || b.filled == 0, "a fresh round on Half hidden")
        shot("next-round-half")
    }
}
