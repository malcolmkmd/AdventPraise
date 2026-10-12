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
//  Pro (the accompaniment player and AirPlay to a church screen) is the
//  RevenueCat entitlement below. Prices are never written here: the paywall
//  reads them from the RevenueCat offering (or, failing that, the App Store).
//
//  ⚠️ TODO (Rolo): the Pro product IDs below are placeholders. Replace them
//  with the App Store Connect IDs, attach those products to the `pro`
//  entitlement, and put them in the current offering in RevenueCat.
//

import Foundation

enum PurchaseConfig {
    /// RevenueCat public SDK key ("appl_…"). Empty = purchases disabled
    /// (DEBUG builds then unlock Pro so the app can be exercised; launch
    /// with `-uiDebugFree YES` to see it locked).
    static let revenueCatAPIKey = ""

    /// The RevenueCat entitlement that unlocks the player and AirPlay.
    static let proEntitlement = "pro"

    /// The RevenueCat offering the paywall shows. nil = the current offering.
    static let proOfferingID: String? = nil

    /// Pro products, used only when no offering can be loaded. PLACEHOLDERS:
    /// the real IDs come from Rolo.
    static let proProductIDs: [String] = [
        "com.mDev.Advent_Praise.pro.annual",     // TODO (Rolo)
        "com.mDev.Advent_Praise.pro.lifetime",   // TODO (Rolo)
    ]
}
