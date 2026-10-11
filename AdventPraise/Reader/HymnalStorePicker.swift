//
//  HymnalStorePicker.swift
//  Advent Praise
//
//  LanguagePicker wired to the purchase store and the reader. The Lectern's
//  Hymnals panel, the reader's Hymnals sheet and the iPad sidebar sheet all
//  use it, so access and purchase rules live in one place.
//

import SwiftUI

struct HymnalStorePicker: View {
    let model: ReaderModel
    /// Runs as soon as a row is tapped (before any purchase finishes).
    var onSelected: () -> Void = {}
    /// Runs once the reader has switched to the chosen hymnal.
    var onSwitched: () -> Void = {}
    @Environment(PurchaseStore.self) private var store

    var body: some View {
        LanguagePicker(hymnals: HymnalInfo.catalogue.map(\.designHymnal),
                       access: { store.access(for: $0, current: model.hymnalInfo) },
                       unlockAllPrice: store.allHymnalsPrice,
                       isUnlockingAll: store.purchasing == PurchaseConfig.allHymnalsProductID,
                       ownsEverything: store.ownsEverything || PurchaseConfig.allHymnalsProductID == nil,
                       onSelect: { hymnal in
                           model.select(hymnal, store: store, then: onSwitched)
                           onSelected()
                       },
                       onUnlockAll: { Task { await store.purchaseAll() } },
                       onRestore: { Task { await store.restore() } })
    }
}

extension PurchaseStore {
    /// How a hymnal row should read: current, owned, purchasing or locked.
    func access(for hymnal: DSHymnal, current: HymnalInfo) -> DSHymnalAccess {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return .locked(price: nil) }
        if purchasing == info.id { return .purchasing }
        if info.id == current.id { return .current }
        if isOwned(info) { return .owned }
        return .locked(price: price(for: info))
    }
}

extension ReaderModel {
    /// Switches to an owned hymnal now, or buys it first and switches if the
    /// purchase succeeds. `onSwitched` runs after the switch.
    func select(_ hymnal: DSHymnal, store: PurchaseStore, then onSwitched: @escaping () -> Void = {}) {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return }
        if store.isOwned(info) {
            switchHymnal(to: info)
            onSwitched()
        } else {
            Task {
                if await store.purchase(info) {
                    switchHymnal(to: info)
                    onSwitched()
                }
            }
        }
    }
}
