//
//  LanguagePicker.swift
//  Advent Praise 7 — Vesper design system
//
//  Choose the vernacular hymnal. Two presentations:
//  • LanguagePicker       — the full list (Lectern "Hymnals" panel, iPad
//                           sidebar section, onboarding). Hymnals are
//                           LanguageTiles, so purchase state is inline.
//  • LanguageMenuButton   — a compact control showing the current language
//                           as a LanguageChip;
//                           opens a Menu of owned hymnals (iPad toolbar).
//                           The toolbar supplies the glass on iOS 26.
//
//  Switching keeps the same hymn number where it exists (app logic).
//

import SwiftUI

struct LanguagePicker: View {
    let hymnals: [DSHymnal]
    let access: (DSHymnal) -> DSHymnalAccess
    var unlockAllPrice: String? = nil
    var isUnlockingAll = false
    var ownsEverything = false
    /// true = draws its own glass panel. false = embedded in the Lectern or a sheet.
    var isStandalone = false
    let onSelect: (DSHymnal) -> Void
    var onUnlockAll: () -> Void = {}
    /// nil hides Restore purchases (the hymnals are free).
    var onRestore: (() -> Void)? = nil

    @Environment(\.dsSurface) private var surface

    var body: some View {
        if isStandalone {
            list.dsGlass(RoundedRectangle.ds(DS.Radius.panel), depth: .sheet)
        } else {
            list
        }
    }

    private var list: some View {
        VStack(spacing: DS.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                Text("Hymnals").font(DS.Typeface.panelTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(hymnals.count) languages").dsEyebrow(tracking: 0.9).foregroundStyle(surface.secondary)
            }

            ScrollView {
                LanguageTileGrid(hymnals: hymnals) { hymnal in
                    LanguageTile(hymnal: hymnal, access: access(hymnal)) { onSelect(hymnal) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 420)
            // Into the panel's padding by the tiles' ring padding, so the tiles line up with the title.
            .padding(.horizontal, -(LanguageTile.ringGap + LanguageTile.ringWidth))

            if !ownsEverything {
                PaywallUnlockAllButton(count: hymnals.count - 1, price: unlockAllPrice,
                                       isPurchasing: isUnlockingAll, action: onUnlockAll)
            }
            if let onRestore {
                Button("Restore purchases", action: onRestore)
                    .font(DS.Typeface.button)
                    .foregroundStyle(surface.tint)
                    .frame(minHeight: DS.Size.hitTarget)
            }
        }
        .padding(DS.Space.panel)
    }
}

/// Compact current-language control.
struct LanguageMenuButton: View {
    let current: DSHymnal
    /// Only owned hymnals belong in the quick menu; buying happens in LanguagePicker.
    let owned: [DSHymnal]
    let onSelect: (DSHymnal) -> Void
    var onShowAll: () -> Void = {}

    @Environment(\.dsSurface) private var surface

    var body: some View {
        Menu {
            Picker("Hymnal", selection: Binding(get: { current.id },
                                               set: { id in
                                                   if let hymnal = owned.first(where: { $0.id == id }) { onSelect(hymnal) }
                                               })) {
                ForEach(owned) { hymnal in
                    Text("\(hymnal.language) · \(hymnal.name)").tag(hymnal.id)
                }
            }
            Divider()
            Button("All hymnals…", systemImage: "globe", action: onShowAll)
        } label: {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "globe")
                LanguageChip(hymnal: current)
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                    .foregroundStyle(surface.secondary)
            }
            .font(DS.Typeface.label)
            .padding(.horizontal, DS.Space.panel)
            .frame(minHeight: DS.Size.hitTarget)
            .modifier(MenuChrome())
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Hymnal")
        .accessibilityValue("\(current.name), \(current.language)")
    }
}

/// iOS 26: nothing — the navigation toolbar already wraps the item in glass,
/// and a second capsule would be glass on glass. iOS 17–25: a quiet inset
/// capsule (the bar is already a material).
private struct MenuChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.background(Capsule().fill(.primary.opacity(DS.Fill.inset)))
        }
    }
}

#Preview("LanguagePicker · in Lectern") {
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        LanguagePicker(hymnals: DSPreview.hymnals, access: DSPreview.access(for:),
                       unlockAllPrice: "$9.99", isStandalone: true) { _ in }
            .padding(DS.Space.l)
    }
    .dsSurface(.parchment)
}

#Preview("LanguageMenuButton") {
    ZStack(alignment: .top) {
        DSPreviewBackdrop()
        LanguageMenuButton(current: DSPreview.hymnals[0],
                           owned: [DSPreview.hymnals[0], DSPreview.hymnals[6]]) { _ in }
            .padding(.top, DS.Space.l)
    }
    .dsSurface(.muted)
}
