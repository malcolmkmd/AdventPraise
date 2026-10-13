//
//  PurchaseConfig.swift
//  Advent Praise
//
//  RevenueCat settings. Everything here must match App Store Connect and the
//  RevenueCat dashboard for app id1015021132.
//
//  Every hymnal is free from 7.0. The hymnal non-consumables sold in 6.x are
//  no longer sold or checked; Restore purchases still re-syncs them.
//
//  Pro (the player beyond its free plays, church mode with AirPlay, the
//  pitch pipe and unlimited Memorise) is one non-consumable, bought once,
//  behind the RevenueCat entitlement below. Playlists and the service
//  planner are free for everyone. There is no subscription
//  and no trial. The price is never written here: the paywall reads it from
//  the RevenueCat offering (or, failing that, the App Store).
//
//  Tips are one-off consumables. They unlock nothing, and they live on the
//  Support Advent Praise screen in More, not on the paywall.
//
//  ⚠️ TODO (Rolo): every product ID below is a placeholder. Replace them with
//  the App Store Connect IDs, attach the Pro product to the `pro`
//  entitlement, and put it in the current offering in RevenueCat as the
//  Lifetime package. The tips are consumables and belong to no entitlement.
//

import Foundation

enum PurchaseConfig {
    /// RevenueCat public SDK key ("appl_…"). Empty = purchases disabled
    /// (DEBUG builds then unlock Pro so the app can be exercised; launch
    /// with `-uiDebugFree YES` to see it locked, and the paywall shows the
    /// mock offering below).
    static let revenueCatAPIKey = ""

    /// The RevenueCat entitlement that unlocks Pro.
    static let proEntitlement = "pro"

    /// The RevenueCat offering the paywall shows. nil = the current offering.
    static let proOfferingID: String? = nil

    // MARK: Pro

    /// Pro: one-time, non-consumable. The only way to buy it.
    static let proProductID = "ap_pro_lifetime"    // TODO (Rolo)

    // MARK: Tips

    /// One-off consumables, cheapest first. Each unlocks nothing.
    static let tips: [TipDefinition] = [
        TipDefinition(productID: "ap_tip_amen", name: "Amen", blurb: "A quiet thank you", systemImage: "heart.fill"),                   // TODO (Rolo)
        TipDefinition(productID: "ap_tip_hallelujah", name: "Hallelujah", blurb: "Keeps the hymns ringing", systemImage: "music.note"), // TODO (Rolo)
        TipDefinition(productID: "ap_tip_hosanna", name: "Hosanna", blurb: "Carries Advent Praise further", systemImage: "sparkles"),  // TODO (Rolo)
    ]

    static var tipProductIDs: [String] { tips.map(\.productID) }

    // MARK: Mock offering (DEBUG, no RevenueCat key)

    #if DEBUG
    /// What the paywall and the Support screen show in a DEBUG build without
    /// a RevenueCat key, so they can be seen in the Simulator. Prices here
    /// are stand-ins and never reach a Release build; purchases in this mode
    /// pretend to succeed.
    enum Mock {
        static let proOption = ProOption(id: proProductID, price: "R199.99")
        static let tipPrices = ["R19.99", "R49.99", "R99.99"]
    }
    #endif
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
