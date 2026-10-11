//
//  PaywallLanguageRow.swift
//  Advent Praise 7 — Vesper design system
//
//  One vernacular hymnal with its purchase state. Used by LanguagePicker
//  and any paywall list. Prices are brass (purchases are "musical" value,
//  not navigation) and never shown as amounts in analytics.
//
//  States: current ✓ · owned · locked (price pill) · purchasing (spinner)
//  · locked with no price yet (store not loaded: "—", still tappable to retry).
//

import SwiftUI

struct PaywallLanguageRow: View {
    let hymnal: DSHymnal
    let access: DSHymnalAccess
    let action: () -> Void

    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                RoundedRectangle.ds(DS.Radius.swatch)
                    .fill(hymnal.swatch)
                    .frame(width: DS.Size.swatch, height: DS.Size.swatch)
                    .overlay {
                        Text(String(hymnal.language.prefix(2)))
                            .font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(hymnal.name).font(DS.Typeface.label).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    Text(hymnal.language).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                }
                Spacer(minLength: DS.Space.s)
                trailing
            }
            .padding(.horizontal, 10)
            .padding(.vertical, DS.Space.xs)
            .frame(minHeight: DS.Size.compactRow)
            .background(RoundedRectangle.ds(DS.Radius.key)
                .fill(access == .current ? surface.tint.opacity(DS.Fill.tintActive) : Color.primary.opacity(DS.Fill.row)))
            .overlay(RoundedRectangle.ds(DS.Radius.key)
                .strokeBorder(access == .current ? surface.tint.opacity(0.35) : .clear))
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
        }
        .buttonStyle(.plain)
        .disabled(access == .purchasing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hymnal.name), \(hymnal.language)")
        .accessibilityValue(accessibilityState)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(access == .current ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var trailing: some View {
        switch access {
        case .purchasing:
            ProgressView().controlSize(.small)
        case .current:
            Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(surface.tint)
        case .owned:
            Text("Owned").dsEyebrow(tracking: 0.6).foregroundStyle(surface.secondary)
        case .locked(let price):
            PricePill(price: price)
        }
    }

    private var accessibilityState: Text {
        switch access {
        case .current: Text("Current hymnal")
        case .owned: Text("Owned")
        case .purchasing: Text("Purchasing")
        case .locked(let price): price.map { Text("Locked, \($0)") } ?? Text("Locked")
        }
    }

    private var accessibilityHint: Text {
        switch access {
        case .current: Text("")
        case .owned: Text("Switches to this hymnal")
        case .purchasing: Text("")
        case .locked: Text("Buys this hymnal")
        }
    }
}

/// The lock + price capsule: a brass wash. It sits inside a row (content), so
/// it is never glass; the whole row is the button and the pill only signals.
private struct PricePill: View {
    let price: String?
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Label(price ?? "—", systemImage: "lock.fill")
            .font(DS.Typeface.caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .foregroundStyle(surface.brass)
            .background(Capsule().fill(surface.brass.opacity(DS.Fill.tintSelected)))
    }
}

/// The "Unlock all N hymnals" call to action that closes the paywall list.
struct PaywallUnlockAllButton: View {
    let count: Int
    let price: String?
    var isPurchasing = false
    let action: () -> Void

    var body: some View {
        GlassButton(title: title, systemImage: "lock.open.fill", isLoading: isPurchasing,
                    fullWidth: true, action: action)
            .disabled(isPurchasing || price == nil)
    }

    private var title: LocalizedStringKey {
        if let price { "Unlock all \(count) hymnals · \(price)" } else { "Unlock all \(count) hymnals" }
    }
}

#Preview("PaywallLanguageRow · states") {
    VStack(spacing: DS.Space.xxs) {
        ForEach(DSPreview.hymnals) { hymnal in
            PaywallLanguageRow(hymnal: hymnal, access: DSPreview.access(for: hymnal)) {}
        }
        PaywallUnlockAllButton(count: 8, price: "$9.99") {}
            .padding(.top, DS.Space.s)
        Button("Restore purchases") {}
            .font(DS.Typeface.button)
            .frame(minHeight: DS.Size.hitTarget)
    }
    .padding(DS.Space.panel)
    .dsGlass(RoundedRectangle.ds(DS.Radius.panel))
    .padding(DS.Space.l)
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(DSPreviewBackdrop())
    .dsSurface(.paper)
}

#Preview("PaywallLanguageRow · Black") {
    VStack(spacing: DS.Space.xxs) {
        ForEach(DSPreview.hymnals.prefix(4)) { hymnal in
            PaywallLanguageRow(hymnal: hymnal, access: DSPreview.access(for: hymnal)) {}
        }
    }
    .padding(DS.Space.l)
    .dsSurface(.black)
}
