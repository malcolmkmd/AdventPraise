//
//  PurchaseStore.swift
//  Advent Praise
//
//  Purchases through RevenueCat (PurchasesClient.swift). Every hymnal is
//  free. Pro, the RevenueCat entitlement `pro`, unlocks the accompaniment
//  player beyond its free plays (FreePlays.swift), AirPlay to a church
//  screen, sheet music and the rest of what the paywall lists. It is sold
//  as two subscriptions on the current offering: annual
//  (`ap_pro_annual`, `$rc_annual`) and monthly (`ap_pro_monthly`,
//  `$rc_monthly`). Either plan may carry the store's free trial. Pro bought
//  once in 7.0.x (`ap_pro_lifetime`) and 7.0.1's MIDI Piano unlock the same
//  entitlement for life. The paywall's prices, trial and order come from
//  the RevenueCat offering, never from the app. With no experiment metadata
//  that is annual first. A missing monthly package leaves annual on sale.
//  Tips are one-off consumables
//  that unlock nothing. "Restore purchases" re-syncs the Apple Account's
//  purchases with the App Store, including those made in the 6.x app.
//
//  What is owned is whatever RevenueCat's CustomerInfo says: read at launch,
//  after every purchase and restore, and on every change it reports (Ask to
//  Buy approvals, refunds, purchases on another device). A blip doesn't
//  take Pro away: the cached CustomerInfo, or the last Pro this install
//  knew, stays until a fetch succeeds. Offerings and CustomerInfo are
//  tried again a couple of times first. The rules are `Entitlements`, in
//  PurchaseConfig.
//
//  The paywall and the Support screen only ever see plain values
//  (`UnlockOption`, `TipOption`). Each loads on its own: Pro missing never
//  empties the tips screen, and a missing tip never hides the paywall's buy
//  button.
//

import Network
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

/// Pro as the paywall sells one plan of it: a package from the offering, its
/// price and free trial as the App Store gives them, and whether this Apple
/// Account can still have the trial.
struct UnlockOption: Identifiable, Equatable, Sendable {
    let package: OfferingPackage
    /// Checked with the App Store after the offering loads; false until then.
    var isTrialEligible = false

    /// The App Store product ID ("ap_pro_annual"); analytics sends this.
    var id: String { package.productID }
    /// The App Store's localized price: "R299.99".
    var price: String { package.price }
    /// The free trial this buyer would get, if any.
    var trial: SubscriptionTerm? { isTrialEligible ? package.freeTrial : nil }

    /// "Annual" or "Monthly", from the store's period.
    var planName: String {
        switch package.period?.unit {
        case .year: String(localized: "Annual")
        case .month: String(localized: "Monthly")
        case .week: String(localized: "Weekly")
        case .day: String(localized: "Daily")
        case nil: String(localized: "Pro")
        }
    }

    /// The store price with its period: "R299.99/year".
    var priceLine: String { Self.recurring(price: price, period: package.period) }

    /// "3 days free", from the store's trial. Nil when this plan has none.
    var trialCallout: String? {
        guard let trial else { return nil }
        return String(localized: "\(Self.length(trial)) free")
    }

    /// "3 days free, then R299.99/year. Cancel anytime." Without the trial:
    /// "R299.99/year. Cancel anytime."
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

    /// "R299.99/year"
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

/// How much the annual plan saves against twelve months of the monthly plan.
/// Built only from the two store prices. Nil when either price is missing,
/// the currencies differ, or a year of monthly is not more expensive.
struct AnnualSaving: Equatable, Sendable {
    /// Whole percent, rounded to the nearest percent. At least 1.
    let percent: Int
    /// Amount saved over a year, in `currencyCode`.
    let amount: Decimal
    let currencyCode: String

    static func compare(annual: OfferingPackage, monthly: OfferingPackage) -> AnnualSaving? {
        guard let annualAmount = annual.priceAmount, let monthlyAmount = monthly.priceAmount,
              let currency = annual.currencyCode, currency == monthly.currencyCode,
              monthlyAmount > 0 else { return nil }
        let yearOfMonthly = monthlyAmount * Decimal(12)
        let saved = yearOfMonthly - annualAmount
        guard saved > 0 else { return nil }
        let percent = wholePercent(saved: saved, of: yearOfMonthly)
        guard percent >= 1 else { return nil }
        return AnnualSaving(percent: percent, amount: saved, currencyCode: currency)
    }

    /// "Best value · Save R59.89 a year · 17%", or the percent alone when the
    /// amount can't be formatted. The figures come from `compare`.
    func label(locale: Locale = .current) -> String {
        if let formatted = formattedAmount(locale: locale) {
            return String(localized: "Best value · Save \(formatted) a year · \(percent)%")
        }
        return String(localized: "Best value · Save \(percent)%")
    }

    func formattedAmount(locale: Locale = .current) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    private static func wholePercent(saved: Decimal, of total: Decimal) -> Int {
        var ratio = (saved / total) * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &ratio, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
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
    var annual: UnlockOption?
    var monthly: UnlockOption?
    var tips: [TipOption] = []
    /// Variant A until an offering loads. The loaded offering's metadata replaces it.
    var experiment: PaywallExperiment = .unknown

    /// The plan a single control buys: annual when it loaded, otherwise monthly.
    var proOption: UnlockOption? { annual ?? monthly }
    /// True only when neither subscription loaded. Monthly missing still leaves annual.
    var proFailed: Bool { proOption == nil }
    var tipsFailed: Bool { tips.isEmpty }
    /// Something is missing somewhere (for logging; the screens ask their own).
    var anyFailed: Bool { proFailed || tipsFailed }

    /// The paywall's two Pro plans, taken from the current offering by product
    /// id. Annual is `ap_pro_annual`, preferring the `$rc_annual` package, then
    /// any other package of that product. Monthly is `ap_pro_monthly`, preferring
    /// `$rc_monthly`, the same way. Lifetime, MIDI, tips and a package that only
    /// shares a RevenueCat id are ignored. Either plan may be absent.
    /// Annual then monthly, unless the offering's `first_package` names the other one.
    var orderedPlans: [UnlockOption] {
        let plans = [annual, monthly].compactMap { $0 }
        guard let first = plans.firstIndex(where: { $0.package.id == experiment.firstPackageID }) else {
            return plans
        }
        return Array(plans[first...]) + Array(plans[..<first])
    }

    static func from(offering: OfferingSnapshot?, tipPrices: [String: String]) -> Storefront {
        let packages = offering?.packages ?? []
        let experiment = offering.map { PaywallExperiment.parsing(metadata: $0.metadata, offeringID: $0.id) } ?? .unknown
        return Storefront(
            annual: package(in: packages, productID: PurchaseConfig.proProductID, packageID: PurchaseConfig.proPackageID)
                .map { UnlockOption(package: $0) },
            monthly: package(in: packages, productID: PurchaseConfig.monthlyProductID, packageID: PurchaseConfig.monthlyPackageID)
                .map { UnlockOption(package: $0) },
            tips: PurchaseConfig.tips.compactMap { definition in
                tipPrices[definition.productID].map { definition.option(price: $0) }
            },
            experiment: experiment)
    }

    /// The named package of this product, or the first package of the product
    /// when the offering uses another package id.
    private static func package(in packages: [OfferingPackage], productID: String, packageID: String) -> OfferingPackage? {
        let matches = packages.filter { $0.productID == productID }
        return matches.first { $0.id == packageID } ?? matches.first
    }

    /// `next` where it found something, what was here before where it didn't.
    func keeping(_ next: Storefront) -> Storefront {
        Storefront(annual: next.annual ?? annual, monthly: next.monthly ?? monthly,
                   tips: next.tips.isEmpty ? tips : next.tips,
                   experiment: next.experiment.isKnown ? next.experiment : experiment)
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

    /// The last CustomerInfo this install trusted. Kept so a later launch
    /// can stay Pro when RevenueCat's own cache is empty and the network isn't.
    static let rememberedCustomerKey = "purchase.rememberedCustomer"

    @ObservationIgnored private let client: any PurchasesClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let retryDelay: @MainActor (Duration) async throws -> Void
    @ObservationIgnored private let onProPurchaseCancelled: @MainActor (Bool) -> Void
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var pathLatch: PathLatch?
    /// A load of prices failed and hasn't succeeded since. The next time
    /// the path comes back, that load is tried again.
    @ObservationIgnored private var storefrontLoadFailed = false
    /// The load already running, so a second caller waits for it instead of
    /// starting another or returning before the offering is known.
    @ObservationIgnored private var loadInFlight: Task<Void, Never>?

    init(client: any PurchasesClient,
         defaults: UserDefaults = .standard,
         retryDelay: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
         onProPurchaseCancelled: @escaping @MainActor (Bool) -> Void = { PurchaseCancelReviewCenter.shared.consider(isPro: $0) }) {
        self.client = client
        self.defaults = defaults
        self.retryDelay = retryDelay
        self.onProPurchaseCancelled = onProPurchaseCancelled
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

    /// Annual when it loaded, otherwise monthly. Nil when neither could be loaded.
    var proOption: UnlockOption? { storefront.proOption }
    /// The annual plan, when the offering included it.
    var annualOption: UnlockOption? { storefront.annual }
    /// The monthly plan, when the offering included it. Nil leaves annual on sale.
    var monthlyOption: UnlockOption? { storefront.monthly }
    /// The offering's first package, then the other. Annual first when the
    /// offering doesn't say. A plan that didn't load is left out.
    var proPlans: [UnlockOption] { storefront.orderedPlans }
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
        // Before the fetch, so a Pro customer is never drawn as free while
        // the network is still being asked. A remembered Pro outranks a
        // cache that doesn't say Pro; a successful fetch below replaces both.
        let cached = client.cachedCustomer()
        let remembered = rememberedCustomer()
        if cached?.isPro == true, let cached {
            apply(cached, remember: true, markLoaded: false)
        } else if remembered?.isPro == true, let remembered {
            apply(remembered, remember: false, markLoaded: false)
        } else if let cached {
            apply(cached, remember: false, markLoaded: false)
        }
        startConnectivityWatch()
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
        if let existing = loadInFlight {
            await existing.value
            return
        }
        isLoadingOptions = true
        let task = Task { await self.performLoad() }
        loadInFlight = task
        await task.value
        loadInFlight = nil
    }

    private func performLoad() async {
        defer { isLoadingOptions = false }
        var offering: OfferingSnapshot?
        var fetchFailed = false
        do {
            offering = try await StoreFetchRetry.run(sleep: retryDelay) {
                try await self.client.offering(id: PurchaseConfig.offeringID)
            }
        } catch is CancellationError {
            return
        } catch {
            // One event for the last try, not one for each. Prices kept from
            // an earlier load stay on screen (`keeping` below).
            fetchFailed = true
            Analytics.error(.products, code: "offering.\(StoreErrorReport.analyticsCode(error))", error)
        }
        let tipPrices = await client.prices(of: PurchaseConfig.tipProductIDs)
        var next = Storefront.from(offering: offering, tipPrices: tipPrices)
        if var annual = next.annual {
            annual.isTrialEligible = await client.isEligibleForTrial(annual.package)
            next.annual = annual
        }
        if var monthly = next.monthly {
            monthly.isTrialEligible = await client.isEligibleForTrial(monthly.package)
            next.monthly = monthly
        }
        storefront = storefront.keeping(next)
        if storefront.experiment.isKnown { Analytics.setPaywallExperiment(storefront.experiment) }
        if storefront.proFailed, !fetchFailed { Analytics.error(.products, code: "no_pro_option") }
        if storefront.tipsFailed, !fetchFailed { Analytics.error(.products, code: "no_tips") }
        storefrontLoadFailed = storefront.proFailed || storefront.tipsFailed
    }

    // MARK: Pro

    /// Buys Pro. True when Pro is active afterwards. Haptics: the purchase
    /// flourish on success, an error when it fails, nothing if the buyer
    /// cancels. `feature` is what the paywall led with, for analytics; the
    /// product is sent as its ID, never a price.
    @discardableResult
    func purchase(_ option: UnlockOption, feature: ProFeature) async -> Bool {
        let experiment = storefront.experiment
        Analytics.track(.purchaseStarted(product: option.id, feature: feature, experiment: experiment))
        purchasingID = option.id
        defer { purchasingID = nil }
        switch await client.purchase(package: option.package) {
        case .completed(let customer):
            apply(customer)
            if isPro {
                Haptics.play(.purchaseComplete)
                Analytics.track(.purchaseCompleted(product: option.id, feature: feature, experiment: experiment))
            } else {
                message = String(localized: "The purchase went through, but Advent Praise Pro isn’t active yet. Try Restore purchases.")
                Haptics.play(.warning)
                Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .notActivated, experiment: experiment))
            }
        case .cancelled:
            Analytics.track(.purchaseCancelled(product: option.id, feature: feature, experiment: experiment))
            // Tips have their own purchase path and don't come through here.
            onProPurchaseCancelled(isPro)
        case .pending:
            message = String(localized: "Your purchase is waiting for approval. Advent Praise Pro unlocks as soon as it’s approved.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .pending, experiment: experiment))
        case .failed(.unavailable, _):
            message = String(localized: "Advent Praise Pro isn’t available right now. Check your connection and try again.")
            Haptics.play(.warning)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: .unavailable, experiment: experiment))
            await loadStorefront()
        case .failed(let failure, let text):
            message = text
            Haptics.play(.error)
            Analytics.track(.purchaseFailed(product: option.id, feature: feature, reason: failure, experiment: experiment))
        }
        return isPro
    }

    #if DEBUG
    /// Prices already in hand, so a SwiftUI preview doesn't wait on the App Store.
    func seeded(_ storefront: Storefront) -> PurchaseStore {
        self.storefront = storefront
        return self
    }
    #endif

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

    /// The paywall's prices failed to load, and the path has come back.
    /// Does nothing when the last load succeeded.
    func connectivityRestored() async {
        guard storefrontLoadFailed else { return }
        await loadStorefront()
    }

    private func refreshEntitlements() async {
        do {
            let fresh = try await StoreFetchRetry.run(sleep: retryDelay) {
                try await self.client.customer()
            }
            apply(fresh, remember: true, markLoaded: true)
        } catch is CancellationError {
            return
        } catch {
            // The cache or the remembered Pro, applied in `start`, stays.
            // One event, with RevenueCat's code, not one per try.
            if !hasLoadedEntitlements { hasLoadedEntitlements = true }
            Analytics.error(.purchase, code: "customer_info.\(StoreErrorReport.analyticsCode(error))", error)
        }
    }

    private func apply(_ customer: CustomerSnapshot, remember: Bool = true, markLoaded: Bool = true) {
        #if DEBUG
        if let forced = Self.forcedEntitlements {
            entitlements = forced
            hasLoadedEntitlements = true
            Analytics.setEntitlements(entitlements)
            return
        }
        #endif
        entitlements = Entitlements(active: customer.activeEntitlements, purchased: customer.purchasedProductIDs)
        if remember { self.remember(customer) }
        if markLoaded { hasLoadedEntitlements = true }
        Analytics.setEntitlements(entitlements)
    }

    private func rememberedCustomer() -> CustomerSnapshot? {
        guard let data = defaults.data(forKey: Self.rememberedCustomerKey) else { return nil }
        return try? JSONDecoder().decode(CustomerSnapshot.self, from: data)
    }

    private func remember(_ customer: CustomerSnapshot) {
        guard let data = try? JSONEncoder().encode(customer) else { return }
        defaults.set(data, forKey: Self.rememberedCustomerKey)
    }

    /// Posts back here when the path returns after being unsatisfied.
    /// Skipped under XCTest; tests call `connectivityRestored` themselves.
    private func startConnectivityWatch() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil {
            return
        }
        #endif
        guard pathMonitor == nil else { return }
        let latch = PathLatch()
        let monitor = NWPathMonitor()
        pathLatch = latch
        pathMonitor = monitor
        StoreConnectivityHub.store = self
        monitor.pathUpdateHandler = { path in
            guard latch.note(online: path.status == .satisfied) else { return }
            Task { @MainActor in
                await StoreConnectivityHub.store?.connectivityRestored()
            }
        }
        monitor.start(queue: DispatchQueue(label: "adventpraise.connectivity"))
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

/// The store the path monitor calls. The monitor's callback can't capture
/// the store (it isn't sendable); it hops back to the main actor through this.
@MainActor
enum StoreConnectivityHub {
    static weak var store: PurchaseStore?
}

/// Remembers that the path was unsatisfied, and reports the moment it isn't.
private final class PathLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var offline = false

    /// True only on the change from offline to online.
    func note(online: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if online {
            let returned = offline
            offline = false
            return returned
        }
        offline = true
        return false
    }
}
