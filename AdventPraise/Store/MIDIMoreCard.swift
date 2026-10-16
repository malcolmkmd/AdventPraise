//
//  MIDIMoreCard.swift
//  Advent Praise
//
//  MIDI Piano in More, under the Pro card, in the same shape: a small tile
//  (the piano keys in the gold light), the title, one line, and a chevron.
//  For sale, the whole card opens the MIDI Piano screen (MIDIPaywall.swift).
//  Owned, on its own or with Pro, it reads Owned (and Included with Pro),
//  opens nothing, and isn't a button.
//

import SwiftUI

struct MIDIMoreCard: View {
    /// Opens the MIDI Piano screen. Not called once the piano is owned.
    let onOpen: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .callout) private var tileSize: CGFloat = 48

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }
    private var ownership: MIDIOwnership { store.midiOwnership }

    private var subtitle: String {
        switch ownership {
        case .notOwned: String(localized: "The sing-along player, without the free-play limit")
        case .owned: String(localized: "Bought once, yours for good")
        case .includedWithPro: String(localized: "Included with Pro")
        }
    }

    var body: some View {
        if ownership.isOwned {
            card
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("MIDI Piano, owned. \(subtitle)")
        } else {
            Button(action: onOpen) { card }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("MIDI Piano, \(subtitle)")
                .accessibilityHint("Opens the MIDI Piano unlock")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("more.midiCard")
        }
    }

    private var card: some View {
        let shape = RoundedRectangle.ds(DS.Radius.card)
        return HStack(spacing: DS.Space.m) {
            tile
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                HStack(spacing: DS.Space.xxs) {
                    Text("MIDI Piano").font(DS.Typeface.rowTitle)
                    if ownership.isOwned {
                        Image(systemName: "checkmark.seal.fill")
                            .font(DS.Typeface.detail)
                            .foregroundStyle(palette.brass)
                    }
                }
                Text(subtitle)
                    .font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if ownership.isOwned {
                Text("Owned")
                    .font(DS.Typeface.caption.weight(.medium))
                    .foregroundStyle(surface.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(surface.secondary)
            }
        }
        .padding(.vertical, DS.Space.m)
        .padding(.leading, DS.Space.m)
        .padding(.trailing, DS.Space.m + DS.Space.xxs)
        .background(shape.fill(.primary.opacity(DS.Fill.row)))
        .overlay(shape.strokeBorder(palette.brass.opacity(palette.isDark ? 0.35 : 0.28)))
        .contentShape(shape)
    }

    /// The piano keys in the light, small. Decoration only. Capped so the
    /// row stays a row at the largest text sizes.
    private var tile: some View {
        let size = min(tileSize, 64)
        return ZStack {
            palette.ground
            PaywallLight(palette: palette, intensity: 0.9)
            Image(systemName: "pianokeys")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(palette.brass)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle.ds(DS.Radius.tile))
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("MIDI card · paper") {
    ScrollView {
        MIDIMoreCard {}.padding()
    }
    .environment(PurchaseStore())
    .dsSurface(.paper)
}

#Preview("MIDI card · black") {
    ScrollView {
        MIDIMoreCard {}.padding()
    }
    .environment(PurchaseStore())
    .dsSurface(.black)
}
