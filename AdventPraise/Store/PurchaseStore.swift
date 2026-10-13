//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through StoreKit 2, with no server and no SDK. Every hymnal is
//  free. Pro, owning `PurchaseConfig.proProductID`, unlocks the
//  accompaniment player beyond its free plays (FreePlays.swift) and AirPlay
//  to a church screen. It is bought once (one non-consumable, no
//  subscription, no trial); its price comes from the App Store, never from
//  the app. Tips are one-off consumables that unlock nothing. "Restore
//  purchases" re-syncs the Apple Account's purchases with the App Store
//  (`AppStore.sync()`), including those made in the 6.x app.
//
//  Pro is whatever `Transaction.currentEntitlements` says, read at launch
//  and again after every purchase, restore and `Transaction.updates`
//  (Ask to Buy approvals, refunds, purchases on another device). Every
//  verified transaction is finished once it has been delivered.
//
//  The paywall and the Support screen only ever see plain values
//  (`ProOption`, `TipOption`); the StoreKit products behind them stay in
//  here.
//

import Observation
import StoreKit
import SwiftUI

/// Something Pro unlocks; the paywall leads with it.
enum ProFeature: String, Identifiable, Sendable {
    case player, airPlay
    /// The Go Pro banner on a mirrored screen (ScreenMirroring.swift).
    case mirroring
    /// Opened from More, not by a locked feature.
    case support
    var id: String { rawValue }
}

/// Pro as the paywall sells it: one product, one price, bought once. The
/// price comes from the App Store.
struct ProOption: Identifiable, Equatable, Sendable {
    /// The App Store product ID.
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
    /// True once the entitlements have been read at least once.
    private(set) var hasLoadedEntitlements = false
    /// Pro is owned by this Apple Account.
    private(set) var isPro = false
    /// The one way to buy Pro; nil until loaded, or when it couldn't be.
    private(set) var proOption: ProOption?
    private(set) var tips: [TipOption] = []
    private(set) var isLoadingOptions = false
    /// The products couldn't be loaded (offline, or not set up yet). The
    /// paywall and the Support screen offer Try again.
    private(set) var optionsFailed = false
    /// True while Pro is being bought.
    private(set) var purchasing = false
    /// The tip being bought.
    private(set) var tipping: String?
    /// A tip went through; the Support screen shows its thank-you until this is cleared.
    var thankYouForTip: TipOption?
    var message: String?

    private var updates: Task<Void, Never>?
    /// Everything this Apple Account owns, Pro and the 6.x hymnals alike.
    private var ownedProductIDs: Set<String> = []
    private var products: [String: Product] = [:]

    /// Listens for transactions made outside a purchase call (Ask to Buy,
    /// another device, refunds, interrupted purchases) and reads what the
    /// Apple Account owns. Called once, at launch.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: Loading

    /// Loads Pro's price and the tips from the App Store.
    func loadStorefront() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsFailed = false
        defer { isLoadingOptions = false }
        do {
            let loaded = try await Product.products(for: PurchaseConfig.allProductIDs)
            for product in loaded { products[product.id] = product }
        } catch {
            Analytics.error(.products, error)
        }
        if let pro = products[PurchaseConfig.proProductID] {
            proOption = ProOption(id: pro.id, price: pro.displayPrice)
        } else {
            proOption = nil
            Analytics.error(.products, code: "no_pro_option")
        }
        tips = PurchaseConfig.tips.compactMap { definition in
            products[definition.productID].map { definition.option(price: $0.displayPrice) }
        }
        optionsFailed = proOption == nil || tips.isEmpty
    }

    // MARK: Pro

    /// Buys Pro. True when Pro is active afterwards. Haptics: the purchase
    /// flourish on success, an error when it fails, nothing if the buyer
    /// cancels. `feature` is what the paywall led with, for analytics; the
    /// product is sent as its ID, never a price.
    @discardableResult
    func purchase(_ option: ProOption, feature: ProFeature) async -> Bool {
        Analytics.track(.purchaseStarted(product: option.id, feature: feature))
        guard let product = products[option.id] else {
            message = "Pro isn’t available right now. Check your connection and try again."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .unavailable))
            await loadStorefront()
            return false
        }
        purchasing = true
        defer { purchasing = false }
        switch await buy(product) {
        case .delivered:
            await refreshEntitlements()
            if isPro {
                Haptics.play(.purchaseComplete)
                Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
            } else {
                message = "The purchase went through, but Pro isn’t active yet. Try Restore purchases."
                Haptics.play(.warning)
                Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notActivated))
            }
        case .cancelled:
            Analytics.track(.purchaseCancelled(product: option.id, feature: feature))
        case .pending:
            message = "Your purchase is waiting for approval. Pro unlocks as soon as it’s approved."
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .pending))
        case .failed(let failure, let text):
            message = text
            Haptics.play(.error)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: failure))
        }
        return isPro
    }

    // MARK: Tips

    /// Buys a tip. It unlocks nothing; success sets `thankYouForTip`.
    func tip(_ tip: TipOption) async {
        Analytics.track(.tipStarted(product: tip.id))
        guard let product = products[tip.id] else {
            message = "Tips aren’t available right now. Check your connection and try again."
            Haptics.play(.warning)
            Analytics.track(.tipFailed(product: tip.id, reason: .unavailable))
            await loadStorefront()
            return
        }
        tipping = tip.id
        defer { tipping = nil }
        switch await buy(product) {
        case .delivered:
            Haptics.play(.purchaseComplete)
            Analytics.track(.tipCompleted(product: tip.id))
            thankYouForTip = tip
        case .cancelled:
            Analytics.track(.tipCancelled(product: tip.id))
        case .pending:
            message = "Your tip is waiting for approval. Thank you all the same."
            Haptics.play(.warning)
            Analytics.track(.tipFailed(product: tip.id, reason: .pending))
        case .failed(let failure, let text):
            message = text
            Haptics.play(.error)
            Analytics.track(.tipFailed(product: tip.id, reason: failure))
        }
    }

    // MARK: Restore

    func restore(source: RestoreSource) async {
        Analytics.track(.restoreStarted(source: source))
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            Analytics.track(.restoreFailed)
            return
        } catch {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
            Analytics.track(.restoreFailed)
            Analytics.error(.restore, error)
            return
        }
        await refreshEntitlements()
        message = if isPro {
            "Advent Praise Pro has been restored."
        } else if ownedProductIDs.isEmpty {
            "No previous purchases were found for this Apple Account."
        } else {
            "Your purchases have been restored. Advent Praise Pro isn’t among them."
        }
        Haptics.play(isPro ? .success : .warning)
        Analytics.track(.restoreCompleted(foundPurchases: !ownedProductIDs.isEmpty, proActive: isPro))
    }

    // MARK: Private

    private enum BuyOutcome {
        /// Verified and finished.
        case delivered
        case cancelled
        /// Ask to Buy, or the bank wants a check: `Transaction.updates` delivers it later.
        case pending
        case failed(PurchaseFailure, String)
    }

    /// One purchase through the App Store sheet. A verified transaction is
    /// finished here; an unverified one is never delivered or finished.
    private func buy(_ product: Product) async -> BuyOutcome {
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                return .delivered
            case .success(.unverified(_, let error)):
                Analytics.error(.purchase, error)
                return .failed(.unverified, "The App Store couldn’t confirm this purchase. Try Restore purchases in a moment.")
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(.storeError, "The purchase didn’t go through. You haven’t been charged.")
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch StoreKitError.networkError {
            return .failed(.storeError, "Couldn’t reach the App Store. Check your connection and try again. You haven’t been charged.")
        } catch Product.PurchaseError.purchaseNotAllowed {
            return .failed(.notAllowed, "Purchases aren’t allowed on this device. Check Screen Time in Settings.")
        } catch {
            Analytics.error(.purchase, error)
            return .failed(.storeError, "The purchase didn’t go through. You haven’t been charged.")
        }
    }

    /// A transaction from outside a purchase call. Pro is re-read; a tip
    /// that was waiting for approval gets its thank-you.
    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = update else {
            if case .unverified(_, let error) = update { Analytics.error(.purchase, error) }
            return
        }
        if transaction.productType == .consumable, transaction.revocationDate == nil,
           let tip = tips.first(where: { $0.id == transaction.productID }) {
            thankYouForTip = tip
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Reads what this Apple Account owns. Revoked (refunded) purchases are
    /// not in `currentEntitlements`, so a refund takes Pro away.
    private func refreshEntitlements() async {
        var owned: Set<String> = []
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
        isPro = owned.contains(PurchaseConfig.proProductID)
        #if DEBUG
        if DebugLaunch.pro { isPro = true }
        if DebugLaunch.free { isPro = false }
        #endif
        hasLoadedEntitlements = true
        Analytics.setPro(isPro)
    }
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
