//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat. Every hymnal is free. Pro, the RevenueCat
//  entitlement `PurchaseConfig.proEntitlement`, unlocks the accompaniment
//  player and AirPlay to a church screen. Its plans, prices and free trial
//  come from the RevenueCat offering, never from the app. Tips are one-off
//  consumables that unlock nothing. "Restore purchases" re-syncs the Apple
//  Account's purchases with the App Store, including those made in the 6.x
//  app.
//
//  The paywall only ever sees plain values (`ProOption`, `TipOption`); the
//  RevenueCat packages and products behind them stay in here. That is what
//  lets a DEBUG build without a key show `PurchaseConfig.Mock` instead.
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

/// Which plan a Pro option is, for layout: Yearly is the primary, Lifetime
/// the quiet second; anything else the offering carries is listed after.
enum ProPlan: Sendable {
    case yearly, lifetime, other
}

/// A free trial on a subscription, as the App Store describes it.
struct ProTrial: Equatable, Sendable {
    enum Unit: Sendable { case day, week, month, year }
    let value: Int
    let unit: Unit

    init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    /// 7 → 1 week, 14 → 2 weeks, otherwise days.
    init(days: Int) {
        if days % 7 == 0 { self.init(value: days / 7, unit: .week) } else { self.init(value: days, unit: .day) }
    }

    /// "1 week", "3 days".
    var length: String {
        switch (unit, value) {
        case (.day, 1): String(localized: "1 day")
        case (.day, let n): String(localized: "\(n) days")
        case (.week, 1): String(localized: "1 week")
        case (.week, let n): String(localized: "\(n) weeks")
        case (.month, 1): String(localized: "1 month")
        case (.month, let n): String(localized: "\(n) months")
        case (.year, 1): String(localized: "1 year")
        case (.year, let n): String(localized: "\(n) years")
        }
    }

    /// "1-week", for "1-week free trial".
    var hyphenated: String { length.replacingOccurrences(of: " ", with: "-") }
}

/// One way to buy Pro, as the paywall lists it. Everything shown comes from
/// the App Store through RevenueCat.
struct ProOption: Identifiable, Equatable, Sendable {
    let id: String
    let plan: ProPlan
    let title: String
    /// The App Store's localized price: "$9.99".
    let price: String
    /// "per year", "one-time purchase"…
    let term: String
    /// Auto-renewing: the paywall then shows the renewal terms.
    let renews: Bool
    /// A free trial this Apple Account can take. nil: none, or already used.
    let trial: ProTrial?

    static func == (a: ProOption, b: ProOption) -> Bool { a.id == b.id }
}

/// A tip the paywall offers, with its App Store price.
struct TipOption: Identifiable, Equatable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let blurb: LocalizedStringResource
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
    private(set) var proOptions: [ProOption] = []
    private(set) var tips: [TipOption] = []
    private(set) var isLoadingOptions = false
    /// The options couldn't be loaded (offline, or nothing set up yet).
    private(set) var optionsFailed = false
    /// The Pro option being bought.
    private(set) var purchasing: String?
    /// The tip being bought.
    private(set) var tipping: String?
    /// A tip went through; the paywall shows its thank-you until this is cleared.
    var thankYouForTip: TipOption?
    var message: String?

    private var listener: Task<Void, Never>?
    private var purchasedProductIDs: Set<String> = []
    /// What the options stand for, by option id.
    private var packages: [String: Package] = [:]
    private var products: [String: StoreProduct] = [:]

    var isConfigured: Bool { !PurchaseConfig.revenueCatAPIKey.isEmpty }

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

    /// Loads the Pro plans (from the RevenueCat offering, or straight from
    /// the App Store if no offering is set up) and the tips.
    func loadStorefront() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsFailed = false
        defer { isLoadingOptions = false }
        #if DEBUG
        if isMock {
            try? await Task.sleep(for: .milliseconds(250))
            proOptions = PurchaseConfig.Mock.proOptions
            tips = zip(PurchaseConfig.tips, PurchaseConfig.Mock.tipPrices).map { definition, price in
                TipOption(id: definition.productID, name: definition.name, blurb: definition.blurb, price: price)
            }
            return
        }
        #endif
        guard isConfigured else { optionsFailed = true; return }
        var found: [(product: StoreProduct, package: Package?)] = []
        if let offerings = try? await Purchases.shared.offerings(),
           let offering = PurchaseConfig.proOfferingID.flatMap(offerings.offering(identifier:)) ?? offerings.current {
            found = offering.availablePackages.map { ($0.storeProduct, $0) }
        }
        if found.isEmpty {
            found = await Purchases.shared.products(PurchaseConfig.proProductIDs).map { ($0, nil) }
        }
        let eligible = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: found.map(\.product.productIdentifier))
        var options: [ProOption] = []
        for entry in found {
            let option = Self.option(product: entry.product, package: entry.package,
                                     eligibility: eligible[entry.product.productIdentifier]?.status)
            options.append(option)
            packages[option.id] = entry.package
            products[option.id] = entry.product
        }
        proOptions = Self.ordered(options)
        optionsFailed = options.isEmpty
        if options.isEmpty { Analytics.error(.products, code: "no_pro_options") }

        let tipProducts = await Purchases.shared.products(PurchaseConfig.tipProductIDs)
        tips = PurchaseConfig.tips.compactMap { definition in
            guard let product = tipProducts.first(where: { $0.productIdentifier == definition.productID }) else { return nil }
            products[definition.productID] = product
            return TipOption(id: definition.productID, name: definition.name, blurb: definition.blurb,
                             price: product.localizedPriceString)
        }
    }

    // MARK: Pro

    /// True when Pro is active afterwards. Haptics: the purchase flourish on
    /// success, an error when it fails, nothing if the buyer cancels.
    /// `feature` is what the paywall led with, for analytics; the product
    /// is sent as the package or product ID, never a price.
    @discardableResult
    func purchase(_ option: ProOption, feature: ProFeature) async -> Bool {
        Analytics.track(.purchaseStarted(product: option.id, feature: feature))
        #if DEBUG
        if isMock {
            purchasing = option.id
            defer { purchasing = nil }
            try? await Task.sleep(for: .milliseconds(900))
            isPro = true
            Analytics.setPro(true)
            Haptics.play(.purchaseComplete)
            Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
            return true
        }
        #endif
        guard isConfigured, let product = products[option.id] else {
            message = "Purchases aren’t available in this build."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notConfigured))
            return false
        }
        purchasing = option.id
        defer { purchasing = nil }
        do {
            let result = if let package = packages[option.id] {
                try await Purchases.shared.purchase(package: package)
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

    /// Yearly first, Lifetime second, anything else by price.
    private static func ordered(_ options: [ProOption]) -> [ProOption] {
        let yearly = options.filter { $0.plan == .yearly }
        let lifetime = options.filter { $0.plan == .lifetime }
        let other = options.filter { $0.plan == .other }
        return yearly + lifetime + other
    }

    private static func option(product: StoreProduct, package: Package?,
                               eligibility: IntroEligibilityStatus?) -> ProOption {
        let period = product.subscriptionPeriod
        let plan = plan(for: package?.packageType, period: period, product: product)
        return ProOption(id: package?.identifier ?? product.productIdentifier,
                         plan: plan,
                         title: title(for: plan, product: product),
                         price: product.localizedPriceString,
                         term: term(for: period),
                         renews: product.productType == .autoRenewableSubscription,
                         trial: trial(for: product, eligibility: eligibility))
    }

    private static func plan(for type: PackageType?, period: SubscriptionPeriod?, product: StoreProduct) -> ProPlan {
        switch type {
        case .annual?: return .yearly
        case .lifetime?: return .lifetime
        default: break
        }
        switch product.productIdentifier {
        case PurchaseConfig.proYearlyProductID: return .yearly
        case PurchaseConfig.proLifetimeProductID: return .lifetime
        default: break
        }
        if let period, period.unit == .year, period.value == 1 { return .yearly }
        if period == nil, product.productType == .nonConsumable { return .lifetime }
        return .other
    }

    private static func title(for plan: ProPlan, product: StoreProduct) -> String {
        switch plan {
        case .yearly: String(localized: "Yearly")
        case .lifetime: String(localized: "Lifetime")
        case .other: product.localizedTitle.isEmpty ? String(localized: "Pro") : product.localizedTitle
        }
    }

    /// The product's free trial, when this Apple Account can still take it.
    /// Unknown eligibility (offline, a new account) shows it; the App Store
    /// has the last word at purchase time either way.
    private static func trial(for product: StoreProduct, eligibility: IntroEligibilityStatus?) -> ProTrial? {
        guard let discount = product.introductoryDiscount, discount.paymentMode == .freeTrial else { return nil }
        if let eligibility, eligibility == .ineligible || eligibility == .noIntroOfferExists { return nil }
        let period = discount.subscriptionPeriod
        let unit: ProTrial.Unit = switch period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
        return ProTrial(value: period.value, unit: unit)
    }

    private static func term(for period: SubscriptionPeriod?) -> String {
        guard let period else { return String(localized: "one-time purchase") }
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
