//
//  EntitlementsTests.swift
//  AdventPraiseTests
//
//  The rules behind the unlocks, with no RevenueCat: the `pro` entitlement
//  opens everything; the product IDs live buyers own are kept; the
//  storefront takes Pro from the offering and judges each screen on its
//  own; and the purchase events keep the names PostHog already has.
//

import Foundation
import Testing
@testable import Advent_Praise

struct EntitlementsTests {
    private let allFeatures: [ProFeature] = [.player, .airPlay, .mirroring, .support, .sheetMusic]

    @Test func nothingActiveOpensNothing() {
        let none = Entitlements.none
        #expect(!none.isPro)
        #expect(!none.unlocksPlayer)
        #expect(!none.hasPurchases)
        for feature in allFeatures {
            #expect(!none.unlocks(feature), "\(feature) should be locked")
        }
    }

    @Test func theProEntitlementOpensEverything() {
        let pro = Entitlements(active: [PurchaseConfig.proEntitlement], purchased: [PurchaseConfig.proProductID])
        #expect(pro.isPro)
        #expect(pro.unlocksPlayer)
        for feature in allFeatures {
            #expect(pro.unlocks(feature), "\(feature) should be open with Pro")
        }
    }

    /// 7.0.1's MIDI Piano buyers: RevenueCat attaches ap_midi_unlock to
    /// `pro`, so they have all of Pro, sheet music and AirPlay included.
    @Test func aMidiPianoBuyerIsPro() {
        let midi = Entitlements(active: [PurchaseConfig.proEntitlement], purchased: [PurchaseConfig.legacyMIDIProductID])
        #expect(midi.isPro)
        #expect(midi.unlocks(.airPlay))
        #expect(midi.unlocks(.sheetMusic))
        #expect(midi.unlocks(.player))
    }

    /// RevenueCat's entitlement decides, not the product list.
    @Test func productsWithoutTheEntitlementOpenNothing() {
        let owned = Entitlements(active: [], purchased: ["ap_hymnal_tswana", PurchaseConfig.proProductID])
        #expect(!owned.isPro)
        #expect(owned.hasPurchases)
        #expect(!owned.unlocks(.player))
        #expect(!Entitlements(active: ["something_else"]).isPro)
    }

    @Test func theLiveProductIDsAreKept() {
        #expect(PurchaseConfig.proEntitlement == "pro")
        #expect(PurchaseConfig.proProductID == "ap_pro_lifetime")
        #expect(PurchaseConfig.legacyMIDIProductID == "ap_midi_unlock")
        #expect(PurchaseConfig.proEntitlementProductIDs == ["ap_pro_lifetime", "ap_midi_unlock"])
        #expect(PurchaseConfig.tipProductIDs == ["ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"])
        #expect(PurchaseConfig.offeringID == nil, "the paywall shows RevenueCat's current offering")
    }

    /// The local StoreKit configuration still carries every live product.
    @Test func theStoreKitConfigurationHasEveryProduct() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "StoreKit/Products.storekit")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try #require(json["products"] as? [[String: Any]])
        let ids = Set(products.compactMap { $0["productID"] as? String })
        for id in PurchaseConfig.proEntitlementProductIDs.union(PurchaseConfig.tipProductIDs) {
            #expect(ids.contains(id), "\(id) is missing from Products.storekit")
        }
    }

    @Test func featuresReportThemselvesToAnalyticsByName() {
        #expect(ProFeature.player.analyticsName == "player")
        #expect(ProFeature.airPlay.analyticsName == "air_play")
        #expect(ProFeature.mirroring.analyticsName == "mirroring")
        #expect(ProFeature.support.analyticsName == "support")
        #expect(ProFeature.sheetMusic.analyticsName == "sheet_music")
    }
}

/// What the offering and the tip prices produced.
struct StorefrontTests {
    private let tips = PurchaseConfig.tipProductIDs
    private let lifetime = OfferingPackage(id: "$rc_lifetime", productID: "ap_pro_lifetime", price: "R199.99")

    private func prices(_ ids: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, "R1.00") })
    }

    @Test func proComesFromTheOfferingsLifetimePackage() {
        let offering = OfferingSnapshot(id: "default", packages: [lifetime])
        let front = Storefront.from(offering: offering, tipPrices: prices(tips))
        #expect(!front.proFailed)
        #expect(!front.tipsFailed)
        #expect(!front.anyFailed)
        #expect(front.proOption?.id == "ap_pro_lifetime")
        #expect(front.proOption?.package.id == "$rc_lifetime")
        #expect(front.proOption?.price == "R199.99")
        #expect(front.tips.map(\.id) == tips, "cheapest first, in the config's order")
    }

    /// MIDI Piano is no longer sold, even if an offering still lists it.
    @Test func midiPianoIsNeverOffered() {
        let midi = OfferingPackage(id: "midi", productID: "ap_midi_unlock", price: "R79.99")
        let both = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [midi, lifetime]), tipPrices: [:])
        #expect(both.proOption?.id == "ap_pro_lifetime")
        let midiOnly = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [midi]), tipPrices: [:])
        #expect(midiOnly.proFailed)
    }

    @Test func theLifetimePackageWinsOverAnotherPackageOfPro() {
        let custom = OfferingPackage(id: "pro_custom", productID: "ap_pro_lifetime", price: "R199.99")
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [custom, lifetime]), tipPrices: [:])
        #expect(front.proOption?.package.id == "$rc_lifetime")
    }

    @Test func noOfferingLeavesTheTips() {
        let front = Storefront.from(offering: nil, tipPrices: prices(tips))
        #expect(front.proFailed)
        #expect(!front.tipsFailed)
        #expect(front.tips.count == 3)
    }

    @Test func tipsMissingLeavesThePaywall() {
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [lifetime]), tipPrices: [:])
        #expect(!front.proFailed)
        #expect(front.tipsFailed)
    }

    @Test func oneTipIsEnoughForTheSupportScreen() {
        let front = Storefront.from(offering: nil, tipPrices: prices([tips[1]]))
        #expect(!front.tipsFailed)
        #expect(front.tips.map(\.id) == [tips[1]])
    }

    @Test func aRetryKeepsWhatLoadedBefore() {
        let loaded = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [lifetime]), tipPrices: prices(tips))
        let kept = loaded.keeping(.from(offering: nil, tipPrices: [:]))
        #expect(kept == loaded)
        let empty = Storefront().keeping(loaded)
        #expect(empty == loaded)
    }
}

/// The purchase events keep the names and properties PostHog already has.
struct PurchaseAnalyticsTests {
    @Test func purchaseEvents() {
        let started = AnalyticsEvent.purchaseStarted(product: "ap_pro_lifetime", feature: .player)
        #expect(started.name == "purchase_started")
        #expect(started.properties["product"] as? String == "ap_pro_lifetime")
        #expect(started.properties["feature"] as? String == "player")
        #expect(AnalyticsEvent.purchaseCompleted(product: "ap_pro_lifetime", feature: .sheetMusic).name == "purchase_completed")
        #expect(AnalyticsEvent.purchaseCancelled(product: "ap_pro_lifetime", feature: .airPlay).name == "purchase_cancelled")
        let failed = AnalyticsEvent.purchaseFailed(product: "ap_pro_lifetime", feature: .support, reason: .pending)
        #expect(failed.name == "purchase_failed")
        #expect(failed.properties["reason"] as? String == "pending")
        #expect(PurchaseFailure.notActivated.rawValue == "not_activated")
        #expect(PurchaseFailure.storeError.rawValue == "store_error")
    }

    @Test func restoreAndTipEvents() {
        #expect(AnalyticsEvent.restoreStarted(source: .paywall).properties["source"] as? String == "paywall")
        let restored = AnalyticsEvent.restoreCompleted(foundPurchases: true, proActive: true)
        #expect(restored.name == "restore_completed")
        #expect(restored.properties["found_purchases"] as? Bool == true)
        #expect(restored.properties["pro_active"] as? Bool == true)
        #expect(AnalyticsEvent.restoreFailed.name == "restore_failed")
        #expect(AnalyticsEvent.tipStarted(product: "ap_tip_amen").name == "tip_started")
        #expect(AnalyticsEvent.tipCompleted(product: "ap_tip_amen").properties["product"] as? String == "ap_tip_amen")
        #expect(AnalyticsEvent.tipFailed(product: "ap_tip_amen", reason: .unavailable).name == "tip_failed")
    }

    @Test func paywallEvents() {
        let viewed = AnalyticsEvent.paywallViewed(feature: .sheetMusic, context: .sheetMusic)
        #expect(viewed.name == "paywall_viewed")
        #expect(viewed.properties["feature"] as? String == "sheet_music")
        #expect(AnalyticsEvent.paywallDismissed(feature: .player, context: .reader, outcome: .unlocked)
            .properties["outcome"] as? String == "unlocked")
    }
}
