//
//  TranslationSwitcher.swift
//  Advent Praise
//
//  "Hymn N in…" and every hymnal (all free): the reader menu's Translation
//  panel, and church mode's globe popover. One tap switches straight away and keeps
//  the hymn number.
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
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    ForEach(HymnalInfo.catalogue) { row($0) }
                }
                .padding(.horizontal, DS.Space.xs)
                .padding(.bottom, DS.Space.xs)
            }
        }
        .frame(width: width)
        .analyticsScreen(.translations)
    }

    private func row(_ info: HymnalInfo) -> some View {
        TranslationRow(info: info, number: model.hymn.id,
                       access: store.access(for: info.designHymnal, current: model.hymnalInfo)) {
            model.select(info.designHymnal, source: source, then: onSwitched)
        }
    }
}

/// One hymnal: its language, and whether this hymn number exists in it.
private struct TranslationRow: View {
    let info: HymnalInfo
    let number: Int
    let access: DSHymnalAccess
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    private var isCurrent: Bool { access == .current }
    private var detail: String {
        number <= info.maxNumber ? info.name : String(localized: "No hymn \(number) · opens the first hymn")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                RoundedRectangle.ds(DS.Radius.swatch).fill(info.color)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text(info.language).font(DS.Typeface.rowTitle)
                    Text(detail)
                        .font(DS.Typeface.detail)
                        .foregroundStyle(surface.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row + 8)
            .background(RoundedRectangle.ds(DS.Radius.tile)
                .fill(isCurrent ? surface.tint.opacity(DS.Fill.tintSelected) : .clear))
            .contentShape(RoundedRectangle.ds(DS.Radius.tile))
        }
        .buttonStyle(DSPressStyle())
        .disabled(access == .purchasing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.language), \(info.name)")
        .accessibilityValue(value)
        .accessibilityHint(hint)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var trailing: some View {
        switch access {
        case .current:
            Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(surface.brass)
        case .owned:
            EmptyView()
        case .purchasing:
            ProgressView().controlSize(.small)
        case .locked(let price):
            PricePill(price: price)
        }
    }

    private var value: String {
        switch access {
        case .current: String(localized: "Showing now")
        case .owned: number <= info.maxNumber ? "" : String(localized: "No hymn \(number)")
        case .purchasing: String(localized: "Purchasing")
        case .locked(let price): price.map { String(localized: "Locked, \($0)") } ?? String(localized: "Locked")
        }
    }

    private var hint: String {
        switch access {
        case .current, .purchasing: ""
        case .owned: String(localized: "Shows this hymn in \(info.language)")
        case .locked: String(localized: "Buys this hymnal, then shows this hymn in it")
        }
    }
}

