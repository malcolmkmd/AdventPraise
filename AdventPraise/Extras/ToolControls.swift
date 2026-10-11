//
//  ToolControls.swift
//  Advent Praise
//
//  Controls for the Tools sheets (pitch pipe, memorise), drawn from the
//  reading surface's tokens so every label clears WCAG AA on all five
//  surfaces. They are opaque (no material), so Reduce Transparency changes
//  nothing. Ratios: Tools/contrast_check.py.
//

import SwiftUI

/// The Tools sheet's ground: the reading surface, opaque, and its colour
/// scheme, so the navigation bar, Done and system controls match the
/// surface rather than the system appearance.
struct ToolSheetChrome: ViewModifier {
    let surface: DSSurface
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .dsSurface(surface)
            .presentationBackground(contrast == .increased ? surface.highContrastBackground : surface.background)
    }
}

/// A selectable capsule (verse tabs, levels). Selected: solid tint with
/// `onTint` text. Otherwise: `elevated` with a `controlBorder` outline.
struct ToolChipStyle: ButtonStyle {
    var isSelected: Bool
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typeface.label)
            .lineLimit(1)
            .padding(.horizontal, DS.Space.panel)
            .frame(minHeight: DS.Size.hitTarget)
            .foregroundStyle(isSelected ? AnyShapeStyle(surface.onTint) : AnyShapeStyle(.primary))
            .background(Capsule().fill(isSelected ? surface.tint : surface.elevated))
            .overlay(Capsule().strokeBorder(isSelected ? .clear : surface.controlBorder, lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
            .animation(DS.Motion.select, value: isSelected)
    }
}

/// A full-width action. Prominent: solid tint, `onTint` label. Plain:
/// `elevated` with an outline and a tint label.
struct ToolButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.dsSurface) private var surface
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typeface.button)
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget + 6)
            .foregroundStyle(prominent ? surface.onTint : surface.tint)
            .background(RoundedRectangle.ds(DS.Radius.key).fill(prominent ? surface.tint : surface.elevated))
            .overlay(RoundedRectangle.ds(DS.Radius.key)
                .strokeBorder(prominent ? .clear : surface.controlBorder, lineWidth: 1))
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : DS.Fill.disabled)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
    }
}

/// The bar of actions pinned under a Tools sheet: opaque `elevated` with a
/// hairline on top.
struct ToolActionBar<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.m) { content }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.m)
            .background(surface.elevated.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(surface.controlBorder.opacity(0.4)).frame(height: 1) }
    }
}
