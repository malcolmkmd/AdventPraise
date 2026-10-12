//
//  HymnalStorePicker.swift
//  Advent Praise
//
//  LanguagePicker wired to the reader. The Lectern's Hymnals panel and the
//  iPad sidebar sheet both use it. Every hymnal is free, so a tap switches.
//

import SwiftUI

struct HymnalStorePicker: View {
    let model: ReaderModel
    /// Where the picker is shown, for analytics.
    let source: HymnalSource
    /// Runs as soon as a row is tapped.
    var onSelected: () -> Void = {}
    /// Runs once the reader has switched to the chosen hymnal.
    var onSwitched: () -> Void = {}
    @Environment(PurchaseStore.self) private var store

    var body: some View {
        LanguagePicker(hymnals: HymnalInfo.catalogue.map(\.designHymnal),
                       access: { store.access(for: $0, current: model.hymnalInfo) },
                       ownsEverything: true,
                       onSelect: { hymnal in
                           model.select(hymnal, source: source, then: onSwitched)
                           onSelected()
                       })
            .analyticsScreen(.hymnals)
    }
}

extension ReaderModel {
    /// Switches to the hymnal. `onSwitched` runs after the switch.
    func select(_ hymnal: DSHymnal, source: HymnalSource, then onSwitched: @escaping () -> Void = {}) {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return }
        switchHymnal(to: info, source: source)
        onSwitched()
    }
}
