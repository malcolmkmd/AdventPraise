//
//  PurchaseStoreTests.swift
//  AdventPraiseTests
//
//  The StoreKit 2 store against StoreKit/AdventPraise.storekit (ZAR), in a
//  local StoreKit test session: the products load with their prices, Pro
//  bought is Pro owned, a tip unlocks nothing, Ask to Buy waits, a failed
//  load offers Try again, and Restore finds Pro again.
//
//  The paywall screenshot (build/shots/storekit/) is taken from here too:
//  with TEST_RUNNER_AP_SHOTS=1 the last test spends the free plays and taps
//  Play in the host app, then holds the paywall up while
//  scripts/storekit-shot.sh captures the simulator.
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Advent_Praise

/// One session for the suite: StoreKit testing is process-wide.
@MainActor
private enum Session {
    static let configuration = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "StoreKit/AdventPraise.storekit")

    static func fresh() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        return session
    }
}

@MainActor
@Suite(.serialized)
struct PurchaseStoreTests {
    @Test func loadsProAndTheTipsWithTheirPrices() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        #expect(!store.optionsFailed)
        let pro = try #require(store.proOption)
        #expect(pro.id == "ap_pro_lifetime")
        #expect(pro.price.contains("199"))
        #expect(store.tips.map(\.id) == ["ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"])
    }

    @Test func buyingProMakesItPro() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        let pro = try #require(store.proOption)
        #expect(!store.isPro)
        let unlocked = await store.purchase(pro, feature: .player)
        #expect(unlocked)
        #expect(store.isPro)
        #expect(store.message == nil)
    }

    @Test func aTipUnlocksNothingAndSaysThankYou() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        let tip = try #require(store.tips.first)
        await store.tip(tip)
        #expect(store.thankYouForTip == tip)
        #expect(!store.isPro)
    }

    @Test func askToBuyWaitsWithAFriendlyMessage() async throws {
        let session = try Session.fresh()
        session.askToBuyEnabled = true
        let store = PurchaseStore()
        await store.loadStorefront()
        let pro = try #require(store.proOption)
        let unlocked = await store.purchase(pro, feature: .player)
        #expect(!unlocked)
        #expect(store.message?.contains("waiting for approval") == true)
    }

    @Test func aFailedLoadOffersTryAgain() async throws {
        let session = try Session.fresh()
        try session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let store = PurchaseStore()
        await store.loadStorefront()
        #expect(store.optionsFailed)
        #expect(store.proOption == nil)
        try session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadStorefront()
        #expect(!store.optionsFailed)
        #expect(store.proOption != nil)
    }

    @Test func restoreFindsProAgain() async throws {
        let session = try Session.fresh()
        _ = try await session.buyProduct(identifier: PurchaseConfig.proProductID)
        let store = PurchaseStore()
        await store.restore(source: .paywall)
        #expect(store.isPro)
        #expect(store.message == "Advent Praise Pro has been restored.")
    }

    /// Not a check: the screenshot of the paywall from Play, for
    /// build/shots/storekit/. Runs only with TEST_RUNNER_AP_SHOTS=1.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AP_SHOTS"] == "1"))
    func paywallFromPlayForTheScreenshot() async throws {
        _ = try Session.fresh()
        let services = AppServices.shared
        services.freePlays.debugSet(used: FreePlayAllowance.free)
        // What the Lectern's Play does.
        let hymn = services.reader.hymn
        services.player.start(hymn, source: services.reader.hymnal.name)
        #expect(services.reader.paywall == .player)
        try await Task.sleep(for: .seconds(3))
        #expect(services.store.proOption != nil)
        let marker = Session.configuration.deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "build/shots/storekit/.paywall-ready")
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: marker)
        try await Task.sleep(for: .seconds(8))
        try? FileManager.default.removeItem(at: marker)
    }
}
