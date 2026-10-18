//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat (PurchasesClient.swift). Every hymnal is
//  free. Pro, the RevenueCat entitlement `pro`, unlocks the accompaniment
//  player beyond its free plays (FreePlays.swift), AirPlay to a church
//  screen, sheet music and the rest of what the paywall lists. It is sold
//  as an annual subscription (`ap_pro_annual`, the `$rc_annual` package)
//  with a 3-day free trial for new subscribers; Pro bought once in 7.0.x
//  (`ap_pro_lifetime`) and 7.0.1's MIDI Piano unlock the same entitlement
//  for life. The paywall's price and trial come from the RevenueCat
//  offering, never from the app. Tips are one-off consumables
//  that unlock nothing. "Restore purchases" re-syncs the Apple Account's
//  purchases with the App Store, including those made in the 6.x app.
//
//  What is owned is whatever RevenueCat's CustomerInfo says: read at launch,
//  after every purchase and restore, and on every change it reports (Ask to
//  Buy approvals, refunds, purchases on another device). The rules are
//  `Entitlements`, in PurchaseConfig.
//
//  The paywall and the Support screen only ever see plain values
//  (`UnlockOption`, `TipOption`). Each loads on its own: Pro missing never
//  empties the tips screen, and a missing tip never hides the paywall's buy
//  button.
//

import Observation
import SwiftUI

/// Something Pro unlocks; the paywall leads with it.
enum ProFeature: String, Identifiable, Sendable {
    case player, airPlay
    /// The Go Pro banner on a mirrored screen (ScreenMirroring.swift).
    case mirroring
    /// Opened from More, not by a locked feature.
    case support
    /// The whole page of a hymn's sheet music (SheetMusicView.swift). Hymn
    /// of the Day's is free; the rest shows its top and this gate.
    case sheetMusic
    var id: String { rawValue }
}

/// Pro as the paywall sells it: the offering's annual package, its price
/// and free trial as the App Store gives them, and whether this Apple
/// Account can still have the trial.
struct UnlockOption: Identifiable, Equatable, Sendable {
    let package: OfferingPackage
    /// Checked with the App Store after the offering loads; false until then.
    var isTrialEligible = false

    /// The App Store product ID ("ap_pro_annual"); analytics sends this.
    var id: String { package.productID }
    /// The App Store's localized price: "R199.99".
    var price: String { package.price }
    /// The free trial this buyer would get, if any.
    var trial: SubscriptionTerm? { isTrialEligible ? package.freeTrial : nil }

    /// "3 days free, then R199.99/year. Cancel anytime." Without the trial:
    /// "R199.99/year. Cancel anytime."
    var offerLine: String {
        let recurring = Self.recurring(price: price, period: package.period)
        guard let trial else { return String(localized: "\(recurring). Cancel anytime.") }
        return String(localized: "\(Self.length(trial)) free, then \(recurring). Cancel anytime.")
    }

    /// "Start 3-Day Free Trial", or "Subscribe" without one.
    var callToAction: String {
        guard let trial else { return String(localized: "Subscribe") }
        return String(localized: "Start \(Self.adjective(trial)) Free Trial")
    }

    /// Apple's auto-renewal disclosure, under the offer.
    var renewalTerms: String {
        let period = package.period.map(Self.periodName) ?? String(localized: "period")
        let charge = trial == nil
            ? String(localized: "Payment is charged to your Apple Account when you confirm.")
            : String(localized: "Payment is charged to your Apple Account when the free trial ends.")
        return String(localized: "\(charge) Renews automatically each \(period) unless cancelled at least 24 hours before the end of the current \(period). Manage or cancel in your App Store account settings.")
    }

    /// "R199.99/year"
    static func recurring(price: String, period: SubscriptionTerm?) -> String {
        guard let period else { return price }
        return period.value == 1 ? "\(price)/\(periodName(period))" : "\(price)/\(length(period))"
    }

    static func periodName(_ term: SubscriptionTerm) -> String {
        switch term.unit {
        case .day: String(localized: "day")
        case .week: String(localized: "week")
        case .month: String(localized: "month")
        case .year: String(localized: "year")
        }
    }

    /// "3 days", "1 week"
    static func length(_ term: SubscriptionTerm) -> String {
        switch term.unit {
        case .day: term.value == 1 ? String(localized: "1 day") : String(localized: "\(term.value) days")
        case .week: term.value == 1 ? String(localized: "1 week") : String(localized: "\(term.value) weeks")
        case .month: term.value == 1 ? String(localized: "1 month") : String(localized: "\(term.value) months")
        case .year: term.value == 1 ? String(localized: "1 year") : String(localized: "\(term.value) years")
        }
    }

    /// "3-Day", "1-Week"
    static func adjective(_ term: SubscriptionTerm) -> String {
        switch term.unit {
        case .day: String(localized: "\(term.value)-Day")
        case .week: String(localized: "\(term.value)-Week")
        case .month: String(localized: "\(term.value)-Month")
        case .year: String(localized: "\(term.value)-Year")
        }
    }
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

/// What one load produced, judged per screen: the paywall needs Pro from
/// the offering, the Support screen needs the tips. Each is missing on its
/// own; neither spoils the other.
struct Storefront: Equatable, Sendable {
    var proOption: UnlockOption?
    var tips: [TipOption] = []

    var proFailed: Bool { proOption == nil }
    var tipsFailed: Bool { tips.isEmpty }
    /// Something is missing somewhere (for logging; the screens ask their own).
    var anyFailed: Bool { proFailed || tipsFailed }

    /// Pro is the offering's package that sells `ap_pro_annual` (the
    /// `$rc_annual` package first). Nothing else in the offering is sold
    /// here: never the Lifetime package, even while the offering carries it.
    /// No annual package: no Pro option (the paywall says so, with Try again).
    static func from(offering: OfferingSnapshot?, tipPrices: [String: String]) -> Storefront {
        let pro = offering?.packages.filter { $0.productID == PurchaseConfig.proProductID }
        let package = pro?.first { $0.id == PurchaseConfig.proPackageID } ?? pro?.first
        return Storefront(
            proOption: package.map { UnlockOption(package: $0) },
            tips: PurchaseConfig.tips.compactMap { definition in
                tipPrices[definition.productID].map { definition.option(price: $0) }
            })
    }

    /// `next` where it found something, what was here before where it didn't.
    func keeping(_ next: Storefront) -> Storefront {
        Storefront(proOption: next.proOption ?? proOption, tips: next.tips.isEmpty ? tips : next.tips)
    }
}

@Observable
@MainActor
final class PurchaseStore {
    private(set) var isRestoring = false
    /// True once the entitlements have been read at least once.
    private(set) var hasLoadedEntitlements = false
    /// What this customer has, and the rules for what that opens.
    private(set) var entitlements: Entitlements = .none
    /// The options loaded, each nil or empty until loaded or when it couldn't be.
    private(set) var storefront = Storefront()
    private(set) var isLoadingOptions = false
    /// The product being bought (Pro), while the App Store sheet is up.
    private(set) var purchasingID: String?
    /// The tip being bought.
    private(set) var tipping: String?
    /// A tip went through; the Support screen shows its thank-you until this is cleared.
    var thankYouForTip: TipOption?
    var message: String?

    @ObservationIgnored private let client: any PurchasesClient
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(client: any PurchasesClient) {
        self.client = client
    }

    convenience init() {
        self.init(client: PurchasesClients.live())
    }

    // MARK: Shorthands

    /// The `pro` entitlement is active.
    var isPro: Bool { entitlements.isPro }
    /// The MIDI player beyond its free plays is open.
    var isPlayerUnlocked: Bool { entitlements.unlocksPlayer }
    /// Whether `feature` is open for this account.
    func unlocks(_ feature: ProFeature) -> Bool { entitlements.unlocks(feature) }

    /// The one way to buy Pro; nil until loaded, or when it couldn't be.
    var proOption: UnlockOption? { storefront.proOption }
    var tips: [TipOption] { storefront.tips }
    /// Pro's price couldn't be loaded (offline, or not set up yet): the paywall offers Try again.
    var proOptionFailed: Bool { !isLoadingOptions && storefront.proFailed }
    /// No tip loaded: the Support screen offers Try again.
    var tipsFailed: Bool { !isLoadingOptions && storefront.tipsFailed }
    /// True while Pro is being bought.
    var purchasing: Bool { purchasingID != nil }

    /// Configures RevenueCat, then follows what this customer owns. Called
    /// once, at launch.
    func start() {
        guard updates == nil else { return }
        #if DEBUG
        if let forced = Self.forcedEntitlements {
            apply(CustomerSnapshot(activeEntitlements: forced.active, purchasedProductIDs: forced.purchased))
            return
        }
        #endif
        client.configure()
        guard client.isConfigured else {
            hasLoadedEntitlements = true
            Analytics.setEntitlements(entitlements)
            return
        }
        let stream = client.customerUpdates()
        updates = Task { [weak self] in
            for await customer in stream { self?.apply(customer) }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: Loading

    /// Loads the offering (Pro's package and price) and the tips' prices.
    /// Each is judged on its own: what came back is offered, what didn't is
    /// reported for its screen alone. What loaded before is kept, so a retry
    /// only has to find what is missing.
    func loadStorefront() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        defer { isLoadingOptions = false }
        var offering: OfferingSnapshot?
        do {
            offering = try await client.offering(id: PurchaseConfig.offeringID)
        } catch {
            Analytics.error(.products, error)
        }
        let tipPrices = await client.prices(of: PurchaseConfig.tipProductIDs)
        var next = Storefront.from(offering: offering, tipPrices: tipPrices)
        if let option = next.proOption {
            next.proOption?.isTrialEligible = await client.isEligibleForTrial(option.package)
        }
        storefront = storefront.keeping(next)
        if storefront.proFailed { Analytics.error(.products, code: "no_pro_option") }
        if storefront.tipsFailed { Analytics.error(.products, code: "no_tips") }
    }

    // MARK: Pro

    /// Buys Pro. True when Pro is active afterwards. Haptics: the purchase
    /// flourish on success, an error when it fails, nothing if the buyer
    /// cancels. `feature` is what the paywall led with, for analytics; the
    /// product is sent as its ID, never a price.
    @discardableResult
    func purchase(_ option: UnlockOption, feature: ProFeature) async -> Bool {
        Analytics.track(.purchaseStarted(product: option.id, feature: feature))
        purchasingID = option.id
        defer { purchasingID = nil }
        switch await client.purchase(package: option.package) {
        case .completed(let customer):
            apply(customer)
            if isPro {
                Haptics.play(.purchaseComplete)
                Analytics.track(.purchaseCompleted(product: option.id, feature: feature))
            } else {
                message = String(localized: "The purchase went through, but Advent Praise Pro isn’t active yet. Try Restore purchases.")
                Haptics.play(.warning)
                Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notActivated))
            }
        case .cancelled:
            Analytics.track(.purchaseCancelled(product: option.id, feature: feature))
        case .pending:
            message = String(localized: "Your purchase is waiting for approval. Advent Praise Pro unlocks as soon as it’s approved.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .pending))
        case .failed(.unavailable, _):
            message = String(localized: "Advent Praise Pro isn’t available right now. Check your connection and try again.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .unavailable))
            await loadStorefront()
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
        tipping = tip.id
        defer { tipping = nil }
        switch await client.purchase(productID: tip.id) {
        case .completed:
            Haptics.play(.purchaseComplete)
            Analytics.track(.tipCompleted(product: tip.id))
            thankYouForTip = tip
        case .cancelled:
            Analytics.track(.tipCancelled(product: tip.id))
        case .pending:
            message = "Your tip is waiting for approval. Thank you all the same."
            Haptics.play(.warning)
            Analytics.track(.tipFailed(product: tip.id, reason: .pending))
        case .failed(.unavailable, _):
            message = "Tips aren’t available right now. Check your connection and try again."
            Haptics.play(.warning)
            Analytics.track(.tipFailed(product: tip.id, reason: .unavailable))
            await loadStorefront()
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
        switch await client.restore() {
        case .cancelled:
            Analytics.track(.restoreFailed)
        case .failed:
            message = "Couldn’t restore purchases. Check your connection and try again."
            Haptics.play(.error)
            Analytics.track(.restoreFailed)
        case .restored(let customer):
            apply(customer)
            message = if isPro {
                "Advent Praise Pro has been restored."
            } else if !entitlements.hasPurchases {
                "No previous purchases were found for this Apple Account."
            } else {
                "Your purchases have been restored. Advent Praise Pro isn’t among them."
            }
            Haptics.play(isPro ? .success : .warning)
            Analytics.track(.restoreCompleted(foundPurchases: entitlements.hasPurchases, proActive: isPro))
        }
    }

    // MARK: Private

    private func refreshEntitlements() async {
        do {
            apply(try await client.customer())
        } catch {
            Analytics.error(.purchase, code: "customer_info", error)
        }
    }

    private func apply(_ customer: CustomerSnapshot) {
        #if DEBUG
        if let forced = Self.forcedEntitlements {
            entitlements = forced
            hasLoadedEntitlements = true
            Analytics.setEntitlements(entitlements)
            return
        }
        #endif
        entitlements = Entitlements(active: customer.activeEntitlements, purchased: customer.purchasedProductIDs)
        hasLoadedEntitlements = true
        Analytics.setEntitlements(entitlements)
    }

    #if DEBUG
    /// -uiDebugPro / -uiDebugFree: the answer is given, whatever RevenueCat says.
    private static var forcedEntitlements: Entitlements? {
        if DebugLaunch.free { return Entitlements.none }
        if DebugLaunch.pro {
            return Entitlements(active: [PurchaseConfig.proEntitlement], purchased: [PurchaseConfig.proProductID])
        }
        return nil
    }
    #endif
}

extension PurchaseStore {
    /// How a hymnal row should read. Every hymnal is free: current or not.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        hymnal.id == current.id ? .current : .owned
    }
}
