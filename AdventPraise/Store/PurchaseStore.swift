//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat. Every hymnal is free. Pro, the RevenueCat
//  entitlement `PurchaseConfig.proEntitlement`, unlocks the accompaniment
//  player and AirPlay to a church screen. Its options and prices come from
//  the RevenueCat offering, never from the app. "Restore purchases"
//  re-syncs the Apple Account's purchases with the App Store, including
//  those made in the 6.x app.
//

import Observation
@preconcurrency import RevenueCat
import SwiftUI

/// Something Pro unlocks; the paywall leads with it.
enum ProFeature: String, Identifiable, Sendable {
    case player, airPlay
    var id: String { rawValue }
}

/// One way to buy Pro, as the paywall lists it. Everything shown comes from
/// the App Store through RevenueCat.
struct ProOption: Identifiable, Equatable {
    let id: String
    let title: String
    /// The App Store's localized price: "$9.99".
    let price: String
    /// "per year", "one-time purchase"…
    let term: String
    /// Auto-renewing: the paywall then shows the renewal terms.
    let renews: Bool
    fileprivate let package: Package?
    fileprivate let product: StoreProduct

    static func == (a: ProOption, b: ProOption) -> Bool { a.id == b.id }
}

@Observable
@MainActor
final class PurchaseStore {
    private(set) var isRestoring = false
    /// True once CustomerInfo has been read at least once (cached or fresh).
    private(set) var hasLoadedEntitlements = false
    /// The `pro` entitlement is active.
    private(set) var isPro = false
    private(set) var proOptions: [ProOption] = []
    private(set) var isLoadingOptions = false
    /// The options couldn't be loaded (offline, or nothing set up yet).
    private(set) var optionsFailed = false
    /// The option being bought.
    private(set) var purchasing: String?
    var message: String?

    private var listener: Task<Void, Never>?
    private var purchasedProductIDs: Set<String> = []

    var isConfigured: Bool { !PurchaseConfig.revenueCatAPIKey.isEmpty }

    func start() {
        guard isConfigured else {
            #if DEBUG
            isPro = !DebugLaunch.free
            #endif
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

    // MARK: Pro

    /// Loads the paywall's options from the RevenueCat offering, or straight
    /// from the App Store if no offering is set up.
    func loadProOptions() async {
        guard isConfigured else { optionsFailed = true; return }
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsFailed = false
        defer { isLoadingOptions = false }
        var options: [ProOption] = []
        if let offerings = try? await Purchases.shared.offerings(),
           let offering = PurchaseConfig.proOfferingID.flatMap(offerings.offering(identifier:)) ?? offerings.current {
            options = offering.availablePackages.map { Self.option(product: $0.storeProduct, package: $0) }
        }
        if options.isEmpty {
            options = await Purchases.shared.products(PurchaseConfig.proProductIDs)
                .map { Self.option(product: $0, package: nil) }
                .sorted { $0.product.price < $1.product.price }
        }
        proOptions = options
        optionsFailed = options.isEmpty
    }

    /// True when Pro is active afterwards. Haptics: the purchase flourish on
    /// success, an error when it fails, nothing if the buyer cancels.
    @discardableResult
    func purchase(_ option: ProOption) async -> Bool {
        guard isConfigured else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            return false
        }
        purchasing = option.id
        defer { purchasing = nil }
        do {
            let result = if let package = option.package {
                try await Purchases.shared.purchase(package: package)
            } else {
                try await Purchases.shared.purchase(product: option.product)
            }
            apply(result.customerInfo)
            if !result.userCancelled {
                Analytics.track(.purchaseCompleted(product: option.id))
                Haptics.play(isPro ? .purchaseComplete : .warning)
                if !isPro { message = "The purchase went through, but Pro isn’t active yet. Try Restore purchases." }
            }
            return isPro
        } catch {
            message = "The purchase didn’t go through. You haven’t been charged."
            Haptics.play(.error)
            return false
        }
    }

    // MARK: Restore

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
            message = if isPro {
                "Advent Praise Pro has been restored."
            } else if purchasedProductIDs.isEmpty {
                "No previous purchases were found for this Apple Account."
            } else {
                "Your purchases have been restored. Advent Praise Pro isn’t among them."
            }
            Haptics.play(isPro ? .success : .warning)
        } catch {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
        }
    }

    // MARK: Private

    private func apply(_ info: CustomerInfo) {
        purchasedProductIDs = info.allPurchasedProductIdentifiers
        isPro = info.entitlements.active[PurchaseConfig.proEntitlement] != nil
        hasLoadedEntitlements = true
    }

    private static func option(product: StoreProduct, package: Package?) -> ProOption {
        let period = product.subscriptionPeriod
        return ProOption(id: package?.identifier ?? product.productIdentifier,
                         title: title(for: package?.packageType, period: period, product: product),
                         price: product.localizedPriceString,
                         term: term(for: period),
                         renews: product.productType == .autoRenewableSubscription,
                         package: package, product: product)
    }

    private static func title(for type: PackageType?, period: SubscriptionPeriod?, product: StoreProduct) -> String {
        switch type {
        case .lifetime?: return String(localized: "Lifetime")
        case .annual?: return String(localized: "Yearly")
        case .monthly?: return String(localized: "Monthly")
        case .weekly?: return String(localized: "Weekly")
        default: break
        }
        if period == nil, product.productType == .nonConsumable { return String(localized: "Lifetime") }
        return product.localizedTitle.isEmpty ? String(localized: "Pro") : product.localizedTitle
    }

    private static func term(for period: SubscriptionPeriod?) -> String {
        guard let period else { return String(localized: "One-time purchase") }
        switch (period.unit, period.value) {
        case (.year, 1): return String(localized: "per year")
        case (.month, 1): return String(localized: "per month")
        case (.week, 1): return String(localized: "per week")
        case (.day, 1): return String(localized: "per day")
        case (.year, let n): return String(localized: "every \(n) years")
        case (.month, let n): return String(localized: "every \(n) months")
        case (.week, let n): return String(localized: "every \(n) weeks")
        case (.day, let n): return String(localized: "every \(n) days")
        @unknown default: return ""
        }
    }
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
