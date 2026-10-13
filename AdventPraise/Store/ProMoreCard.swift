//
//  ProMoreCard.swift
//  Advent Praise
//
//  Advent Praise Pro at the top of More: one compact row. A small tile of
//  the paywall's scenery (the logo glowing in the gold light), the title,
//  one line, and a chevron. The whole card opens the paywall, which also
//  carries Restore purchases and, for Pro, the thank-you.
//
//  Free: the free plays of the piano left. Pro: yours for good.
//

import SwiftUI

struct ProMoreCard: View {
    /// Opens the paywall (the thank-you and Restore, for Pro).
    let onSeePro: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(FreePlays.self) private var freePlays
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .callout) private var tileSize: CGFloat = 48

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    private var subtitle: String {
        if store.isPro { return String(localized: "Thank you. Pro is yours for good.") }
        return switch freePlays.remaining {
        case 0: String(localized: "Your free plays of the piano are used")
        case 1: String(localized: "1 free play of the piano left")
        default: String(localized: "\(freePlays.remaining) of \(FreePlayAllowance.free) free plays of the piano left")
        }
    }

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.card)
        Button(action: onSeePro) {
            HStack(spacing: DS.Space.m) {
                tile
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    HStack(spacing: DS.Space.xxs) {
                        Text("Advent Praise Pro").font(DS.Typeface.rowTitle)
                        if store.isPro {
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
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(surface.secondary)
            }
            .padding(.vertical, DS.Space.m)
            .padding(.leading, DS.Space.m)
            .padding(.trailing, DS.Space.m + DS.Space.xxs)
            .background(shape.fill(.primary.opacity(DS.Fill.row)))
            .overlay(shape.strokeBorder(palette.brass.opacity(palette.isDark ? 0.35 : 0.28)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Advent Praise Pro, \(subtitle)")
        .accessibilityHint("Opens Advent Praise Pro")
        .accessibilityAddTraits(.isButton)
    }

    /// The logo in the light, small. Decoration only. Capped so the row
    /// stays a row at the largest text sizes.
    private var tile: some View {
        let size = min(tileSize, 64)
        return ZStack {
            palette.ground
            PaywallLight(palette: palette, intensity: 0.9)
            PaywallLogo(palette: palette, width: size * 0.42)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle.ds(DS.Radius.tile))
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Pro card · paper") {
    ScrollView {
        ProMoreCard {}.padding()
    }
    .environment(PurchaseStore())
    .environment(FreePlays())
    .dsSurface(.paper)
}

#Preview("Pro card · black") {
    ScrollView {
        ProMoreCard {}.padding()
    }
    .environment(PurchaseStore())
    .environment(FreePlays())
    .dsSurface(.black)
}
