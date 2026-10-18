//
//  TranslationSwitcher.swift
//  Advent Praise
//
//  "Hymn N in…" and every hymnal (all free) as colour tiles: the reader
//  menu's Translation panel, and church mode's globe popover. One tap
//  switches straight away and keeps the hymn: the same number among
//  Christ In Song and its translations, and across to the SDA Hymnal (its
//  own numbers, its own full-width tile) the cross-referenced hymn, whose
//  number the tile shows.
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
            Text("Hymn \(model.hymn.id, format: .hymnNumber) in…")
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
        LanguageTile(hymnal: hymnal,
                     access: store.access(for: hymnal, current: model.hymnalInfo),
                     detail: detail(for: hymnal),
                     switchHint: String(localized: "Shows this hymn in \(hymnal.isOwnBook ? hymnal.name : hymnal.language)")) {
            model.select(hymnal, source: source, then: onSwitched)
        }
    }

    /// nil shows the hymnal's title. Across numberings: where the hymn is,
    /// or that it isn't there.
    private func detail(for hymnal: DSHymnal) -> String? {
        let number = model.hymn.id
        guard let info = HymnalInfo.with(id: hymnal.id), info.id != model.hymnalInfo.id else { return nil }
        guard info.numbering != model.hymnalInfo.numbering else {
            return number <= info.maxNumber ? nil
                : String(localized: "No hymn \(number, format: .hymnNumber) · opens the first hymn")
        }
        if let there = HymnalCrossReference.number(number, from: model.hymnalInfo, to: info) {
            return String(localized: "\(info.name) · hymn \(there, format: .hymnNumber)")
        }
        return String(localized: "\(info.name) · not in this hymnal")
    }
}
