//
//  PurchaseConfig.swift
//  Advent Praise
//
//  The App Store products, straight through StoreKit 2. Everything here
//  must match App Store Connect for app id1015021132 (STOREKIT_STATUS.md
//  lists exactly what to create there).
//
//  Every hymnal is free from 7.0. The hymnal non-consumables sold in 6.x are
//  no longer sold or checked; Restore purchases still re-syncs them.
//
//  Pro (the player beyond its free plays, church mode with AirPlay, the
//  pitch pipe and unlimited Memorise) is one non-consumable, bought once.
//  Owning it is Pro: there is no server and no entitlement layer, the app
//  reads `Transaction.currentEntitlements`. Playlists and the service
//  planner are free for everyone. There is no subscription and no trial.
//  The price is never written here: the paywall reads it from the App Store.
//
//  Tips are one-off consumables. They unlock nothing, and they live on the
//  Support Advent Praise screen in More, not on the paywall.
//
//  Local testing: StoreKit/Products.storekit (ZAR) is the StoreKit
//  configuration of the shared scheme's Debug Run only; StoreKit/AdventPraise-USD.storekit
//  has the same products in US dollars.
//

import Foundation

enum PurchaseConfig {
    // MARK: Pro

    /// Pro: one-time, non-consumable. The only way to buy it.
    static let proProductID = "ap_pro_lifetime"

    // MARK: Tips

    /// One-off consumables, cheapest first. Each unlocks nothing.
    static let tips: [TipDefinition] = [
        TipDefinition(productID: "ap_tip_amen", name: "Amen", blurb: "A quiet thank you", systemImage: "heart.fill"),
        TipDefinition(productID: "ap_tip_hallelujah", name: "Hallelujah", blurb: "Keeps the hymns ringing", systemImage: "music.note"),
        TipDefinition(productID: "ap_tip_hosanna", name: "Hosanna", blurb: "Carries Advent Praise further", systemImage: "sparkles"),
    ]

    static var tipProductIDs: [String] { tips.map(\.productID) }

    /// Every product the app sells, for one `Product.products(for:)` call.
    static var allProductIDs: [String] { [proProductID] + tipProductIDs }
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
