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
//  Pro (the player, church mode with AirPlay, the service planner, the pitch
//  pipe, unlimited Memorise and playlists, side-by-side translations) is the
//  RevenueCat entitlement below. Prices are never written here: the paywall
//  reads them from the RevenueCat offering (or, failing that, the App Store).
//
//  Tips are one-off consumables. They unlock nothing; the paywall says so.
//
//  ⚠️ TODO (Rolo): every product ID below is a placeholder. Replace them with
//  the App Store Connect IDs, attach the Pro products to the `pro`
//  entitlement, and put them in the current offering in RevenueCat. The tips
//  are consumables and belong to no entitlement.
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

    /// Yearly, auto-renewing, with the free trial set up in App Store
    /// Connect (the paywall reads the trial from the product, never from here).
    static let proYearlyProductID = "ap_pro_yearly"        // TODO (Rolo)
    /// Lifetime, one-time, non-consumable.
    static let proLifetimeProductID = "ap_pro_lifetime"    // TODO (Rolo)

    /// Pro products, used only when no offering can be loaded.
    static let proProductIDs: [String] = [proYearlyProductID, proLifetimeProductID]

    // MARK: Tips

    /// One-off consumables, cheapest first. Each unlocks nothing.
    static let tips: [TipDefinition] = [
        TipDefinition(productID: "ap_tip_amen", name: "Amen", blurb: "A quiet thank you"),                     // TODO (Rolo)
        TipDefinition(productID: "ap_tip_hallelujah", name: "Hallelujah", blurb: "Keeps the hymns ringing"),  // TODO (Rolo)
        TipDefinition(productID: "ap_tip_hosanna", name: "Hosanna", blurb: "Carries Advent Praise further"), // TODO (Rolo)
    ]

    static var tipProductIDs: [String] { tips.map(\.productID) }

    // MARK: Mock offering (DEBUG, no RevenueCat key)

    #if DEBUG
    /// What the paywall shows in a DEBUG build without a RevenueCat key, so
    /// it can be seen in the Simulator. Prices here are stand-ins and never
    /// reach a Release build; purchases in this mode pretend to succeed.
    enum Mock {
        static let proOptions: [ProOption] = [
            ProOption(id: proYearlyProductID, plan: .yearly, title: String(localized: "Yearly"),
                      price: "$19.99", term: String(localized: "per year"), renews: true,
                      trial: ProTrial(days: 7)),
            ProOption(id: proLifetimeProductID, plan: .lifetime, title: String(localized: "Lifetime"),
                      price: "$49.99", term: String(localized: "one-time purchase"), renews: false, trial: nil),
        ]
        static let tipPrices = ["$0.99", "$2.99", "$9.99"]
    }
    #endif
}

/// A tip as the config names it; the store adds the App Store price.
struct TipDefinition: Identifiable, Sendable {
    let productID: String
    let name: LocalizedStringResource
    let blurb: LocalizedStringResource
    var id: String { productID }
}
