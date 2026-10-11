//
//  GlassCard.swift
//  Advent Praise 7 — Vesper design system
//
//  A floating rounded panel. Use for content that hovers over the reading
//  surface (iPad overlays, What's New tiles, worship HUD). Do not nest one
//  GlassCard inside another glass layer — use `DSInsetGroup` for that.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var radius: CGFloat = DS.Radius.card
    var padding: CGFloat = DS.Space.panel
    var depth: DSGlassDepth = .card
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let card = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        if #available(iOS 26, *) {
            // Informational glass: never interactive.
            card.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: RoundedRectangle.ds(radius))
        } else {
            card.dsGlass(RoundedRectangle.ds(radius), depth: depth, tint: tint)
        }
    }
}

/// The non-glass grouping used *inside* glass (Lectern panels, sheets):
/// a `.primary` 5 % fill. Glass on glass is never allowed.
struct DSInsetGroup<Content: View>: View {
    var title: LocalizedStringKey? = nil
    @ViewBuilder var content: Content
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if let title {
                Text(title).dsEyebrow().foregroundStyle(surface.secondary)
                    .padding(.horizontal, DS.Space.xxs)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.row)))
                .clipShape(RoundedRectangle.ds(DS.Radius.tile))
        }
    }
}

#Preview("GlassCard") {
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        VStack(spacing: DS.Space.m) {
            GlassCard {
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("Now singing").dsEyebrow().foregroundStyle(.secondary)
                    Text("30 · Blessed Assurance").font(DS.Typeface.rowTitle)
                }
            }
            GlassCard(tint: DS.Palette.evergreen.opacity(0.4)) {
                Label("Tinted card for a single primary message", systemImage: "sparkles")
                    .font(DS.Typeface.label)
            }
            GlassCard {
                DSInsetGroup(title: "Inset inside glass") {
                    Text("Row one").padding(DS.Space.m).frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Text("Row two").padding(DS.Space.m).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(DS.Space.l)
    }
    .dsSurface(.paper)
}

#Preview("GlassCard · Black") {
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        GlassCard {
            Text("Glass over a dark surface").font(DS.Typeface.label)
        }
        .padding(DS.Space.l)
    }
    .dsSurface(.black)
}
