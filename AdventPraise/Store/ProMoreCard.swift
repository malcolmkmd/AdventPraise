//
//  ProMoreCard.swift
//  Advent Praise
//
//  Advent Praise Pro at the top of More: a card with a strip of the
//  paywall's scenery (the logo in the gold light over a small crowd of
//  raised hands), so it reads as the paywall's family.
//
//  Free: what Pro opens, the free plays of the piano left, and a button to
//  the paywall. Pro: thanks, and Restore purchases for a new phone.
//

import SwiftUI

struct ProMoreCard: View {
    /// Opens the paywall (free users only).
    let onSeePro: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(FreePlays.self) private var freePlays
    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var lifted = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.card)
        VStack(alignment: .leading, spacing: 0) {
            scenery
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if store.isPro { proContent } else { freeContent }
            }
            .padding(DS.Space.l - DS.Space.xxs)
        }
        .background(shape.fill(.primary.opacity(DS.Fill.row)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.brass.opacity(palette.isDark ? 0.35 : 0.28)))
        .onAppear { lifted = true }
    }

    // MARK: Scenery

    /// The logo in the light, over the crowd. Decoration only.
    private var scenery: some View {
        ZStack(alignment: .bottom) {
            palette.ground
            PaywallLight(palette: palette, intensity: 0.8)
            PaywallHands(palette: palette, lifted: lifted, height: 40)
                .padding(.bottom, -6)
            PaywallLogo(palette: palette, width: 34)
                .padding(.bottom, 34)
                .accessibilityHidden(true)
        }
        .frame(height: 104)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    // MARK: Free

    @ViewBuilder private var freeContent: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("Advent Praise Pro").dsEyebrow(tracking: 1.4).foregroundStyle(palette.brass)
            Text("Sing without limits")
                .font(DS.Typeface.sheetTitle)
                .accessibilityAddTraits(.isHeader)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 140),
                                     spacing: DS.Space.s, alignment: .leading)],
                  alignment: .leading, spacing: DS.Space.s) {
            ForEach(Array(ProPaywallView.lines.enumerated()), id: \.offset) { _, line in
                ProCardLine(systemImage: line.image, text: line.text, palette: palette)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What Pro opens")
        FreePlaysMeter(remaining: freePlays.remaining, palette: palette)
        GlassButton(title: "See Advent Praise Pro", tint: palette.brass, fullWidth: true, action: onSeePro)
            .accessibilityHint("Opens Advent Praise Pro, a one-time purchase")
        restoreButton(title: "Already bought Pro? Restore")
            .frame(maxWidth: .infinity)
            .padding(.top, -DS.Space.xs)
    }

    // MARK: Pro

    @ViewBuilder private var proContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(palette.brass)
                .accessibilityHidden(true)
            Text("You have Advent Praise Pro")
                .font(DS.Typeface.panelTitle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        Text("Thank you for supporting Advent Praise. The piano, church mode with AirPlay, the pitch pipe and Memorise are yours for good, on every device signed in with this Apple Account.")
            .font(DS.Typeface.rowBody)
            .foregroundStyle(surface.secondary)
            .fixedSize(horizontal: false, vertical: true)
        restoreButton(title: "Restore purchases")
    }

    private func restoreButton(title: LocalizedStringKey) -> some View {
        Button {
            Task { await store.restore(source: .more) }
        } label: {
            HStack(spacing: DS.Space.xs) {
                if store.isRestoring {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").accessibilityHidden(true)
                }
                Text(title)
            }
            .font(DS.Typeface.label)
            .foregroundStyle(surface.tint)
            .frame(minHeight: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isRestoring)
        .accessibilityHint("Checks the App Store for purchases made with this Apple Account")
    }
}

// MARK: - Pieces

private struct ProCardLine: View {
    let systemImage: String
    let text: LocalizedStringKey
    let palette: PaywallPalette
    @ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 24

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.brass)
                .frame(width: iconSize, height: iconSize)
                .background(Circle().fill(palette.gold.opacity(palette.isDark ? 0.16 : 0.2)))
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typeface.detail.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The free plays left of the piano, as a row of pips and a line.
private struct FreePlaysMeter: View {
    let remaining: Int
    let palette: PaywallPalette
    @Environment(\.dsSurface) private var surface

    private var label: String {
        switch remaining {
        case 0: String(localized: "Your free plays of the piano are used")
        case 1: String(localized: "1 free play of the piano left")
        default: String(localized: "\(remaining) of \(FreePlayAllowance.free) free plays of the piano left")
        }
    }

    var body: some View {
        HStack(spacing: DS.Space.s) {
            HStack(spacing: 3) {
                ForEach(0..<FreePlayAllowance.free, id: \.self) { index in
                    Capsule()
                        .fill(index < remaining ? AnyShapeStyle(palette.brass) : AnyShapeStyle(.primary.opacity(DS.Fill.stroke)))
                        .frame(width: 5, height: 14)
                }
            }
            .accessibilityHidden(true)
            Text(label)
                .font(DS.Typeface.caption.weight(.medium))
                .foregroundStyle(surface.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
