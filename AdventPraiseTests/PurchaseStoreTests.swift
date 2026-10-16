//
//  PurchaseStoreTests.swift
//  AdventPraiseTests
//
//  The StoreKit 2 store against StoreKit/Products.storekit (ZAR), in a
//  local StoreKit test session: the products load with their prices, Pro
//  bought is Pro owned, MIDI Piano bought opens the player and nothing
//  else, a tip unlocks nothing, Ask to Buy waits, a failed load offers Try
//  again on every screen, and Restore finds Pro (or the piano) again.
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
        .appending(path: "StoreKit/Products.storekit")
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
    @Test func loadsProMidiAndTheTipsWithTheirPrices() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        #expect(!store.proOptionFailed)
        #expect(!store.midiOptionFailed)
        #expect(!store.tipsFailed)
        let pro = try #require(store.proOption)
        #expect(pro.id == "ap_pro_lifetime")
        #expect(pro.price.contains("199"))
        let midi = try #require(store.midiOption)
        #expect(midi.id == "ap_midi_unlock")
        #expect(midi.price.contains("79"))
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
        #expect(store.isPlayerUnlocked)
        #expect(store.unlocks(.airPlay))
        #expect(store.message == nil)
    }

    @Test func buyingMidiPianoOpensThePlayerAlone() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        let midi = try #require(store.midiOption)
        #expect(!store.isPlayerUnlocked)
        let unlocked = await store.purchase(midi, feature: .player)
        #expect(unlocked)
        #expect(store.ownsMIDI)
        #expect(store.isPlayerUnlocked)
        #expect(!store.isPro, "the piano alone is not Pro")
        #expect(!store.unlocks(.airPlay))
        #expect(!store.unlocks(.mirroring))
        #expect(store.message == nil)
    }

    /// The MIDI Piano screen (More, the iPad sidebar) sells the same product
    /// under its own feature; buying it there closes that screen.
    @Test func buyingMidiPianoFromItsOwnScreenOwnsIt() async throws {
        _ = try Session.fresh()
        let store = PurchaseStore()
        await store.loadStorefront()
        let midi = try #require(store.midiOption)
        #expect(store.midiOwnership == .notOwned)
        let unlocked = await store.purchase(midi, feature: .midi)
        #expect(unlocked)
        #expect(store.unlocks(.midi))
        #expect(store.midiOwnership == .owned)
        #expect(!store.isPro)
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

    @Test func aFailedLoadOffersTryAgainOnEveryScreen() async throws {
        let session = try Session.fresh()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let store = PurchaseStore()
        await store.loadStorefront()
        #expect(store.proOptionFailed)
        #expect(store.midiOptionFailed)
        #expect(store.tipsFailed)
        #expect(store.proOption == nil)
        #expect(store.midiOption == nil)
        #expect(store.tips.isEmpty)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadStorefront()
        #expect(!store.proOptionFailed)
        #expect(!store.midiOptionFailed)
        #expect(!store.tipsFailed)
        #expect(store.proOption != nil)
        #expect(store.midiOption != nil)
    }

    @Test func restoreFindsProAgain() async throws {
        let session = try Session.fresh()
        _ = try await session.buyProduct(identifier: PurchaseConfig.proProductID)
        let store = PurchaseStore()
        await store.restore(source: .paywall)
        #expect(store.isPro)
        #expect(store.message == "Advent Praise Pro has been restored.")
    }

    @Test func restoreFindsTheMidiPianoAgain() async throws {
        let session = try Session.fresh()
        _ = try await session.buyProduct(identifier: PurchaseConfig.midiProductID)
        let store = PurchaseStore()
        await store.restore(source: .paywall)
        #expect(store.ownsMIDI)
        #expect(!store.isPro)
        #expect(store.isPlayerUnlocked)
        #expect(store.message?.contains("MIDI piano has been restored") == true)
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
        // Long enough for a capture started by hand once the marker appears.
        try await Task.sleep(for: .seconds(25))
        try? FileManager.default.removeItem(at: marker)
    }

    /// Not a check: the MIDI Piano screen as More's row opens it, priced by
    /// the StoreKit configuration, for its screenshot. Runs only when
    /// build/shots/storekit/take-midi exists; writes .midi-ready and holds.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: Session.shots.appending(path: "take-midi").path)))
    func midiScreenForTheScreenshot() async throws {
        _ = try Session.fresh()
        let services = AppServices.shared
        // The host's store read what the simulator's old test session owned
        // before this one cleared it: re-read, and drop Restore's alert.
        await services.store.restore(source: .more)
        services.store.message = nil
        #expect(services.store.midiOwnership == .notOwned)
        services.reader.switchHymnal(to: .default, feedback: nil, source: .lectern)
        services.reader.paywall = .midi
        // The sheet lands and the hands lift and settle.
        try await Task.sleep(for: .seconds(4))
        #expect(services.store.midiOption != nil)
        let marker = Session.shots.appending(path: ".midi-ready")
        try Data().write(to: marker)
        try await Task.sleep(for: .seconds(25))
        try? FileManager.default.removeItem(at: marker)
    }
}
