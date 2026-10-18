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
                                                    freeTrial: SubscriptionTerm(value: 3, unit: .day))
    nonisolated static let lifetime = OfferingPackage(id: "$rc_lifetime", productID: "ap_pro_lifetime", price: "R349.99")
    nonisolated static let proCustomer = CustomerSnapshot(activeEntitlements: ["pro"], purchasedProductIDs: ["ap_pro_annual"])

    var isConfigured = true
    private(set) var configureCount = 0
    var customerNow = CustomerSnapshot()
    /// As the live offering stands until 7.1: Annual, and Lifetime still in it.
    var offering: OfferingSnapshot? = OfferingSnapshot(id: "default", packages: [FakePurchasesClient.annual, FakePurchasesClient.lifetime])
    var trialEligible = true
    var offeringError: (any Error)?
    private(set) var offeringRequests = 0
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

    func customer() async throws -> CustomerSnapshot { customerNow }

    func offering(id: String?) async throws -> OfferingSnapshot? {
        offeringRequests += 1
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
        customerNow = Self.proCustomer
        return .completed(customerNow)
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        boughtProducts.append(productID)
        return nextPurchase ?? .completed(customerNow)
    }

    func restore() async -> RestoreOutcome { nextRestore }
}

private struct Offline: Error {}

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
        #expect(pro.offerLine == "3 days free, then R299.99/year. Cancel anytime.")
        #expect(pro.callToAction == "Start 3-Day Free Trial")
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
        #expect(store.isPlayerUnlocked)
        #expect(store.unlocks(.airPlay))
        #expect(store.unlocks(.sheetMusic))
        #expect(!store.purchasing)
        #expect(store.message == nil)
    }

    @Test func cancellingSaysNothing() async throws {
        let client = FakePurchasesClient()
        client.nextPurchase = .cancelled
        let (store, _) = await loadedStore(client)
        let unlocked = await store.purchase(try #require(store.proOption), feature: .player)
        #expect(!unlocked)
        #expect(!store.isPro)
        #expect(store.message == nil)
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

    @Test func anOfferingWithoutTheAnnualPackageSellsNothing() async {
        let client = FakePurchasesClient()
        client.offering = OfferingSnapshot(id: "default", packages: [FakePurchasesClient.lifetime])
        let (store, _) = await loadedStore(client)
        #expect(store.proOption == nil)
        #expect(store.proOptionFailed, "the paywall offers Try again")
        #expect(!store.tipsFailed)
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
