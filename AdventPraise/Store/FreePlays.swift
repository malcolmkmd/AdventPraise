//
//  FreePlays.swift
//  Advent Praise
//
//  Every free user gets `FreePlayAllowance.free` plays of the accompaniment.
//  A play is a hymn starting from the top: a resume after a pause, a scrub
//  or a restart while the hymn is still up is part of the same play (the
//  engine decides that; see `HymnMIDIEngine.isLocked`). Once they are used,
//  Play opens the paywall. Pro never counts.
//
//  The count is kept in UserDefaults and in the Keychain, which outlives the
//  app, so deleting and reinstalling doesn't hand out five more. The higher
//  of the two wins, and both are brought up to it.
//

import Foundation
import Observation
import Security

/// The counting, with nothing stored: how many plays are used and left.
struct FreePlayAllowance: Equatable, Sendable {
    static let free = 5

    private(set) var used: Int

    init(used: Int = 0) { self.used = max(0, used) }

    var remaining: Int { max(0, Self.free - used) }
    var isUsedUp: Bool { remaining == 0 }
    /// The play being started now is the last free one.
    var isLastPlay: Bool { remaining == 1 }

    /// Counts one play. False, and nothing counted, once none are left.
    @discardableResult
    mutating func spend() -> Bool {
        guard !isUsedUp else { return false }
        used += 1
        return true
    }

    /// The stored counts can disagree (a reinstall empties UserDefaults but
    /// not the Keychain): the most plays used wins.
    static func reconciled(_ counts: [Int?]) -> FreePlayAllowance {
        FreePlayAllowance(used: counts.compactMap { $0 }.max() ?? 0)
    }
}

/// Somewhere the used count is kept.
protocol FreePlayStorage {
    func read() -> Int?
    func write(_ used: Int)
}

@Observable
@MainActor
final class FreePlays {
    private(set) var allowance: FreePlayAllowance
    @ObservationIgnored private let stores: [any FreePlayStorage]

    init(stores: [any FreePlayStorage] = [DefaultsFreePlayStorage(), KeychainFreePlayStorage()]) {
        self.stores = stores
        allowance = .reconciled(stores.map { $0.read() })
        save()
    }

    var remaining: Int { allowance.remaining }
    var isUsedUp: Bool { allowance.isUsedUp }

    /// A new play has started: counts it, and returns how many are left.
    @discardableResult
    func spend() -> Int {
        if allowance.spend() { save() }
        return allowance.remaining
    }

    #if DEBUG
    /// `-uiDebugFreePlaysUsed`: sets the count, for screenshots and testing.
    func debugSet(used: Int) {
        allowance = FreePlayAllowance(used: used)
        for store in stores { store.write(allowance.used) }
    }
    #endif

    private func save() {
        for store in stores where store.read() != allowance.used { store.write(allowance.used) }
    }
}

// MARK: - Storage

struct DefaultsFreePlayStorage: FreePlayStorage {
    var defaults: UserDefaults = .standard
    var key = "freePlays.used"

    func read() -> Int? { defaults.object(forKey: key) as? Int }
    func write(_ used: Int) { defaults.set(used, forKey: key) }
}

/// A generic password item, this device only. Readable after the first
/// unlock, so a playlist can go on to the next hymn with the screen locked.
struct KeychainFreePlayStorage: FreePlayStorage {
    var service = (Bundle.main.bundleIdentifier ?? "com.mDev.Advent-Praise") + ".freePlays"
    var account = "used"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> Int? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let text = String(data: data, encoding: .utf8) else { return nil }
        return Int(text)
    }

    func write(_ used: Int) {
        let data = Data(String(used).utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Tests only: removes the item.
    func delete() { SecItemDelete(query as CFDictionary) }
}
