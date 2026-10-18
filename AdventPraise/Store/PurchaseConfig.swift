//
//  PurchaseConfig.swift
//  Advent Praise
//
//  The products and the RevenueCat set-up. Everything here must match App
//  Store Connect for app id1015021132 and the "Advent Praise" project in
//  RevenueCat (docs/revenuecat.md lists the dashboard set-up).
//
//  Every hymnal is free from 7.0. The hymnal non-consumables sold in 6.x are
//  no longer sold or checked; Restore purchases still re-syncs them.
//
//  Pro (the player beyond its free plays, church mode with AirPlay, sheet
//  music, the pitch pipe and unlimited Memorise) is the RevenueCat
//  entitlement `pro`. It is bought once: `ap_pro_lifetime`, the Lifetime
//  package of the default offering. There is no subscription and no trial.
//  The price is never written here: the paywall reads it from the offering.
//
//  MIDI Piano (`ap_midi_unlock`) was sold beside Pro in 7.0.1 only. From
//  7.0.3 it is no longer offered, and RevenueCat attaches it to `pro` too:
//  whoever bought it has all of Pro, and Restore still finds it.
//
//  Tips are one-off consumables. They unlock nothing, belong to no
//  entitlement, and live on the Support Advent Praise screen in More.
//
//  Local testing: StoreKit/Products.storekit (ZAR) is the StoreKit
//  configuration of the shared scheme's Debug Run; StoreKit/AdventPraise-USD.storekit
//  has the same products in US dollars. RevenueCat only accepts Xcode's
//  test transactions once the StoreKit test certificate is uploaded to the
//  iOS app in RevenueCat (see docs/revenuecat.md).
//

import Foundation

enum PurchaseConfig {
    // MARK: RevenueCat

    /// The iOS app's public SDK key in RevenueCat ("appl_…"). Client-side,
    /// safe to ship. Empty: purchases are off (DEBUG builds then use the
    /// preview store, so the paywall can still be exercised).
    static let revenueCatAPIKey = ""

    /// The entitlement that is Pro.
    static let proEntitlement = "pro"

    /// The offering the paywall shows. nil: RevenueCat's current (default) offering.
    static let offeringID: String? = nil

    // MARK: Pro

    /// Pro: one-time, non-consumable. The only unlock on sale.
    static let proProductID = "ap_pro_lifetime"

    /// MIDI Piano, 7.0.1's cheaper unlock. Not sold from 7.0.3; RevenueCat
    /// attaches it to `pro`, so owning it is Pro.
    static let legacyMIDIProductID = "ap_midi_unlock"

    /// Every product that opens the `pro` entitlement in RevenueCat. Only
    /// `proProductID` is offered on the paywall.
    static let proEntitlementProductIDs: Set<String> = [proProductID, legacyMIDIProductID]

    // MARK: Tips

    /// One-off consumables, cheapest first. Each unlocks nothing.
    static let tips: [TipDefinition] = [
        TipDefinition(productID: "ap_tip_amen", name: "Amen", blurb: "A quiet thank you", systemImage: "heart.fill"),
        TipDefinition(productID: "ap_tip_hallelujah", name: "Hallelujah", blurb: "Keeps the hymns ringing", systemImage: "music.note"),
        TipDefinition(productID: "ap_tip_hosanna", name: "Hosanna", blurb: "Carries Advent Praise further", systemImage: "sparkles"),
    ]

    static var tipProductIDs: [String] { tips.map(\.productID) }
}

/// A tip as the config names it; the store adds the App Store price.
struct TipDefinition: Identifiable, Sendable {
    let productID: String
    let name: LocalizedStringResource
    let blurb: LocalizedStringResource
    /// The SF Symbol on its row.
    let systemImage: String
    var id: String { productID }

    /// With its App Store price, for the Support screen.
    func option(price: String) -> TipOption {
        TipOption(id: productID, name: name, blurb: blurb, systemImage: systemImage, price: price)
    }
}

// MARK: - Entitlements

/// What this customer has, as RevenueCat reports it, and what that opens.
/// Pure values, so the rules can be tested without RevenueCat: the `pro`
/// entitlement opens everything.
struct Entitlements: Equatable, Sendable {
    /// Active RevenueCat entitlements ("pro").
    var active: Set<String> = []
    /// Product IDs bought on this Apple Account (Pro, MIDI Piano and the 6.x
    /// hymnals alike). Tips are not counted.
    var purchased: Set<String> = []

    static let none = Entitlements()

    /// Pro, however it was bought (Pro, or 7.0.1's MIDI Piano).
    var isPro: Bool { active.contains(PurchaseConfig.proEntitlement) }
    /// The MIDI player beyond its free plays.
    var unlocksPlayer: Bool { isPro }
    /// Anything was ever bought (for Restore's message).
    var hasPurchases: Bool { !purchased.isEmpty }

    /// Whether `feature` is open. Everything is Pro.
    func unlocks(_ feature: ProFeature) -> Bool { isPro }
}
