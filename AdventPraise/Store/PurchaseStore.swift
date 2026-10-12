//
//  PurchaseStore.swift
//  Advent Praise
//
//  Hymnal purchases through RevenueCat. English ships free; every other
//  hymnal is a non-consumable (see PurchaseConfig). Ownership comes from
//  RevenueCat's CustomerInfo, which includes purchases made in the 6.x app,
//  and "Restore purchases" re-syncs with the App Store.
//

import Observation
@preconcurrency import RevenueCat
import SwiftUI

@Observable
@MainActor
final class PurchaseStore {
    private(set) var prices: [String: String] = [:]          // product id → localized price
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var ownsEverything = false
    private(set) var purchasing: String?                     // hymnal key or the all-hymnals product id
    private(set) var isRestoring = false
    /// True once CustomerInfo has been read at least once (cached or fresh).
    private(set) var hasLoadedEntitlements = false
    var message: String?

    private var products: [String: StoreProduct] = [:]
    private var listener: Task<Void, Never>?

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
        Task { await loadProducts() }
    }

    // MARK: Queries

    func isOwned(_ hymnal: HymnalInfo) -> Bool {
        if hymnal.isFree || ownsEverything { return true }
        #if DEBUG
        if !isConfigured { return true }
        #endif
        guard let id = PurchaseConfig.productID(for: hymnal.id) else { return false }
        return purchasedProductIDs.contains(id)
    }

    func price(for hymnal: HymnalInfo) -> String? {
        PurchaseConfig.productID(for: hymnal.id).flatMap { prices[$0] }
    }

    var allHymnalsPrice: String? { PurchaseConfig.allHymnalsProductID.flatMap { prices[$0] } }

    // MARK: Actions

    /// Returns true when the hymnal is owned afterwards. `source` is the
    /// paywall it was bought from, for analytics.
    @discardableResult
    func purchase(_ hymnal: HymnalInfo, source: StoreSource) async -> Bool {
        guard let id = PurchaseConfig.productID(for: hymnal.id) else { return isOwned(hymnal) }
        return await buy(productID: id, busyKey: hymnal.id, product: hymnal.id, source: source) && isOwned(hymnal)
    }

    func purchaseAll(source: StoreSource) async {
        guard let id = PurchaseConfig.allHymnalsProductID else { return }
        _ = await buy(productID: id, busyKey: id, product: "all", source: source)
    }

    func restore(source: StoreSource) async {
        Analytics.track(.restoreStarted(source: source))
        guard isConfigured else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            Analytics.track(.restoreFailed)
            return
        }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            let foundNothing = purchasedProductIDs.isEmpty && !ownsEverything
            message = foundNothing
                ? "No previous hymnal purchases were found for this Apple Account."
                : "Your hymnals have been restored."
            Haptics.play(foundNothing ? .warning : .success)
            Analytics.track(.restoreCompleted(foundPurchases: !foundNothing))
        } catch {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
            Analytics.track(.restoreFailed)
            Analytics.error(.restore, error)
        }
    }

    // MARK: Private

    /// Haptics: the purchase flourish on success, an error when it fails,
    /// a warning when it can't start, and nothing if the buyer cancels.
    /// `product` is the hymnal key or "all" (never a price), for analytics.
    private func buy(productID: String, busyKey: String, product key: String, source: StoreSource) async -> Bool {
        Analytics.track(.purchaseStarted(product: key, source: source))
        guard isConfigured else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: key, source: source, reason: .notConfigured))
            return false
        }
        if products[productID] == nil { await loadProducts() }
        guard let product = products[productID] else {
            message = "This hymnal isn’t available from the App Store right now."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: key, source: source, reason: .productUnavailable))
            return false
        }
        purchasing = busyKey
        defer { purchasing = nil }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            apply(result.customerInfo)
            if result.userCancelled {
                Analytics.track(.purchaseCancelled(product: key, source: source))
            } else {
                Analytics.track(.purchaseCompleted(product: key, source: source))
                Haptics.play(.purchaseComplete)
            }
            return !result.userCancelled
        } catch {
            message = "The purchase didn’t go through. You haven’t been charged."
            Haptics.play(.error)
            Analytics.track(.purchaseFailed(product: key, source: source, reason: .storeError))
            Analytics.error(.purchase, error)
            return false
        }
    }

    private func loadProducts() async {
        let fetched = await Purchases.shared.products(PurchaseConfig.allProductIDs)
        if fetched.isEmpty, !PurchaseConfig.allProductIDs.isEmpty { Analytics.error(.products, code: "none_returned") }
        for product in fetched {
            products[product.productIdentifier] = product
            prices[product.productIdentifier] = product.localizedPriceString
        }
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    private func apply(_ info: CustomerInfo) {
        purchasedProductIDs = info.allPurchasedProductIdentifiers
        let allID = PurchaseConfig.allHymnalsProductID
        ownsEverything = info.entitlements.active[PurchaseConfig.allHymnalsEntitlement] != nil
            || allID.map(info.allPurchasedProductIdentifiers.contains) == true
        hasLoadedEntitlements = true
    }
}
