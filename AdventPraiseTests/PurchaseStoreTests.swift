//
//  PurchaseStoreTests.swift
//  AdventPraiseTests
//
//  The store against a stand-in for RevenueCat (no network, no App Store):
//  the paywall is fed from the offering, Pro bought is Pro, 7.0.1's MIDI
//  Piano is Pro, a tip unlocks nothing, Ask to Buy waits, a failed load
//  offers Try again on every screen, Restore finds Pro (or says what it
//  found), and changes RevenueCat reports (another device, a refund) reach
//  the app.
//

import Foundation
import Testing
@testable import Advent_Praise

/// RevenueCat as the store sees it, scripted per test.
@MainActor
final class FakePurchasesClient: PurchasesClient {
    nonisolated static let annual = OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
                                                    period: SubscriptionTerm(value: 1, unit: .year),
                                                    freeTrial: SubscriptionTerm(value: 3, unit: .day),
                                                    priceAmount: Decimal(string: "299.99"), currencyCode: "ZAR")
    nonisolated static let monthly = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R29.99",
                                                     period: SubscriptionTerm(value: 1, unit: .month),
                                                     priceAmount: Decimal(string: "29.99"), currencyCode: "ZAR")
    nonisolated static let lifetime = OfferingPackage(id: "$rc_lifetime", productID: "ap_pro_lifetime", price: "R349.99")
    nonisolated static let proCustomer = CustomerSnapshot(activeEntitlements: ["pro"], purchasedProductIDs: ["ap_pro_annual"])

    var isConfigured = true
    private(set) var configureCount = 0
    var customerNow = CustomerSnapshot()
    /// The live offering: monthly listed first, then Lifetime, then annual.
    /// The paywall still chooses the two subscriptions by product id.
    var offering: OfferingSnapshot? = OfferingSnapshot(id: "default", packages: [
        FakePurchasesClient.monthly, FakePurchasesClient.lifetime, FakePurchasesClient.annual,
    ])
    var trialEligible = true
    var offeringError: (any Error)?
    /// Used up in order before `offering` / `offeringError`.
    var offeringScript: [() throws -> OfferingSnapshot?] = []
    private(set) var offeringRequests = 0
    var customerScript: [() throws -> CustomerSnapshot] = []
    var cachedCustomerSnapshot: CustomerSnapshot?
    private(set) var customerRequests = 0
    var tipPrices = ["ap_tip_amen": "R19.99", "ap_tip_hallelujah": "R49.99", "ap_tip_hosanna": "R99.99"]
    /// nil: the purchase goes through and the customer has Pro.
    var nextPurchase: PurchaseOutcome?
    var nextRestore: RestoreOutcome = .restored(CustomerSnapshot())
    private(set) var boughtPackages: [String] = []
    private(set) var boughtProducts: [String] = []
    private var continuations: [AsyncStream<CustomerSnapshot>.Continuation] = []

    func configure() { configureCount += 1 }

    func customerUpdates() -> AsyncStream<CustomerSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: CustomerSnapshot.self)
        continuations.append(continuation)
        return stream
    }

    /// RevenueCat reports a change (a purchase on another device, a refund).
    func report(_ customer: CustomerSnapshot) {
        customerNow = customer
        continuations.forEach { $0.yield(customer) }
    }

    func cachedCustomer() -> CustomerSnapshot? { cachedCustomerSnapshot }

    func customer() async throws -> CustomerSnapshot {
        customerRequests += 1
        if !customerScript.isEmpty { return try customerScript.removeFirst()() }
        return customerNow
    }

    func offering(id: String?) async throws -> OfferingSnapshot? {
        offeringRequests += 1
        if !offeringScript.isEmpty { return try offeringScript.removeFirst()() }
        if let offeringError { throw offeringError }
        return offering
    }

    func prices(of productIDs: [String]) async -> [String: String] {
        tipPrices.filter { productIDs.contains($0.key) }
    }

    func isEligibleForTrial(_ package: OfferingPackage) async -> Bool { trialEligible && package.freeTrial != nil }

    func purchase(package: OfferingPackage) async -> PurchaseOutcome {
        boughtPackages.append(package.id)
        if let nextPurchase { return nextPurchase }
        customerNow = CustomerSnapshot(activeEntitlements: ["pro"], purchasedProductIDs: [package.productID])
        return .completed(customerNow)
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        boughtProducts.append(productID)
        return nextPurchase ?? .completed(customerNow)
    }

    func restore() async -> RestoreOutcome { nextRestore }
}

private struct Offline: Error {}

/// A RevenueCat-shaped error, so the retry rules can be tested without the SDK.
struct ScriptedStoreError: Error, CustomNSError {
    static let network = ScriptedStoreError(
        code: 10, name: "NETWORK_ERROR", rootDomain: "NSURLErrorDomain", rootCode: -1009,
        message: "A network error has occurred.")
    static let configuration = ScriptedStoreError(
        code: 23, name: "CONFIGURATION_ERROR", rootDomain: nil, rootCode: nil,
        message: "There is an issue with your configuration.")

    let code: Int
    let name: String
    let rootDomain: String?
    let rootCode: Int?
    let message: String

    static var errorDomain: String { "RevenueCat.ErrorCode" }
    var errorCode: Int { code }
    var errorUserInfo: [String: Any] {
        var info: [String: Any] = [
            "readable_error_code": name,
            NSLocalizedDescriptionKey: message,
        ]
        if let rootDomain, let rootCode {
            info["rc_root_error"] = ["domain": rootDomain, "code": rootCode]
        }
        return info
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct PurchaseStoreTests {
    private func loadedStore(_ client: FakePurchasesClient = FakePurchasesClient()) async -> (PurchaseStore, FakePurchasesClient) {
        let store = PurchaseStore(client: client)
        await store.loadStorefront()
        return (store, client)
    }

    /// Waits for the store to take in what the client reported.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: Loading

    @Test func thePaywallIsFedFromTheOffering() async throws {
        let (store, _) = await loadedStore()
        #expect(!store.proOptionFailed)
        #expect(!store.tipsFailed)
        let pro = try #require(store.proOption)
        #expect(pro.id == "ap_pro_annual")
        #expect(pro.package.id == "$rc_annual")
        #expect(pro.price == "R299.99")
        #expect(pro.isTrialEligible)
        #expect(pro.planName == "Annual")
        #expect(pro.offerLine == "3 days free, then R299.99/year. Cancel anytime.")
        #expect(pro.callToAction == "Start 3-Day Free Trial")
        let monthly = try #require(store.monthlyOption)
        #expect(monthly.id == "ap_pro_monthly")
        #expect(monthly.package.id == "$rc_monthly")
        #expect(monthly.price == "R29.99")
        #expect(monthly.planName == "Monthly")
        #expect(monthly.trial == nil)
        #expect(!monthly.isTrialEligible)
        #expect(monthly.offerLine == "R29.99/month. Cancel anytime.")
        #expect(monthly.callToAction == "Subscribe")
        #expect(!monthly.offerLine.contains("free"))
        let saving = try #require(AnnualSaving.compare(annual: pro.package, monthly: monthly.package))
        #expect(saving.percent == 17)
        #expect(saving.amount == Decimal(string: "59.89")!)
        #expect(store.proPlans.map(\.id) == ["ap_pro_annual", "ap_pro_monthly"])
        #expect(store.tips.map(\.id) == ["ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"])
        #expect(store.tips.map(\.price) == ["R19.99", "R49.99", "R99.99"])
    }

    @Test func aFailedLoadOffersTryAgainOnEveryScreen() async throws {
        let client = FakePurchasesClient()
        client.offeringError = Offline()
        client.tipPrices = [:]
        let (store, _) = await loadedStore(client)
        #expect(store.proOptionFailed)
        #expect(store.tipsFailed)
        #expect(store.proOption == nil)
        #expect(store.tips.isEmpty)
        client.offeringError = nil
        client.tipPrices = ["ap_tip_amen": "R19.99"]
        await store.loadStorefront()
        #expect(!store.proOptionFailed)
        #expect(!store.tipsFailed)
        #expect(store.proOption?.price == "R299.99")
    }

    @Test func noOfferingSetUpMeansNoBuyButton() async {
        let client = FakePurchasesClient()
        client.offering = nil
        let (store, _) = await loadedStore(client)
        #expect(store.proOptionFailed)
        #expect(!store.tipsFailed, "the Support screen doesn't depend on the offering")
    }

    // MARK: Pro

    @Test func buyingProMakesItPro() async throws {
        let (store, client) = await loadedStore()
        let pro = try #require(store.proOption)
        #expect(!store.isPro)
        let unlocked = await store.purchase(pro, feature: .player)
        #expect(unlocked)
        #expect(client.boughtPackages == ["$rc_annual"])
        #expect(store.isPro)
        #expect(store.entitlements.isSubscriber)
        #expect(!store.entitlements.ownsProForLife)
        #expect(store.isPlayerUnlocked)
        #expect(store.unlocks(.airPlay))
        #expect(store.unlocks(.sheetMusic))
        #expect(!store.purchasing)
        #expect(store.message == nil)
    }

    @Test func cancellingSaysNothing() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .cancelled
        let store = PurchaseStore(client: client, onProPurchaseCancelled: { _ in })
        await store.loadStorefront()
        let unlocked = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(!unlocked)
        #expect(!store.isPro)
        #expect(store.message == nil)
    }

    @Test func cancellingProAsksForAReviewAndCancellingATipDoesNot() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .cancelled
        var proCancels = 0
        let store = PurchaseStore(client: client, retryDelay: { _ in }, onProPurchaseCancelled: { isPro in
            #expect(!isPro)
            proCancels += 1
        })
        await store.loadStorefront()
        _ = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(proCancels == 1)
        await store.tip(try #require(store.tips.first))
        #expect(proCancels == 1)
    }

    @Test func askToBuyWaitsWithAFriendlyMessage() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .pending
        let (store, _) = await loadedStore(client)
        let unlocked = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(!unlocked)
        #expect(store.message?.contains("waiting for approval") == true)
    }

    @Test func aPurchaseWithoutTheEntitlementSaysToRestore() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .completed(CustomerSnapshot(activeEntitlements: [], purchasedProductIDs: ["ap_pro_lifetime"]))
        let (store, _) = await loadedStore(client)
        let unlocked = await store.purchase(try #require(store.proOption), feature: .sheetMusic)
        #expect(!unlocked)
        #expect(store.message?.contains("isn’t active yet") == true)
    }

    @Test func aStoreErrorShowsItsMessage() async throws {
        let client = FakePurchasesClient()
        let text = "Purchases aren’t allowed on this device. Check Screen Time in Settings."
        client.nextPurchase = .failed(.notAllowed, message: text)
        let (store, _) = await loadedStore(client)
        _ = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(store.message == text)
        #expect(!store.isPro)
    }

    @Test func anUnavailablePackageReloadsTheOffering() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .failed(.unavailable, message: "")
        let (store, _) = await loadedStore(client)
        #expect(client.offeringRequests == 1)
        _ = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(store.message?.contains("isn’t available right now") == true)
        #expect(client.offeringRequests == 2)
    }

    // MARK: Tips

    @Test func aTipUnlocksNothingAndSaysThankYou() async throws {
        let (store, client) = await loadedStore()
        let tip = try #require(store.tips.first)
        await store.tip(tip)
        #expect(client.boughtProducts == ["ap_tip_amen"])
        #expect(store.thankYouForTip == tip)
        #expect(!store.isPro)
        #expect(store.tipping == nil)
    }

    @Test func aCancelledTipSaysNothing() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .cancelled
        let (store, _) = await loadedStore(client)
        await store.tip(try #require(store.tips.last))
        #expect(store.thankYouForTip == nil)
        #expect(store.message == nil)
    }

    // MARK: Restore

    @Test func restoreFindsProAgain() async {
        let client = FakePurchasesClient()
        client.nextRestore = .restored(FakePurchasesClient.proCustomer)
        let store = PurchaseStore(client: client)
        await store.restore(source: .paywall)
        #expect(store.isPro)
        #expect(!store.isRestoring)
        #expect(store.message == "Advent Praise Pro has been restored.")
    }

    /// 7.0.1's MIDI Piano comes back as Pro.
    @Test func restoreFindsTheMidiPianoAsPro() async {
        let client = FakePurchasesClient()
        client.nextRestore = .restored(CustomerSnapshot(activeEntitlements: ["pro"], purchasedProductIDs: ["ap_midi_unlock"]))
        let store = PurchaseStore(client: client)
        await store.restore(source: .more)
        #expect(store.isPro)
        #expect(store.unlocks(.airPlay))
        #expect(store.message == "Advent Praise Pro has been restored.")
    }

    @Test func restoreWithNothingSaysSo() async {
        let store = PurchaseStore(client: FakePurchasesClient())
        await store.restore(source: .paywall)
        #expect(!store.isPro)
        #expect(store.message == "No previous purchases were found for this Apple Account.")
    }

    @Test func restoreWithOnlySixPointXHymnalsSaysProIsntAmongThem() async {
        let client = FakePurchasesClient()
        client.nextRestore = .restored(CustomerSnapshot(activeEntitlements: [], purchasedProductIDs: ["ap_hymnal_tswana"]))
        let store = PurchaseStore(client: client)
        await store.restore(source: .more)
        #expect(!store.isPro)
        #expect(store.message == "Your purchases have been restored. Advent Praise Pro isn’t among them.")
    }

    @Test func aCancelledRestoreIsQuiet() async {
        let client = FakePurchasesClient()
        client.nextRestore = .cancelled
        let store = PurchaseStore(client: client)
        await store.restore(source: .paywall)
        #expect(store.message == nil)
        #expect(!store.isRestoring)
    }

    @Test func aFailedRestoreSaysCheckTheConnection() async {
        let client = FakePurchasesClient()
        client.nextRestore = .failed
        let store = PurchaseStore(client: client)
        await store.restore(source: .paywall)
        #expect(store.message?.contains("Couldn’t restore purchases") == true)
    }

    // MARK: Launch and updates

    @Test func launchReadsWhatIsOwned() async {
        let client = FakePurchasesClient()
        client.customerNow = FakePurchasesClient.proCustomer
        let store = PurchaseStore(client: client)
        store.start()
        #expect(client.configureCount == 1)
        await eventually { store.hasLoadedEntitlements }
        #expect(store.hasLoadedEntitlements)
        #expect(store.isPro)
        store.start()
        #expect(client.configureCount == 1, "started once")
    }

    @Test func changesRevenueCatReportsReachTheApp() async {
        let client = FakePurchasesClient()
        let store = PurchaseStore(client: client)
        store.start()
        await eventually { store.hasLoadedEntitlements }
        #expect(!store.isPro)
        // Bought on another device.
        client.report(FakePurchasesClient.proCustomer)
        await eventually { store.isPro }
        #expect(store.isPro)
        // Refunded.
        client.report(CustomerSnapshot())
        await eventually { !store.isPro }
        #expect(!store.isPro)
    }

    @Test func withoutAKeyPurchasesStayOff() async {
        let client = FakePurchasesClient()
        client.isConfigured = false
        let store = PurchaseStore(client: client)
        store.start()
        #expect(store.hasLoadedEntitlements)
        #expect(!store.isPro)
    }

    // MARK: Annual subscription

    @Test func someoneWhoHadTheTrialIsOfferedSubscribe() async throws {
        let client = FakePurchasesClient()
        client.trialEligible = false
        let (store, _) = await loadedStore(client)
        let pro = try #require(store.proOption)
        #expect(!pro.isTrialEligible && pro.trial == nil)
        #expect(pro.offerLine == "R299.99/year. Cancel anytime.")
        #expect(pro.callToAction == "Subscribe")
        #expect(pro.renewalTerms.hasPrefix("Payment is charged to your Apple Account when you confirm."))
    }

    @Test func anOfferingWithOnlyLifetimeSellsNothing() async {
        let client = FakePurchasesClient()
        client.offering = OfferingSnapshot(id: "default", packages: [FakePurchasesClient.lifetime])
        let (store, _) = await loadedStore(client)
        #expect(store.annualOption == nil)
        #expect(store.monthlyOption == nil)
        #expect(store.proOption == nil)
        #expect(store.proOptionFailed, "the paywall offers Try again")
        #expect(!store.tipsFailed)
    }

    /// Monthly not in the offering (not approved yet, or not attached): annual stays.
    @Test func aMissingMonthlyPlanLeavesAnnualOnSale() async throws {
        let client = FakePurchasesClient()
        client.offering = OfferingSnapshot(id: "default", packages: [FakePurchasesClient.annual, FakePurchasesClient.lifetime])
        let (store, _) = await loadedStore(client)
        let annual = try #require(store.annualOption)
        #expect(annual.id == "ap_pro_annual")
        #expect(annual.isTrialEligible)
        #expect(store.monthlyOption == nil)
        #expect(store.proPlans.map(\.id) == ["ap_pro_annual"])
        #expect(!store.proOptionFailed)
        #expect(store.proOption?.package.id == "$rc_annual")
    }

    /// Annual missing still sells monthly, with no trial promised.
    @Test func aMissingAnnualPlanStillSellsMonthly() async throws {
        let client = FakePurchasesClient()
        client.offering = OfferingSnapshot(id: "default", packages: [FakePurchasesClient.monthly])
        let (store, _) = await loadedStore(client)
        let monthly = try #require(store.monthlyOption)
        #expect(store.annualOption == nil)
        #expect(monthly.id == "ap_pro_monthly")
        #expect(monthly.trial == nil)
        #expect(monthly.callToAction == "Subscribe")
        #expect(store.proPlans.map(\.id) == ["ap_pro_monthly"])
        #expect(!store.proOptionFailed)
        #expect(store.proOption?.id == "ap_pro_monthly")
    }

    @Test func buyingMonthlyUnlocksProWithoutATrial() async throws {
        let (store, client) = await loadedStore()
        let monthly = try #require(store.monthlyOption)
        #expect(!monthly.offerLine.contains("free"))
        let unlocked = await store.purchase(monthly, feature: .player)
        #expect(unlocked)
        #expect(client.boughtPackages == ["$rc_monthly"])
        #expect(store.isPro)
        #expect(store.entitlements.isSubscriber)
        #expect(!store.entitlements.ownsProForLife)
        #expect(store.unlocks(.sheetMusic))
        #expect(!store.purchasing)
    }

    // MARK: Blips

    private func quietStore(_ client: FakePurchasesClient,
                            defaults: UserDefaults = UserDefaults(suiteName: "PurchaseStore.\(UUID().uuidString)")!) -> PurchaseStore {
        PurchaseStore(client: client, defaults: defaults, retryDelay: { _ in }, onProPurchaseCancelled: { _ in })
    }

    @Test func aTransientOfferingFailureRetriesThenLoads() async throws {
        let client = FakePurchasesClient()
        let offering = try #require(client.offering)
        client.offeringScript = [
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.network },
            { offering },
        ]
        let store = quietStore(client)
        await store.loadStorefront()
        #expect(client.offeringRequests == StoreFetchRetry.attempts)
        #expect(store.proOption?.price == "R299.99")
        #expect(!store.proOptionFailed)
    }

    @Test func aTransientOfferingFailureGivesUpOnceAndKeepsPricesAlreadyLoaded() async throws {
        let client = FakePurchasesClient()
        let store = quietStore(client)
        await store.loadStorefront()
        #expect(client.offeringRequests == 1)
        client.offeringScript = [
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.network },
        ]
        await store.loadStorefront()
        #expect(client.offeringRequests == 1 + StoreFetchRetry.attempts)
        #expect(store.proOption?.price == "R299.99")
        #expect(!store.proOptionFailed)
        let before = client.offeringRequests
        await store.connectivityRestored()
        #expect(client.offeringRequests == before, "a kept price is not a failed paywall")
    }

    @Test func aPermanentOfferingFailureIsNotRetried() async {
        let client = FakePurchasesClient()
        client.offeringError = ScriptedStoreError.configuration
        let store = quietStore(client)
        await store.loadStorefront()
        #expect(client.offeringRequests == 1)
        #expect(store.proOptionFailed)
    }

    @Test func pricesReloadWhenConnectivityReturns() async {
        let client = FakePurchasesClient()
        client.offeringError = ScriptedStoreError.network
        let store = quietStore(client)
        await store.loadStorefront()
        #expect(client.offeringRequests == StoreFetchRetry.attempts)
        #expect(store.proOptionFailed)
        client.offeringError = nil
        await store.connectivityRestored()
        #expect(!store.proOptionFailed)
        #expect(store.proOption?.price == "R299.99")
        let after = client.offeringRequests
        await store.connectivityRestored()
        #expect(client.offeringRequests == after)
    }

    @Test func aCustomerInfoBlipKeepsCachedPro() async {
        let client = FakePurchasesClient()
        client.cachedCustomerSnapshot = FakePurchasesClient.proCustomer
        client.customerScript = [
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.network },
        ]
        let store = quietStore(client)
        store.start()
        await eventually { store.hasLoadedEntitlements }
        #expect(store.isPro)
        #expect(client.customerRequests == StoreFetchRetry.attempts)
    }

    @Test func aCustomerInfoBlipKeepsRememberedProWhenTheCacheIsEmpty() async throws {
        let defaults = UserDefaults(suiteName: "PurchaseStore.\(UUID().uuidString)")!
        let data = try JSONEncoder().encode(FakePurchasesClient.proCustomer)
        defaults.set(data, forKey: PurchaseStore.rememberedCustomerKey)
        let client = FakePurchasesClient()
        client.customerScript = [
            { throw ScriptedStoreError.network },
            { throw ScriptedStoreError.configuration },
        ]
        let store = quietStore(client, defaults: defaults)
        store.start()
        await eventually { store.hasLoadedEntitlements }
        #expect(store.isPro)
        // The second failure is permanent, so the third try doesn't happen.
        #expect(client.customerRequests == 2)
    }

    @Test func aSuccessfulCustomerInfoClearsARememberedPro() async throws {
        let defaults = UserDefaults(suiteName: "PurchaseStore.\(UUID().uuidString)")!
        let data = try JSONEncoder().encode(FakePurchasesClient.proCustomer)
        defaults.set(data, forKey: PurchaseStore.rememberedCustomerKey)
        let client = FakePurchasesClient()
        client.customerNow = CustomerSnapshot()
        let store = quietStore(client, defaults: defaults)
        store.start()
        await eventually { store.hasLoadedEntitlements }
        #expect(!store.isPro)
        let saved = try #require(defaults.data(forKey: PurchaseStore.rememberedCustomerKey))
        let decoded = try JSONDecoder().decode(CustomerSnapshot.self, from: saved)
        #expect(!decoded.isPro)
    }

    @Test func lifetimeAndMIDIOwnersHaveProAndNeverSeeThePaywall() async {
        for product in ["ap_pro_lifetime", "ap_midi_unlock"] {
            let client = FakePurchasesClient()
            client.customerNow = CustomerSnapshot(activeEntitlements: ["pro"], purchasedProductIDs: [product])
            let store = PurchaseStore(client: client)
            store.start()
            await eventually { store.hasLoadedEntitlements }
            #expect(store.isPro, "\(product)")
            #expect(store.entitlements.ownsProForLife && !store.entitlements.isSubscriber)
            for feature in [ProFeature.player, .airPlay, .mirroring, .support, .sheetMusic] {
                #expect(!ProPaywallRule.presents(feature, isEnabled: true, entitlements: store.entitlements))
            }
        }
    }
}

@MainActor
@Suite("RevenueCat retry reporting")
struct StoreFetchRetryTests {
    @Test func networkErrorsRetryAndConfigurationDoesNot() {
        #expect(StoreErrorReport.isTransient(ScriptedStoreError.network))
        #expect(!StoreErrorReport.isTransient(ScriptedStoreError.configuration))
        #expect(StoreErrorReport.isTransient(URLError(.notConnectedToInternet)))
        #expect(StoreErrorReport.analyticsCode(ScriptedStoreError.network) == "NETWORK_ERROR.NSURLErrorDomain.-1009")
        #expect(!StoreErrorReport.analyticsCode(ScriptedStoreError.network).contains("occurred"))
        #expect(StoreErrorReport.analyticsCode(ScriptedStoreError.configuration) == "CONFIGURATION_ERROR")
        #expect(!StoreErrorReport.analyticsCode(ScriptedStoreError.configuration).contains("issue"))
    }

    @Test func aTransientFetchIsTriedThreeTimesAndSleepsBetween() async {
        var calls = 0
        var slept: [Duration] = []
        do {
            let _: Int = try await StoreFetchRetry.run(sleep: { slept.append($0) }) {
                calls += 1
                throw ScriptedStoreError.network
            }
            Issue.record("the last try should throw")
        } catch {
            #expect(calls == StoreFetchRetry.attempts)
            #expect(slept == StoreFetchRetry.delays)
            #expect(StoreErrorReport.analyticsCode(error) == "NETWORK_ERROR.NSURLErrorDomain.-1009")
        }
    }

    @Test func aPermanentFetchIsTriedOnce() async {
        var calls = 0
        var slept: [Duration] = []
        do {
            let _: Int = try await StoreFetchRetry.run(sleep: { slept.append($0) }) {
                calls += 1
                throw ScriptedStoreError.configuration
            }
            Issue.record("it should throw")
        } catch {
            #expect(calls == 1)
            #expect(slept.isEmpty)
        }
    }
}
