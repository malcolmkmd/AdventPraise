//
//  TranslationSwitcher.swift
//  Advent Praise
//
//  "Hymn N in…" and every hymnal (all free) as colour tiles: the reader
//  menu's Translation panel, and church mode's globe popover. One tap
//  switches straight away and keeps the hymn number.
//  Reads `\.dsSurface`, so it suits whichever ground presents it.
//

import SwiftUI

struct TranslationSwitcher: View {
    let model: ReaderModel
    /// The reader's globe or church mode's, for analytics.
    let source: HymnalSource
    /// The popover's width; nil fills the reader menu.
    var width: CGFloat? = 320
    /// The list scrolls past this height.
    var maxHeight: CGFloat = 420
    /// Runs once the reader shows the chosen hymnal.
    var onSwitched: () -> Void = {}
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Hymn \(model.hymn.id) in…")
                .dsEyebrow()
                .foregroundStyle(surface.secondary)
                .padding(.horizontal, DS.Space.panel)
                .padding(.top, DS.Space.panel)
                .accessibilityAddTraits(.isHeader)
            DSFittingScroll(maxHeight: maxHeight) {
                LanguageTileGrid(hymnals: HymnalInfo.catalogue.map(\.designHymnal)) { tile($0) }
                    // Tiles line up with the heading; their ring padding makes up the rest.
                    .padding(.horizontal, DS.Space.panel - LanguageTile.ringGap - LanguageTile.ringWidth)
                    .padding(.bottom, DS.Space.xs)
            }
        }
        .frame(width: width)
        .analyticsScreen(.translations)
    }

    private func tile(_ hymnal: DSHymnal) -> some View {
        let number = model.hymn.id
        let info = HymnalInfo.with(id: hymnal.id)
        let hasHymn = number <= (info?.maxNumber ?? 0)
        return LanguageTile(hymnal: hymnal,
                            access: store.access(for: hymnal, current: model.hymnalInfo),
                            detail: hasHymn ? nil : String(localized: "No hymn \(number) · opens the first hymn"),
                            switchHint: String(localized: "Shows this hymn in \(hymnal.language)")) {
            model.select(hymnal, source: source, then: onSwitched)
        }
    }
}
