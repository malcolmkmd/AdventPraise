//
//  PurchaseCancelReviewTests.swift
//  AdventPraiseTests
//
//  The sheet after a cancelled Pro purchase: once per install, never for
//  Pro, and never when the gentle rating prompt has asked or is waiting.
//

import Foundation
import Testing
@testable import Advent_Praise

@Suite("Purchase-cancel review")
struct PurchaseCancelReviewDecisionTests {
    @Test func showsOnceForAFreeUserWhoHasNotBeenAsked() {
        #expect(PurchaseCancelReviewDecision.show(isPro: false, alreadyShown: false, gentleAsked: false, gentlePending: false))
        #expect(!PurchaseCancelReviewDecision.show(isPro: false, alreadyShown: true, gentleAsked: false, gentlePending: false))
    }

    @Test func neverForProOrWhenTheGentlePromptIsInTheWay() {
        #expect(!PurchaseCancelReviewDecision.show(isPro: true, alreadyShown: false, gentleAsked: false, gentlePending: false))
        #expect(!PurchaseCancelReviewDecision.show(isPro: false, alreadyShown: false, gentleAsked: true, gentlePending: false))
        #expect(!PurchaseCancelReviewDecision.show(isPro: false, alreadyShown: false, gentleAsked: false, gentlePending: true))
    }
}

@MainActor
@Suite("Purchase-cancel review wiring")
struct PurchaseCancelReviewCenterTests {
    private func prompt() -> ReviewPrompt {
        let defaults = UserDefaults(suiteName: "PurchaseCancelReview.\(UUID().uuidString)")!
        return ReviewPrompt(defaults: defaults, version: "7.3")
    }

    private func earnGentleAsk(_ prompt: ReviewPrompt) {
        prompt.handle(.appOpened(launch: .cold))
        prompt.handle(.appOpened(launch: .warm))
        for n in 1...3 { prompt.handle(.favouriteToggled(number: n, isFavourite: true)) }
    }

    @Test func theSheetShowsOnceAndThenTheGentlePromptStaysQuiet() {
        let prompt = prompt()
        let center = PurchaseCancelReviewCenter()
        center.consider(isPro: false, prompt: prompt)
        #expect(center.isPresented)
        #expect(prompt.purchaseCancelReviewShown)
        #expect(prompt.pending == nil)
        center.answered(.notNow)
        #expect(!center.isPresented)

        center.consider(isPro: false, prompt: prompt)
        #expect(!center.isPresented)

        earnGentleAsk(prompt)
        #expect(prompt.pending == nil)
    }

    @Test func aWaitingGentlePromptBlocksItAndAnAskedOneDoesToo() {
        let waiting = prompt()
        earnGentleAsk(waiting)
        #expect(waiting.isGentlePending)
        let center = PurchaseCancelReviewCenter()
        center.consider(isPro: false, prompt: waiting)
        #expect(!center.isPresented)
        #expect(!waiting.purchaseCancelReviewShown)

        let asked = prompt()
        earnGentleAsk(asked)
        asked.answered(.thirdFavourite, .notNow)
        #expect(asked.hasAskedGently)
        center.consider(isPro: false, prompt: asked)
        #expect(!center.isPresented)
    }

    @Test func theEventsNameTheOutcome() {
        #expect(AnalyticsEvent.purchaseCancelReviewShown.name == "purchase_cancel_review_shown")
        let answered = AnalyticsEvent.purchaseCancelReviewAnswered(.review)
        #expect(answered.name == "purchase_cancel_review_answered")
        #expect(answered.properties["outcome"] as? String == "review")
        #expect(AnalyticsEvent.purchaseCancelReviewAnswered(.notNow).properties["outcome"] as? String == "not_now")
        #expect(AnalyticsEvent.purchaseCancelReviewAnswered(.dismissed).properties["outcome"] as? String == "dismissed")
    }

    @Test func proIsNeverAsked() {
        let prompt = prompt()
        let center = PurchaseCancelReviewCenter()
        center.consider(isPro: true, prompt: prompt)
        #expect(!center.isPresented)
        #expect(!prompt.purchaseCancelReviewShown)
    }
}
