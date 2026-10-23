import Foundation
import Testing
@testable import Advent_Praise

@Suite("Rating ask eligibility")
struct ReviewEligibilityTests {
    let v = "7.2"
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func afterSessions(_ n: Int) -> ReviewEligibility {
        var e = ReviewEligibility()
        for _ in 0..<n { _ = e.recordSession(version: "0", now: t0) }
        return e
    }

    @Test func neverInTheFirstSession() {
        var e = afterSessions(1)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == nil)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == nil)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == nil)
        #expect(e.finishedPlayback(.accompanimentFinished, version: v, now: t0) == nil)
    }

    @Test func thirdFavouriteAsks() {
        var e = afterSessions(2)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == nil)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == nil)
        #expect(e.recordFavouriteAdded(version: v, now: t0) == .thirdFavourite)
    }

    @Test func fifthSessionAsks() {
        var e = afterSessions(4)
        #expect(e.recordSession(version: v, now: t0) == .fifthSession)
    }

    @Test func finishedPlaybackAsksAfterRealUse() {
        let e = afterSessions(2)
        #expect(e.finishedPlayback(.accompanimentFinished, version: v, now: t0) == .accompanimentFinished)
        #expect(e.finishedPlayback(.sheetMusicFinished, version: v, now: t0) == .sheetMusicFinished)
    }

    @Test func oncePerVersion() {
        var e = afterSessions(5)
        e.markAsked(version: v)
        #expect(e.finishedPlayback(.accompanimentFinished, version: v, now: t0) == nil)
        #expect(e.recordSession(version: v, now: t0) == nil)
        // A new version may ask again.
        #expect(e.finishedPlayback(.accompanimentFinished, version: "7.3", now: t0) == .accompanimentFinished)
    }

    @Test func notStraightAfterPaywallOrPurchase() {
        var e = afterSessions(5)
        e.recordPaywallOrPurchase(now: t0)
        #expect(e.finishedPlayback(.accompanimentFinished, version: v, now: t0.addingTimeInterval(60)) == nil)
        let later = t0.addingTimeInterval(ReviewEligibility.paywallCooldown + 1)
        #expect(e.finishedPlayback(.accompanimentFinished, version: v, now: later) == .accompanimentFinished)
    }

    @Test func survivesSaving() throws {
        var e = afterSessions(3)
        e.markAsked(version: v)
        let back = try JSONDecoder().decode(ReviewEligibility.self, from: JSONEncoder().encode(e))
        #expect(back == e)
    }
}

@MainActor @Suite("Rating ask wiring")
struct ReviewPromptTests {
    private func makePrompt() -> ReviewPrompt {
        let d = UserDefaults(suiteName: "ReviewPromptTests.\(UUID())")!
        return ReviewPrompt(defaults: d, version: "7.2")
    }

    @Test func favouritesQueueTheAskOnce() {
        let p = makePrompt()
        p.handle(.appOpened(launch: .cold)); p.handle(.appOpened(launch: .warm))
        for n in 1...3 { p.handle(.favouriteToggled(number: n, isFavourite: true)) }
        #expect(p.pending == .thirdFavourite)
        p.answered(.thirdFavourite, .notNow)
        p.handle(.favouriteToggled(number: 4, isFavourite: true))
        #expect(p.pending == nil)
    }

    @Test func unfavouritingDoesNotCount() {
        let p = makePrompt()
        p.handle(.appOpened(launch: .cold)); p.handle(.appOpened(launch: .warm))
        for n in 1...3 { p.handle(.favouriteToggled(number: n, isFavourite: false)) }
        #expect(p.pending == nil)
    }

    @Test func paywallBlocksAndClearsTheAsk() {
        let p = makePrompt()
        p.handle(.appOpened(launch: .cold)); p.handle(.appOpened(launch: .warm))
        p.handle(.paywallViewed(feature: .player, context: .reader))
        p.handle(.accompanimentCompleted(number: 1, tempo: .medium, verses: 1))
        #expect(p.pending == nil)
    }

    @Test func shortSheetMusicVisitDoesNotCount() {
        let p = makePrompt()
        let t = Date()
        p.handle(.appOpened(launch: .cold)); p.handle(.appOpened(launch: .warm))
        p.handle(.sheetMusicOpened(number: 1, access: .pro), now: t)
        p.sheetMusicClosed(now: t.addingTimeInterval(10))
        #expect(p.pending == nil)
        p.handle(.sheetMusicOpened(number: 1, access: .pro), now: t)
        p.sheetMusicClosed(now: t.addingTimeInterval(ReviewPrompt.sheetMusicMinimum))
        #expect(p.pending == .sheetMusicFinished)
    }
}
