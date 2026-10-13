//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat. Every hymnal is free. Pro, the RevenueCat
//  entitlement `PurchaseConfig.proEntitlement`, unlocks the accompaniment
//  player beyond its free plays (FreePlays.swift) and AirPlay to a church
//  screen. It is bought once (one
//  non-consumable, no subscription, no trial); its price comes from the
//  RevenueCat offering, never from the app. Tips are one-off consumables
//  that unlock nothing. "Restore purchases" re-syncs the Apple Account's
//  purchases with the App Store, including those made in the 6.x app.
//
//  The paywall and the Support screen only ever see plain values
//  (`ProOption`, `TipOption`); the RevenueCat package and products behind
//  them stay in here. That is what lets a DEBUG build without a key show
//  `PurchaseConfig.Mock` instead.
//

import Observation
@preconcurrency import RevenueCat
import SwiftUI

/// Something Pro unlocks; the paywall leads with it.
enum ProFeature: String, Identifiable, Sendable {
    case player, airPlay
    /// Opened from More, not by a locked feature.
    case support
    var id: String { rawValue }
}

/// Pro as the paywall sells it: one product, one price, bought once. The
/// price comes from the App Store through RevenueCat.
struct ProOption: Identifiable, Equatable, Sendable {
    /// The RevenueCat package identifier, or the product ID when there is no offering.
    let id: String
    /// The App Store's localized price: "R199.99".
    let price: String

    static func == (a: ProOption, b: ProOption) -> Bool { a.id == b.id }
}

/// A tip the Support screen offers, with its App Store price.
struct TipOption: Identifiable, Equatable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let blurb: LocalizedStringResource
    let systemImage: String
    let price: String

    static func == (a: TipOption, b: TipOption) -> Bool { a.id == b.id }
}

@Observable
@MainActor
final class PurchaseStore {
    private(set) var isRestoring = false
    /// True once CustomerInfo has been read at least once (cached or fresh).
    private(set) var hasLoadedEntitlements = false
    /// The `pro` entitlement is active.
    private(set) var isPro = false
    /// The one way to buy Pro; nil until loaded, or when it couldn't be.
    private(set) var proOption: ProOption?
    private(set) var tips: [TipOption] = []
    private(set) var isLoadingOptions = false
    /// The storefront couldn't be loaded (offline, or nothing set up yet).
    private(set) var optionsFailed = false
    /// True while Pro is being bought.
    private(set) var purchasing = false
    /// The tip being bought.
    private(set) var tipping: String?
    /// A tip went through; the Support screen shows its thank-you until this is cleared.
    var thankYouForTip: TipOption?
    var message: String?

    private var listener: Task<Void, Never>?
    private var purchasedProductIDs: Set<String> = []
    /// What `proOption` stands for: its package (from the offering), and
    /// its product; tip products by product ID.
    private var proPackage: Package?
    private var products: [String: StoreProduct] = [:]

    var isConfigured: Bool { !PurchaseConfig.revenueCatAPIKey.isEmpty }
    /// Pro can be bought here: a RevenueCat key, or the DEBUG mock.
    var canPurchase: Bool { isConfigured || isMock }

    /// DEBUG without a key: the paywall shows the mock offering and purchases
    /// pretend to go through, so the whole flow can be exercised.
    private var isMock: Bool {
        #if DEBUG
        !isConfigured
        #else
        false
        #endif
    }

    func start() {
        guard isConfigured else {
            #if DEBUG
            isPro = !DebugLaunch.free
            #endif
            hasLoadedEntitlements = true
            Analytics.setPro(isPro)
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

    // MARK: Loading

    /// Loads Pro's price (from the RevenueCat offering, or straight from the
    /// App Store if no offering is set up) and the tips.
    func loadStorefront() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsFailed = false
        defer { isLoadingOptions = false }
        #if DEBUG
        if isMock {
            try? await Task.sleep(for: .milliseconds(250))
            proOption = PurchaseConfig.Mock.proOption
            tips = zip(PurchaseConfig.tips, PurchaseConfig.Mock.tipPrices).map { $0.option(price: $1) }
            return
        }
        #endif
        guard isConfigured else { optionsFailed = true; return }
        var found: (product: StoreProduct, package: Package?)?
        if let offerings = try? await Purchases.shared.offerings(),
           let offering = PurchaseConfig.proOfferingID.flatMap(offerings.offering(identifier:)) ?? offerings.current,
           let package = Self.proPackage(in: offering) {
            found = (package.storeProduct, package)
        }
        if found == nil, let product = await Purchases.shared.products([PurchaseConfig.proProductID]).first {
            found = (product, nil)
        }
        if let found {
            proPackage = found.package
            products[PurchaseConfig.proProductID] = found.product
            proOption = ProOption(id: found.package?.identifier ?? found.product.productIdentifier,
                                  price: found.product.localizedPriceString)
        } else {
            proOption = nil
            optionsFailed = true
            Analytics.error(.products, code: "no_pro_option")
        }

        let tipProducts = await Purchases.shared.products(PurchaseConfig.tipProductIDs)
        tips = PurchaseConfig.tips.compactMap { definition in
            guard let product = tipProducts.first(where: { $0.productIdentifier == definition.productID }) else { return nil }
            products[definition.productID] = product
            return definition.option(price: product.localizedPriceString)
        }
    }

    // MARK: Pro

    /// Buys Pro. True when Pro is active afterwards. Haptics: the purchase
    /// flourish on success, an error when it fails, nothing if the buyer
    /// cancels. `feature` is what the paywall led with, for analytics; the
    /// product is sent as the package or product ID, never a price.
    @discardableResult
    func purchase(_ option: ProOption, feature: ProFeature) async -> Bool {
        Analytics.track(.purchaseStarted(product: option.id, feature: feature))
        #if DEBUG
        if isMock {
            purchasing = true
            defer { purchasing = false }
            try? await Task.sleep(for: .milliseconds(900))
            isPro = true
            Analytics.setPro(true)
            Haptics.play(.purchaseComplete)
            Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
            return true
        }
        #endif
        guard isConfigured, let product = products[PurchaseConfig.proProductID] else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notConfigured))
            return false
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = if let proPackage {
                try await Purchases.shared.purchase(package: proPackage)
            } else {
                try await Purchases.shared.purchase(product: product)
            }
            apply(result.customerInfo)
            if result.userCancelled {
                Analytics.track(.purchaseCancelled(product: option.id, feature: feature))
            } else {
                Haptics.play(isPro ? .purchaseComplete : .warning)
                if isPro {
                    Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
                } else {
                    message = "The purchase went through, but Pro isn’t active yet. Try Restore purchases."
                    Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notActivated))
                }
            }
            return isPro
        } catch {
            message = "The purchase didn’t go through. You haven’t been charged."
            Haptics.play(.error)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .storeError))
            Analytics.error(.purchase, error)
            return false
        }
    }

    // MARK: Tips

    /// Buys a tip. It unlocks nothing; success sets `thankYouForTip`.
    func tip(_ tip: TipOption) async {
        Analytics.track(.tipStarted(product: tip.id))
        #if DEBUG
        if isMock {
            tipping = tip.id
            defer { tipping = nil }
            try? await Task.sleep(for: .milliseconds(900))
            Haptics.play(.purchaseComplete)
            Analytics.track(.tipCompleted(product: tip.id))
            thankYouForTip = tip
            return
        }
        #endif
        guard isConfigured, let product = products[tip.id] else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            Analytics.track(.tipFailed(product: tip.id, reason: .notConfigured))
            return
        }
        tipping = tip.id
        defer { tipping = nil }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            apply(result.customerInfo)
            if result.userCancelled {
                Analytics.track(.tipCancelled(product: tip.id))
            } else {
                Haptics.play(.purchaseComplete)
                Analytics.track(.tipCompleted(product: tip.id))
                thankYouForTip = tip
            }
        } catch {
            message = "The tip didn’t go through. You haven’t been charged."
            Haptics.play(.error)
            Analytics.track(.tipFailed(product: tip.id, reason: .storeError))
            Analytics.error(.purchase, error)
        }
    }

    // MARK: Restore

    func restore(source: RestoreSource) async {
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
            message = if isPro {
                "Advent Praise Pro has been restored."
            } else if purchasedProductIDs.isEmpty {
                "No previous purchases were found for this Apple Account."
            } else {
                "Your purchases have been restored. Advent Praise Pro isn’t among them."
            }
            Haptics.play(isPro ? .success : .warning)
            Analytics.track(.restoreCompleted(foundPurchases: !purchasedProductIDs.isEmpty, proActive: isPro))
        } catch {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
            Analytics.track(.restoreFailed)
            Analytics.error(.restore, error)
        }
    }

    // MARK: Private

    private func apply(_ info: CustomerInfo) {
        purchasedProductIDs = info.allPurchasedProductIdentifiers
        isPro = info.entitlements.active[PurchaseConfig.proEntitlement] != nil
        hasLoadedEntitlements = true
        Analytics.setPro(isPro)
    }

    /// The Pro package in the offering: the one for `proProductID`, else the
    /// Lifetime package, else any non-consumable. Subscriptions are never
    /// sold, so an auto-renewing package left in the offering is ignored.
    private static func proPackage(in offering: Offering) -> Package? {
        let packages = offering.availablePackages.filter { $0.storeProduct.productType != .autoRenewableSubscription }
        return packages.first { $0.storeProduct.productIdentifier == PurchaseConfig.proProductID }
            ?? packages.first { $0.packageType == .lifetime }
            ?? packages.first { $0.storeProduct.productType == .nonConsumable }
    }
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
