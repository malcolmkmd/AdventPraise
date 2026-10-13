//
//  LanguageTile.swift
//  Advent Praise 7 — Vesper design system
//
//  A hymnal as a full-colour tile: the whole tile is the hymnal's colour
//  (`DS.Language`), with the language and the book's title on it in
//  `languageInk`. The current hymnal has a check badge and a ring in the
//  surface's ink, just outside the tile.
//
//  • LanguageTile      — one hymnal
//  • LanguageTileGrid  — two columns (one at accessibility text sizes);
//                        the translation switcher and LanguagePicker
//  • LanguageChip      — the current language as a small filled capsule
//
//  States: current ✓ · owned · purchasing (spinner) · locked (lock + price).
//

import SwiftUI

struct LanguageTile: View {
    let hymnal: DSHymnal
    let access: DSHymnalAccess
    /// Under the language. nil = the hymnal's title.
    var detail: String? = nil
    /// VoiceOver hint for an owned hymnal. nil = "Switches to this hymnal".
    var switchHint: String? = nil
    let action: () -> Void

    @Environment(\.dsSurface) private var surface

    /// Gap between the tile and the current ring, and the ring's width.
    static let ringGap: CGFloat = 3
    static let ringWidth: CGFloat = 2

    private var isCurrent: Bool { access == .current }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                    Text(hymnal.language)
                        .font(DS.Typeface.rowTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    badge
                }
                Text(detail ?? hymnal.name)
                    .font(DS.Typeface.caption)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(surface.languageInk)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(minHeight: DS.Size.languageTile)
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(hymnal.color.fill(on: surface)))
            // A faint inner edge keeps neighbouring tiles apart on dark grounds.
            .overlay(RoundedRectangle.ds(DS.Radius.tile).strokeBorder(surface.languageInk.opacity(DS.Fill.stroke)))
            .padding(Self.ringGap + Self.ringWidth)
            .overlay {
                RoundedRectangle.ds(DS.Radius.tile + Self.ringGap + Self.ringWidth)
                    .strokeBorder(surface.foreground, lineWidth: Self.ringWidth)
                    .opacity(isCurrent ? 1 : 0)
            }
            .contentShape(RoundedRectangle.ds(DS.Radius.tile))
            .animation(DS.Motion.select, value: isCurrent)
        }
        .buttonStyle(DSPressStyle())
        .disabled(access == .purchasing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hymnal.language), \(detail ?? hymnal.name)")
        .accessibilityValue(accessibilityState)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityState: String {
        switch access {
        case .current: String(localized: "Showing now")
        case .owned: ""
        case .purchasing: String(localized: "Purchasing")
        case .locked(let price): price.map { String(localized: "Locked, \($0)") } ?? String(localized: "Locked")
        }
    }

    private var accessibilityHint: String {
        switch access {
        case .current, .purchasing: ""
        case .owned: switchHint ?? String(localized: "Switches to this hymnal")
        case .locked: String(localized: "Buys this hymnal")
        }
    }

    @ViewBuilder private var badge: some View {
        switch access {
        case .current:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(hymnal.color.fill(on: surface), surface.languageInk)
                .font(.body.weight(.semibold))
        case .owned:
            EmptyView()
        case .purchasing:
            ProgressView().controlSize(.small).tint(surface.languageInk)
        case .locked(let price):
            Label(price ?? "—", systemImage: "lock.fill")
                .font(DS.Typeface.caption.weight(.bold))
                .monospacedDigit()
                .labelStyle(.titleAndIcon)
        }
    }
}

/// Tiles two to a row, each row as tall as its tallest tile.
struct LanguageTileGrid<Tile: View>: View {
    let hymnals: [DSHymnal]
    @ViewBuilder let tile: (DSHymnal) -> Tile

    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: Int { typeSize.isAccessibilitySize ? 1 : 2 }

    var body: some View {
        // Each tile carries its ring's padding, so they sit 10 pt apart.
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(Array(stride(from: 0, to: hymnals.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(hymnals[start..<min(start + columns, hymnals.count)]) { tile($0) }
                    if hymnals.count - start < columns { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
    }
}

/// The current language as a small filled capsule (iPad toolbar menu).
struct LanguageChip: View {
    let hymnal: DSHymnal
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Text(hymnal.language)
            .font(DS.Typeface.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(surface.languageInk)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xxs)
            .background(Capsule().fill(hymnal.color.fill(on: surface)))
    }
}

#Preview("LanguageTileGrid") {
    ScrollView {
        LanguageTileGrid(hymnals: DSPreview.hymnals) { hymnal in
            LanguageTile(hymnal: hymnal, access: DSPreview.access(for: hymnal)) {}
        }
        .padding(DS.Space.l)
    }
    .background(DSSurface.paper.background)
    .dsSurface(.paper)
}

#Preview("LanguageTileGrid · Black") {
    ScrollView {
        LanguageTileGrid(hymnals: DSPreview.hymnals) { hymnal in
            LanguageTile(hymnal: hymnal, access: DSPreview.access(for: hymnal)) {}
        }
        .padding(DS.Space.l)
    }
    .background(DSSurface.black.background)
    .dsSurface(.black)
}
