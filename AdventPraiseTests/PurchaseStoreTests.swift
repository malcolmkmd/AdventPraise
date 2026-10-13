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
//  when build/shots/storekit/take exists, the last test spends the free plays and taps
//  Play in the host app, then holds the paywall up while
//  scripts/storekit-shot.sh captures the simulator.
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
import UIKit
@testable import Advent_Praise

/// One session for the suite: StoreKit testing is process-wide.
@MainActor
private enum Session {
    static let configuration = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "StoreKit/AdventPraise.storekit")
    nonisolated static let shots = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "build/shots/storekit")

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
@Suite(.serialized, .timeLimit(.minutes(1)))
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
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let store = PurchaseStore()
        await store.loadStorefront()
        #expect(store.optionsFailed)
        #expect(store.proOption == nil)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
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
    /// build/shots/storekit/. Runs only when build/shots/storekit/take
    /// exists (scripts/storekit-shot.sh makes it).
    @Test(.enabled(if: FileManager.default.fileExists(atPath: Session.shots.appending(path: "take").path)))
    func paywallFromPlayForTheScreenshot() async throws {
        _ = try Session.fresh()
        let services = AppServices.shared
        services.freePlays.debugSet(used: FreePlayAllowance.free)
        // Christ In Song, on a hymn with the accompaniment: what the Lectern's Play does.
        services.reader.switchHymnal(to: .default, feedback: nil, source: .lectern)
        let hymn = try #require(services.reader.hymnal.hymns.first { $0.hasAccompaniment })
        services.reader.show(hymn, feedback: nil, source: nil)
        services.player.start(hymn, source: services.reader.hymnal.name)
        #expect(services.reader.paywall == .player)
        // The sheet lands and the hands lift and settle.
        try await Task.sleep(for: .seconds(4))
        #expect(services.store.proOption != nil)
        let shots = Session.shots
        // The app's own drawing of the window, in case the simulator capture can't run.
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        let keyWindow = windows.first { $0.isKeyWindow }
        let window = try #require(keyWindow)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let png = try #require(image.pngData())
        try png.write(to: shots.appending(path: "paywall-from-play-window.png"))
        let marker = shots.appending(path: ".paywall-ready")
        try Data().write(to: marker)
        try await Task.sleep(for: .seconds(8))
        try? FileManager.default.removeItem(at: marker)
    }
}
