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
    /// Where the picker is shown, for analytics.
    let source: StoreSource
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
                           model.select(hymnal, store: store, source: source, then: onSwitched)
                           onSelected()
                       },
                       onUnlockAll: { Task { await store.purchaseAll(source: source) } },
                       onRestore: { Task { await store.restore(source: source) } })
            .paywallAnalytics(source, model: model)
    }
}

extension View {
    /// `paywall_viewed` when a hymnal list with locked hymnals appears, and
    /// `paywall_dismissed` with what came of it when it goes.
    func paywallAnalytics(_ source: StoreSource, model: ReaderModel) -> some View {
        modifier(PaywallAnalytics(source: source, model: model))
    }
}

private struct PaywallAnalytics: ViewModifier {
    let source: StoreSource
    let model: ReaderModel
    @Environment(PurchaseStore.self) private var store
    @State private var opened: (hymnal: String, owned: Int, ownsEverything: Bool)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                Analytics.screen(source == .translation || source == .churchMode ? .translations : .hymnals)
                let locked = HymnalInfo.catalogue.filter { !store.isOwned($0) }.count
                guard locked > 0 else { opened = nil; return }
                opened = (model.hymnal.id, store.purchasedProductIDs.count, store.ownsEverything)
                Analytics.track(.paywallViewed(source: source, lockedCount: locked))
            }
            .onDisappear {
                guard let opened else { return }
                let bought = store.purchasedProductIDs.count > opened.owned || store.ownsEverything != opened.ownsEverything
                let outcome: PaywallOutcome = bought ? .purchased : model.hymnal.id != opened.hymnal ? .switched : .closed
                Analytics.track(.paywallDismissed(source: source, outcome: outcome))
                self.opened = nil
            }
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
    func select(_ hymnal: DSHymnal, store: PurchaseStore, source: StoreSource,
                then onSwitched: @escaping () -> Void = {}) {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return }
        if store.isOwned(info) {
            switchHymnal(to: info, source: source)
            onSwitched()
        } else {
            Task {
                // The purchase plays its own haptic; the switch stays quiet.
                if await store.purchase(info, source: source) {
                    switchHymnal(to: info, feedback: nil, source: source)
                    onSwitched()
                }
            }
        }
    }
}
