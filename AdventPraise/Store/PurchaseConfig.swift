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

import Foundation

enum PurchaseConfig {
    /// RevenueCat public SDK key ("appl_…"). Empty = purchases disabled.
    static let revenueCatAPIKey = ""
}
