//
//  FreePlaysTests.swift
//  AdventPraiseTests
//
//  The free-play counter: five plays, then none; the higher stored count
//  wins, so a reinstall (UserDefaults gone, Keychain kept) doesn't reset it.
//

import Foundation
import Testing
@testable import Advent_Praise

/// A store in memory; `nil` is "never written".
private final class MemoryStorage: FreePlayStorage {
    var value: Int?
    private(set) var writes = 0
    init(_ value: Int? = nil) { self.value = value }
    func read() -> Int? { value }
    func write(_ used: Int) { value = used; writes += 1 }
}

struct FreePlayAllowanceTests {
    @Test func startsWithFiveFreePlays() {
        let allowance = FreePlayAllowance()
        #expect(FreePlayAllowance.free == 5)
        #expect(allowance.used == 0)
        #expect(allowance.remaining == 5)
        #expect(!allowance.isUsedUp)
        #expect(!allowance.isLastPlay)
    }

    @Test func playsOneToFiveAreFreeThenNone() {
        var allowance = FreePlayAllowance()
        for play in 1...5 {
            let counted = allowance.spend()
            #expect(counted, "play \(play) should be free")
            #expect(allowance.remaining == 5 - play)
        }
        #expect(allowance.isUsedUp)
        let sixth = allowance.spend()
        #expect(!sixth)
        #expect(allowance.used == 5)
        #expect(allowance.remaining == 0)
    }

    @Test func theFifthIsTheLastPlay() {
        #expect(FreePlayAllowance(used: 4).isLastPlay)
        #expect(!FreePlayAllowance(used: 3).isLastPlay)
        #expect(!FreePlayAllowance(used: 5).isLastPlay)
    }

    @Test(arguments: [(-3, 0, 5), (0, 0, 5), (2, 2, 3), (5, 5, 0), (9, 9, 0)])
    func clampsWhatIsStored(stored: Int, used: Int, remaining: Int) {
        let allowance = FreePlayAllowance(used: stored)
        #expect(allowance.used == used)
        #expect(allowance.remaining == remaining)
    }

    @Test func theHigherStoredCountWins() {
        #expect(FreePlayAllowance.reconciled([nil, nil]).used == 0)
        #expect(FreePlayAllowance.reconciled([nil, 3]).used == 3)
        #expect(FreePlayAllowance.reconciled([2, 4]).used == 4)
        #expect(FreePlayAllowance.reconciled([5, 1]).used == 5)
        #expect(FreePlayAllowance.reconciled([]).used == 0)
    }
}

@MainActor
struct FreePlaysTests {
    @Test func spendingIsSavedToEveryStore() {
        let defaults = MemoryStorage(), keychain = MemoryStorage()
        let plays = FreePlays(stores: [defaults, keychain])
        #expect(plays.spend() == 4)
        #expect(plays.spend() == 3)
        #expect(defaults.value == 2)
        #expect(keychain.value == 2)
    }

    @Test func spendingPastTheLimitChangesNothing() {
        let store = MemoryStorage(5)
        let plays = FreePlays(stores: [store])
        #expect(plays.isUsedUp)
        let writes = store.writes
        #expect(plays.spend() == 0)
        #expect(store.value == 5)
        #expect(store.writes == writes)
    }

    @Test func aReinstallKeepsTheKeychainCount() {
        // UserDefaults went with the app; the Keychain item stayed.
        let defaults = MemoryStorage(), keychain = MemoryStorage(3)
        let plays = FreePlays(stores: [defaults, keychain])
        #expect(plays.remaining == 2)
        #expect(defaults.value == 3, "the stores are brought up to the higher count")
    }

    @Test func aLowerKeychainCountIsBroughtUp() {
        let defaults = MemoryStorage(4), keychain = MemoryStorage(1)
        let plays = FreePlays(stores: [defaults, keychain])
        #expect(plays.remaining == 1)
        #expect(keychain.value == 4)
    }

    @Test func theCountOutlastsALaunch() {
        let defaults = MemoryStorage(), keychain = MemoryStorage()
        let first = FreePlays(stores: [defaults, keychain])
        for _ in 1...5 { first.spend() }
        let next = FreePlays(stores: [defaults, keychain])
        #expect(next.isUsedUp)
        #expect(next.remaining == 0)
    }

    // MARK: The onboarding tour

    @Test func nothingPlayedDuringTheTourCounts() {
        let store = MemoryStorage(2)
        let plays = FreePlays(stores: [store])
        plays.isTourActive = true
        let writes = store.writes
        #expect(plays.spend() == 3, "the count is reported, not spent")
        #expect(plays.spend() == 3)
        #expect(plays.remaining == 3)
        #expect(store.value == 2)
        #expect(store.writes == writes)
        plays.isTourActive = false
        #expect(plays.spend() == 2, "after the tour, plays count again")
        #expect(store.value == 3)
    }

    @Test func theTourNeverLocksPlayEvenWithNoFreePlaysLeft() {
        let plays = FreePlays(stores: [MemoryStorage(5)])
        #expect(plays.isUsedUp)
        #expect(plays.locksNewPlay, "a free user with none left is locked")
        plays.isTourActive = true
        #expect(plays.isUsedUp, "the count itself is unchanged")
        #expect(!plays.locksNewPlay, "but Play during the tour never opens the paywall")
        #expect(plays.spend() == 0)
        plays.isTourActive = false
        #expect(plays.locksNewPlay)
    }

    @Test func theTourFlagStartsOff() {
        let plays = FreePlays(stores: [MemoryStorage()])
        #expect(!plays.isTourActive)
        #expect(!plays.locksNewPlay)
    }
}

struct FreePlayStorageTests {
    @Test func userDefaultsRoundTrip() throws {
        let suite = "FreePlaysTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = DefaultsFreePlayStorage(defaults: defaults)
        #expect(storage.read() == nil)
        storage.write(3)
        #expect(storage.read() == 3)
    }

    /// TestFlight build 202610131639 opened the paywall on the first Play:
    /// the phone had had Debug builds, whose count (five used) was still in
    /// the Keychain and UserDefaults under the first names, and the higher
    /// count wins. The versioned names start a fresh user at five.
    @Test @MainActor func aCountLeftByPreReleaseBuildsIsIgnored() throws {
        let suite = "FreePlaysTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bundle = "FreePlaysTests.\(UUID().uuidString)"
        let legacy = [DefaultsFreePlayStorage(defaults: defaults, key: FreePlayStorageName.legacy + ".used"),
                      KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.legacy)] as [any FreePlayStorage]
        let current = [DefaultsFreePlayStorage(defaults: defaults),
                       KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.current)] as [any FreePlayStorage]
        defer {
            KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.legacy).delete()
            KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.current).delete()
        }
        for store in legacy { store.write(5) }

        // The bug: read under the first names, the first Play is locked.
        #expect(FreePlays(stores: legacy).isUsedUp)

        let plays = FreePlays(stores: current)
        #expect(plays.remaining == 5)
        for left in (0..<5).reversed() { #expect(plays.spend() == left) }
        #expect(plays.isUsedUp)
        #expect(legacy.map { $0.read() } == [5, 5], "the old items are left alone")
    }

    @Test @MainActor func aDebugCountNeverReachesRelease() throws {
        let suite = "FreePlaysTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bundle = "FreePlaysTests.\(UUID().uuidString)"
        defer {
            KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.debug).delete()
            KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.release).delete()
        }
        // `-uiDebugFreePlaysUsed 5`, or playing a Debug build with `-uiDebugFree`.
        DefaultsFreePlayStorage(defaults: defaults, key: FreePlayStorageName.debug + ".used").write(5)
        KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.debug).write(5)

        let release = FreePlays(stores: [
            DefaultsFreePlayStorage(defaults: defaults, key: FreePlayStorageName.release + ".used"),
            KeychainFreePlayStorage(service: bundle + "." + FreePlayStorageName.release),
        ])
        #expect(release.remaining == 5)
    }

    @Test func theNamesAreVersionedAndKeptApart() {
        let names = [FreePlayStorageName.legacy, FreePlayStorageName.release, FreePlayStorageName.debug]
        #expect(Set(names).count == 3)
        // These tests run a DEBUG build: it uses the debug names.
        #expect(FreePlayStorageName.current == FreePlayStorageName.debug)
        #expect(DefaultsFreePlayStorage().key == "freePlays.v2.debug.used")
        #expect(KeychainFreePlayStorage().service.hasSuffix(".freePlays.v2.debug"))
    }

    @Test func keychainRoundTrip() {
        let storage = KeychainFreePlayStorage(service: "FreePlaysTests.\(UUID().uuidString)")
        defer { storage.delete() }
        #expect(storage.read() == nil)
        storage.write(2)
        #expect(storage.read() == 2)
        storage.write(5)
        #expect(storage.read() == 5)
    }
}
