//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat. Every hymnal is free. "Restore purchases"
//  re-syncs the Apple Account's purchases with the App Store, including
//  those made in the 6.x app.
//

import Observation
@preconcurrency import RevenueCat
import SwiftUI

@Observable
@MainActor
final class PurchaseStore {
    private(set) var isRestoring = false
    /// True once CustomerInfo has been read at least once (cached or fresh).
    private(set) var hasLoadedEntitlements = false
    var message: String?

    private var listener: Task<Void, Never>?
    private var purchasedProductIDs: Set<String> = []

    var isConfigured: Bool { !PurchaseConfig.revenueCatAPIKey.isEmpty }

    func start() {
        guard isConfigured else {
            hasLoadedEntitlements = true
            return
        }
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: PurchaseConfig.revenueCatAPIKey)
        listener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    // MARK: Actions

    func restore() async {
        guard isConfigured else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            return
        }
        isRestoring = true
        defer { isRestoring = false }
        Analytics.track(.restoreTapped)
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            let foundNothing = purchasedProductIDs.isEmpty
            message = foundNothing
                ? "No previous purchases were found for this Apple Account."
                : "Your purchases have been restored."
            Haptics.play(foundNothing ? .warning : .success)
        } catch {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
        }
    }

    // MARK: Private

    private func apply(_ info: CustomerInfo) {
        purchasedProductIDs = info.allPurchasedProductIdentifiers
        hasLoadedEntitlements = true
    }
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
