//
//  GlassButton.swift
//  Advent Praise 7 — Vesper design system
//
//  Three kinds of button, one API:
//  • .primary   — the single most important action on a surface (Go, Unlock, Get started)
//  • .secondary — everything else that floats (Continue, Restore, Exit)
//  • .icon      — a 44 pt circular glyph button (close, +, share)
//
//  iOS 26 uses the system `.glassProminent` / `.glass` button styles so they
//  pick up Liquid Glass press and morph behaviour. iOS 17–25 draws the
//  Vesper look by hand.
//

import SwiftUI

struct GlassButton: View {
    enum Kind { case primary, secondary, icon }

    let title: LocalizedStringKey
    var systemImage: String? = nil
    var kind: Kind = .primary
    /// Defaults to the surface tint (Evergreen). Pass `surface.brass` for purchases.
    var tint: Color? = nil
    var isLoading = false
    var fullWidth = false
    let action: () -> Void

    @Environment(\.dsSurface) private var surface
    @Environment(\.isEnabled) private var isEnabled

    private var resolvedTint: Color { tint ?? surface.tint }

    var body: some View {
        if #available(iOS 26, *) {
            glassButton
        } else {
            Button(action: action) { label }
                .buttonStyle(DSFallbackButtonStyle(kind: kind, tint: resolvedTint, surface: surface))
                .accessibilityLabel(Text(title))
        }
    }

    @available(iOS 26, *)
    @ViewBuilder private var glassButton: some View {
        let button = Button(action: action) { label }
            .tint(resolvedTint)
            .controlSize(.large)
            .accessibilityLabel(Text(title))
        switch kind {
        case .primary:
            button.buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: DS.Radius.key))
        case .secondary:
            button.buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: DS.Radius.key))
        case .icon:
            button.buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
    }

    @ViewBuilder private var label: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(kind == .primary ? surface.onTint : resolvedTint)
                    .accessibilityLabel("Working")
            } else if kind == .icon, let systemImage {
                Image(systemName: systemImage)
                    .font(.system(.body, weight: .semibold))
                    .frame(width: 24, height: 24)
            } else if let systemImage {
                Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
            } else {
                Text(title)
            }
        }
        .font(DS.Typeface.button)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: fullWidth && kind != .icon ? .infinity : nil)
        .frame(minHeight: kind == .icon ? DS.Size.hitTarget - 8 : 24)
        .opacity(isEnabled ? 1 : DS.Fill.disabled + 0.1)
    }
}

/// iOS 17–25 rendering of GlassButton.
private struct DSFallbackButtonStyle: ButtonStyle {
    let kind: GlassButton.Kind
    let tint: Color
    let surface: DSSurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        styled(configuration.label)
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .opacity(pressed ? 0.85 : 1)
            .animation(DS.Motion.press, value: pressed)
    }

    @ViewBuilder private func styled(_ label: Configuration.Label) -> some View {
        switch kind {
        case .primary:
            label
                .foregroundStyle(surface.onTint)
                .padding(.horizontal, DS.Space.l)
                .frame(minHeight: 50)
                .background(RoundedRectangle.ds(DS.Radius.key).fill(tint)
                    .shadow(color: tint.opacity(0.3), radius: 8, y: 4))
        case .secondary:
            label
                .foregroundStyle(tint)
                .padding(.horizontal, DS.Space.l)
                .frame(minHeight: 50)
                .background(RoundedRectangle.ds(DS.Radius.key).fill(tint.opacity(DS.Fill.tintSelected)))
                .background(RoundedRectangle.ds(DS.Radius.key)
                    .fill(reduceTransparency ? AnyShapeStyle(surface.elevated) : AnyShapeStyle(.thinMaterial)))
        case .icon:
            label
                .foregroundStyle(.primary)
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background(Circle().fill(reduceTransparency ? AnyShapeStyle(surface.elevated) : AnyShapeStyle(.thinMaterial)))
                .overlay(Circle().strokeBorder(.primary.opacity(DS.Fill.hairline)))
        }
    }
}

#Preview("GlassButton") {
    ZStack {
        DSPreviewBackdrop()
        VStack(spacing: DS.Space.m) {
            GlassButton(title: "Open hymn", systemImage: "arrow.right", fullWidth: true) {}
            GlassButton(title: "Continue", kind: .secondary, fullWidth: true) {}
            GlassButton(title: "Unlock all hymnals", tint: DS.Palette.brass, fullWidth: true) {}
            GlassButton(title: "Purchasing", isLoading: true, fullWidth: true) {}
            GlassButton(title: "Open hymn", fullWidth: true) {}.disabled(true)
            HStack(spacing: DS.Space.m) {
                GlassButton(title: "Close", systemImage: "xmark", kind: .icon) {}
                GlassButton(title: "New playlist", systemImage: "plus", kind: .icon) {}
                GlassButton(title: "Share", systemImage: "square.and.arrow.up", kind: .icon) {}
            }
        }
        .padding(DS.Space.l)
    }
    .dsSurface(.parchment)
}

#Preview("GlassButton · Muted") {
    VStack(spacing: DS.Space.m) {
        GlassButton(title: "Get started", fullWidth: true) {}
        GlassButton(title: "Continue", kind: .secondary, fullWidth: true) {}
    }
    .padding(DS.Space.l)
    .dsSurface(.muted)
}
