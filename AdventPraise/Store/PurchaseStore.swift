//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through StoreKit 2, with no server and no SDK. Every hymnal is
//  free. Pro, owning `PurchaseConfig.proProductID`, unlocks the
//  accompaniment player beyond its free plays (FreePlays.swift), AirPlay
//  to a church screen and the rest of what the paywall lists. MIDI Piano,
//  owning `PurchaseConfig.midiProductID`, unlocks the player alone. Both
//  are bought once (non-consumables, no subscription, no trial); their
//  prices come from the App Store, never from the app. Tips are one-off
//  consumables that unlock nothing. "Restore purchases" re-syncs the Apple
//  Account's purchases with the App Store (`AppStore.sync()`), including
//  those made in the 6.x app.
//
//  What is owned is whatever `Transaction.currentEntitlements` says, read at
//  launch and again after every purchase, restore and `Transaction.updates`
//  (Ask to Buy approvals, refunds, purchases on another device). A verified
//  transaction a purchase call returns counts at once, before
//  `currentEntitlements` has caught up. Every verified transaction is
//  finished once it has been delivered. The rules (Pro or MIDI opens the
//  player; everything else needs Pro) are `Entitlements`, in PurchaseConfig.
//
//  The paywall and the Support screen only ever see plain values
//  (`UnlockOption`, `TipOption`); the StoreKit products behind them stay in
//  here. Each product loads on its own: Pro missing never empties the tips
//  screen, and a missing tip never hides the paywall's buy button.
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

/// The two one-time unlocks the paywall sells.
enum Unlock: String, Sendable, CaseIterable {
    case pro, midi

    var productID: String {
        switch self {
        case .pro: PurchaseConfig.proProductID
        case .midi: PurchaseConfig.midiProductID
        }
    }

    /// The product by its ID; nil for a tip or a 6.x hymnal.
    init?(productID: String) {
        guard let unlock = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = unlock
    }

    /// How the purchase messages name it.
    var name: String {
        switch self {
        case .pro: String(localized: "Advent Praise Pro")
        case .midi: String(localized: "the MIDI piano")
        }
    }
}

/// An unlock as the paywall sells it: one product, one price, bought once.
/// The price comes from the App Store.
struct UnlockOption: Identifiable, Equatable, Sendable {
    let unlock: Unlock
    /// The App Store's localized price: "R199.99".
    let price: String

    /// The App Store product ID.
    var id: String { unlock.productID }

    static func == (a: UnlockOption, b: UnlockOption) -> Bool { a.id == b.id }
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

/// What one load of the App Store produced, judged per screen: the paywall
/// needs Pro, the player's paywall also offers MIDI Piano, and the Support
/// screen needs the tips. Each is missing on its own; none spoils another.
struct Storefront: Equatable, Sendable {
    var proOption: UnlockOption?
    var midiOption: UnlockOption?
    var tips: [TipOption] = []

    var proFailed: Bool { proOption == nil }
    var midiFailed: Bool { midiOption == nil }
    var tipsFailed: Bool { tips.isEmpty }
    /// Something is missing somewhere (for logging; the screens ask their own).
    var anyFailed: Bool { proFailed || midiFailed || tipsFailed }

    /// Builds the options from the prices that did load, by product ID.
    static func from(prices: [String: String]) -> Storefront {
        Storefront(
            proOption: prices[PurchaseConfig.proProductID].map { UnlockOption(unlock: .pro, price: $0) },
            midiOption: prices[PurchaseConfig.midiProductID].map { UnlockOption(unlock: .midi, price: $0) },
            tips: PurchaseConfig.tips.compactMap { definition in
                prices[definition.productID].map { definition.option(price: $0) }
            })
    }
}

@Observable
@MainActor
final class PurchaseStore {
    private(set) var isRestoring = false
    /// True once the entitlements have been read at least once.
    private(set) var hasLoadedEntitlements = false
    /// What this Apple Account owns, and the rules for what that opens.
    private(set) var entitlements: Entitlements = .none
    /// The options loaded from the App Store, each nil until loaded or when it couldn't be.
    private(set) var storefront = Storefront()
    private(set) var isLoadingOptions = false
    /// The product being bought (Pro or MIDI Piano), while the App Store sheet is up.
    private(set) var purchasingID: String?
    /// The tip being bought.
    private(set) var tipping: String?
    /// A tip went through; the Support screen shows its thank-you until this is cleared.
    var thankYouForTip: TipOption?
    var message: String?

    private var updates: Task<Void, Never>?
    private var products: [String: Product] = [:]

    // MARK: Shorthands

    /// Pro is owned by this Apple Account.
    var isPro: Bool { entitlements.isPro }
    /// MIDI Piano was bought on its own.
    var ownsMIDI: Bool { entitlements.ownsMIDI }
    /// The MIDI player beyond its free plays is open: Pro, or MIDI Piano.
    var isPlayerUnlocked: Bool { entitlements.unlocksPlayer }
    /// Whether `feature` is open for this account.
    func unlocks(_ feature: ProFeature) -> Bool { entitlements.unlocks(feature) }

    /// The one way to buy Pro; nil until loaded, or when it couldn't be.
    var proOption: UnlockOption? { storefront.proOption }
    /// MIDI Piano alone; nil until loaded, or when it couldn't be.
    var midiOption: UnlockOption? { storefront.midiOption }
    var tips: [TipOption] { storefront.tips }
    /// Pro's price couldn't be loaded (offline, or not set up yet): the paywall offers Try again.
    var proOptionFailed: Bool { !isLoadingOptions && storefront.proFailed }
    /// MIDI Piano's price couldn't be loaded: the player's paywall shows Pro alone.
    var midiOptionFailed: Bool { !isLoadingOptions && storefront.midiFailed }
    /// No tip loaded: the Support screen offers Try again.
    var tipsFailed: Bool { !isLoadingOptions && storefront.tipsFailed }
    /// True while an unlock is being bought.
    var purchasing: Bool { purchasingID != nil }

    /// Listens for transactions made outside a purchase call (Ask to Buy,
    /// another device, refunds, interrupted purchases) and reads what the
    /// Apple Account owns. Called once, at launch.
    func start() {
        guard updates == nil else { return }
        #if DEBUG
        if DebugLaunch.pro || DebugLaunch.midi || DebugLaunch.free {
            Task { await refreshEntitlements() }
            return
        }
        #endif
        updates = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: Loading

    /// Loads the prices of Pro, MIDI Piano and the tips from the App Store.
    /// Every product is judged on its own: what came back is offered, what
    /// didn't is reported for its screen alone. Products already loaded are
    /// kept, so a retry only has to find the missing ones.
    func loadStorefront() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        defer { isLoadingOptions = false }
        let missing = PurchaseConfig.allProductIDs.filter { products[$0] == nil }
        if !missing.isEmpty {
            do {
                for product in try await Product.products(for: missing) { products[product.id] = product }
            } catch {
                Analytics.error(.products, error)
            }
        }
        storefront = .from(prices: products.mapValues(\.displayPrice))
        if storefront.proFailed { Analytics.error(.products, code: "no_pro_option") }
        if storefront.midiFailed { Analytics.error(.products, code: "no_midi_option") }
        if storefront.tipsFailed { Analytics.error(.products, code: "no_tips") }
    }

    // MARK: Unlocks

    /// Buys Pro or MIDI Piano. True when what was bought is owned afterwards.
    /// Haptics: the purchase flourish on success, an error when it fails,
    /// nothing if the buyer cancels. `feature` is what the paywall led with,
    /// for analytics; the product is sent as its ID, never a price.
    @discardableResult
    func purchase(_ option: UnlockOption, feature: ProFeature) async -> Bool {
        Analytics.track(.purchaseStarted(product: option.id, feature: feature))
        let name = option.unlock.name
        guard let product = products[option.id] else {
            message = String(localized: "\(name.prefix(1).uppercased() + name.dropFirst()) isn’t available right now. Check your connection and try again.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .unavailable))
            await loadStorefront()
            return false
        }
        purchasingID = option.id
        defer { purchasingID = nil }
        switch await buy(product) {
        case .delivered(let transaction):
            // Trust the verified transaction we were just handed:
            // `currentEntitlements` can lag a moment behind a purchase (very
            // visibly in Xcode's StoreKit testing on a device), which made a
            // real purchase report "Pro isn't active yet".
            await refreshEntitlements(including: transaction)
            if entitlements.owned.contains(option.id) {
                Haptics.play(.purchaseComplete)
                Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
            } else {
                message = String(localized: "The purchase went through, but \(name) isn’t active yet. Try Restore purchases.")
                Haptics.play(.warning)
                Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notActivated))
            }
        case .cancelled:
            Analytics.track(.purchaseCancelled(product: option.id, feature: feature))
        case .pending:
            message = String(localized: "Your purchase is waiting for approval. \(name.prefix(1).uppercased() + name.dropFirst()) unlocks as soon as it’s approved.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .pending))
        case .failed(let failure, let text):
            message = text
            Haptics.play(.error)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: failure))
        }
        return entitlements.owned.contains(option.id)
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

    /// Re-syncs the Apple Account's purchases: Pro, MIDI Piano and the 6.x
    /// hymnals alike.
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
        } else if ownsMIDI {
            "The MIDI piano has been restored. Advent Praise Pro isn’t among your purchases."
        } else if entitlements.owned.isEmpty {
            "No previous purchases were found for this Apple Account."
        } else {
            "Your purchases have been restored. Advent Praise Pro isn’t among them."
        }
        Haptics.play(isPlayerUnlocked ? .success : .warning)
        Analytics.track(.restoreCompleted(foundPurchases: !entitlements.owned.isEmpty, proActive: isPro))
    }

    // MARK: Private

    private enum BuyOutcome {
        /// Verified and finished; the transaction itself proves ownership.
        case delivered(StoreKit.Transaction)
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
                return .delivered(transaction)
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

    /// A transaction from outside a purchase call. What is owned is re-read
    /// (the transaction itself counts at once); a tip that was waiting for
    /// approval gets its thank-you.
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
        await refreshEntitlements(including: transaction)
    }

    /// Reads what this Apple Account owns. Revoked (refunded) purchases are
    /// not in `currentEntitlements`, so a refund takes an unlock away.
    /// `including`: a verified transaction just delivered (a purchase or an
    /// update), counted even if `currentEntitlements` hasn't caught up yet.
    private func refreshEntitlements(including delivered: StoreKit.Transaction? = nil) async {
        #if DEBUG
        // -uiDebugPro / -uiDebugMIDI / -uiDebugFree: the answer is given, so the
        // App Store isn't asked (a simulator without a StoreKit configuration
        // would put up the sandbox sign-in over every screenshot).
        if DebugLaunch.pro || DebugLaunch.midi || DebugLaunch.free {
            var forced: Set<String> = []
            if DebugLaunch.pro { forced.insert(PurchaseConfig.proProductID) }
            if DebugLaunch.midi { forced.insert(PurchaseConfig.midiProductID) }
            if DebugLaunch.free { forced = [] }
            entitlements = Entitlements(owned: forced)
            hasLoadedEntitlements = true
            Analytics.setEntitlements(entitlements)
            return
        }
        #endif
        var owned: Set<String> = []
        if let delivered, delivered.revocationDate == nil, delivered.productType != .consumable {
            owned.insert(delivered.productID)
        }
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        entitlements = Entitlements(owned: owned)
        hasLoadedEntitlements = true
        Analytics.setEntitlements(entitlements)
    }
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
