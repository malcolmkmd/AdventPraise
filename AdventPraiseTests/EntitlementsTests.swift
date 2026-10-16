//
//  EntitlementsTests.swift
//  AdventPraiseTests
//
//  The rules behind the unlocks, with no StoreKit: Pro opens everything,
//  MIDI Piano opens the player and nothing else; and the storefront judges
//  each product on its own, so Pro missing never empties the tips screen.
//

import Foundation
import Testing
@testable import Advent_Praise

struct EntitlementsTests {
    private let pro = PurchaseConfig.proProductID
    private let midi = PurchaseConfig.midiProductID

    @Test func nothingOwnedOpensNothing() {
        let none = Entitlements.none
        #expect(!none.isPro)
        #expect(!none.ownsMIDI)
        #expect(!none.unlocksPlayer)
        for feature in [ProFeature.player, .airPlay, .mirroring, .support] {
            #expect(!none.unlocks(feature), "\(feature) should be locked")
        }
    }

    @Test func proOpensThePlayerAndEverythingElse() {
        let owned = Entitlements(owned: [pro])
        #expect(owned.isPro)
        #expect(!owned.ownsMIDI)
        #expect(owned.unlocksPlayer)
        for feature in [ProFeature.player, .airPlay, .mirroring, .support] {
            #expect(owned.unlocks(feature), "\(feature) should be open with Pro")
        }
    }

    @Test func midiPianoOpensThePlayerAlone() {
        let owned = Entitlements(owned: [midi])
        #expect(!owned.isPro)
        #expect(owned.ownsMIDI)
        #expect(owned.unlocksPlayer)
        #expect(owned.unlocks(.player))
        #expect(!owned.unlocks(.airPlay), "AirPlay and the worship display stay Pro")
        #expect(!owned.unlocks(.mirroring))
        #expect(!owned.unlocks(.support))
    }

    @Test func proAndMidiTogetherIsPro() {
        let owned = Entitlements(owned: [pro, midi])
        #expect(owned.isPro)
        #expect(owned.ownsMIDI)
        #expect(owned.unlocks(.airPlay))
    }

    @Test func sixPointXHymnalsUnlockNothingNew() {
        let owned = Entitlements(owned: ["ap_hymnal_tswana", "ap_tip_amen"])
        #expect(!owned.isPro)
        #expect(!owned.ownsMIDI)
        #expect(!owned.unlocksPlayer)
    }

    @Test func theProductIDsAreTheOnesSold() {
        #expect(PurchaseConfig.midiProductID == "ap_midi_unlock")
        #expect(PurchaseConfig.allProductIDs == ["ap_pro_lifetime", "ap_midi_unlock",
                                                 "ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"])
        #expect(Unlock(productID: "ap_midi_unlock") == .midi)
        #expect(Unlock(productID: "ap_pro_lifetime") == .pro)
        #expect(Unlock(productID: "ap_tip_amen") == nil)
    }
}

/// The App Store answered with some products and not others.
struct StorefrontTests {
    private let pro = PurchaseConfig.proProductID
    private let midi = PurchaseConfig.midiProductID
    private let tips = PurchaseConfig.tipProductIDs

    private func prices(_ ids: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, "R1.00") })
    }

    @Test func everythingLoadedFailsNothing() {
        let front = Storefront.from(prices: prices(PurchaseConfig.allProductIDs))
        #expect(!front.proFailed)
        #expect(!front.midiFailed)
        #expect(!front.tipsFailed)
        #expect(!front.anyFailed)
        #expect(front.proOption?.unlock == .pro)
        #expect(front.midiOption?.unlock == .midi)
        #expect(front.tips.map(\.id) == tips, "cheapest first, in the config's order")
    }

    @Test func proMissingLeavesTheTipsAndMidi() {
        let front = Storefront.from(prices: prices([midi] + tips))
        #expect(front.proFailed)
        #expect(!front.midiFailed)
        #expect(!front.tipsFailed)
        #expect(front.tips.count == 3)
    }

    @Test func tipsMissingLeavesThePaywall() {
        let front = Storefront.from(prices: prices([pro, midi]))
        #expect(!front.proFailed)
        #expect(!front.midiFailed)
        #expect(front.tipsFailed)
    }

    @Test func midiMissingLeavesProAndTheTips() {
        let front = Storefront.from(prices: prices([pro] + tips))
        #expect(!front.proFailed)
        #expect(front.midiFailed, "the player's gate then shows Pro alone")
        #expect(!front.tipsFailed)
    }

    @Test func oneTipIsEnoughForTheSupportScreen() {
        let front = Storefront.from(prices: prices([tips[1]]))
        #expect(!front.tipsFailed)
        #expect(front.tips.map(\.id) == [tips[1]])
        #expect(front.proFailed)
        #expect(front.midiFailed)
    }

    @Test func nothingLoadedFailsEveryScreen() {
        let front = Storefront.from(prices: [:])
        #expect(front.proFailed)
        #expect(front.midiFailed)
        #expect(front.tipsFailed)
    }
}
