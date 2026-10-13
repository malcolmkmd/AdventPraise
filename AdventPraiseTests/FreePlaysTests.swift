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
