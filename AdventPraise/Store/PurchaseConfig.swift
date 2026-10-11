//
//  PurchaseConfig.swift
//  Advent Praise
//
//  The one place that maps hymnals to in-app purchases. Everything here must
//  match App Store Connect and the RevenueCat dashboard for app id1015021132.
//
//  ⚠️ TODO (Rolo/Malcolm): the product IDs below are placeholders until the
//  live 6.3 product IDs are confirmed. Existing buyers only get their hymnals
//  back on 7.0 if these strings are exactly the live non-consumable IDs.
//

import Foundation

enum PurchaseConfig {
    /// RevenueCat public SDK key ("appl_…"). Empty = purchases disabled
    /// (DEBUG builds then unlock every hymnal so the app can be exercised).
    static let revenueCatAPIKey = ""

    /// Optional RevenueCat entitlement that unlocks every hymnal (e.g. granted
    /// by an "all hymnals" bundle). Leave as is if no such entitlement exists.
    static let allHymnalsEntitlement = "all_hymnals"

    /// Optional non-consumable that unlocks every hymnal. nil hides the
    /// "Unlock all" button.
    static let allHymnalsProductID: String? = nil

    /// Hymnals that are free for everyone.
    static let freeHymnals: Set<String> = ["english"]

    /// Hymnal key (Resources/Hymnals/<key>.json) → App Store product ID.
    static let productIDs: [String: String] = [
        "tswana": "com.mDev.Advent_Praise.tswana",
        "sotho": "com.mDev.Advent_Praise.sotho",
        "chichewa": "com.mDev.Advent_Praise.chichewa",
        "tonga": "com.mDev.Advent_Praise.tonga",
        "shona": "com.mDev.Advent_Praise.shona",
        "venda": "com.mDev.Advent_Praise.venda",
        "swahili": "com.mDev.Advent_Praise.swahili",
        "ndebele": "com.mDev.Advent_Praise.ndebele",
        "xhosa": "com.mDev.Advent_Praise.xhosa",
        "xitsonga": "com.mDev.Advent_Praise.xitsonga",
        "gikuyu": "com.mDev.Advent_Praise.gikuyu",
        "abagusii": "com.mDev.Advent_Praise.abagusii",
        "dholuo": "com.mDev.Advent_Praise.dholuo",
        "sdah": "com.mDev.Advent_Praise.sdah",
        "kinyarwanda": "com.mDev.Advent_Praise.kinyarwanda",
        "pt": "com.mDev.Advent_Praise.portuguese",
        "es": "com.mDev.Advent_Praise.spanish",
        "dg": "com.mDev.Advent_Praise.french",
        "ru": "com.mDev.Advent_Praise.russian",
        "tumbuka": "com.mDev.Advent_Praise.tumbuka",
        "sepedi": "com.mDev.Advent_Praise.sepedi",
        "icibemba": "com.mDev.Advent_Praise.icibemba",
        "twi": "com.mDev.Advent_Praise.twi",
    ]

    static func productID(for hymnalKey: String) -> String? { productIDs[hymnalKey] }

    static var allProductIDs: [String] {
        Array(productIDs.values) + (allHymnalsProductID.map { [$0] } ?? [])
    }
}
