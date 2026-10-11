//
//  WorshipModeControls.swift
//  Advent Praise 7 — Vesper design system
//
//  The overlay for reading in church: lyrics at worship scale on a maximum-
//  contrast ground, screen kept awake, and only three things to touch —
//  previous verse, next verse, and leave. Everything is ≥ 72 pt and sits at
//  the bottom corners where a thumb holding the phone already is.
//
//  Bluetooth page-turners and keyboards work too: ← / → / space / page keys.
//
//  The parent owns verse state and auto-hides the controls after ~4 s idle
//  (`isVisible`). A tap anywhere on the lyrics shows them again.
//

import SwiftUI
import UIKit

struct WorshipModeControls: View {
    let hymnNumber: Int
    let title: String
    /// e.g. "Verse 2 of 4", "Chorus", or the hymnal's refrain label.
    let position: String
    var canGoBack = true
    var canGoForward = true
    var isVisible = true
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onExit: () -> Void
    var onTextSmaller: (() -> Void)? = nil
    var onTextLarger: (() -> Void)? = nil

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var hasKeyFocus: Bool

    var body: some View {
        DSGlassGroup(spacing: 28) {
            controls
        }
    }

    private var controls: some View {
        VStack {
            topBar
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.s)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion), value: isVisible)
        // Key handling stays live even while the controls are hidden.
        .focusable()
        .focused($hasKeyFocus)
        .focusEffectDisabled()
        .onAppear { hasKeyFocus = true }
        .onKeyPress(keys: [.rightArrow, .downArrow, .space, .pageDown]) { _ in
            guard canGoForward else { return .ignored }
            onNext(); return .handled
        }
        .onKeyPress(keys: [.leftArrow, .upArrow, .pageUp]) { _ in
            guard canGoBack else { return .ignored }
            onPrevious(); return .handled
        }
        .onKeyPress(.escape) { onExit(); return .handled }
        .sensoryFeedback(.selection, trigger: position)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: Top: what's showing + leave

    private var topBar: some View {
        HStack(spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text(String(hymnNumber)).font(DS.Typeface.numeral).foregroundStyle(surface.brass)
                    Text(title).font(DS.Typeface.label).lineLimit(1)
                }
                Text(position).dsEyebrow().foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DS.Space.panel)
            .padding(.vertical, DS.Space.s)
            .modifier(WorshipGlass(shape: Capsule()))
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if let onTextSmaller, let onTextLarger {
                HStack(spacing: 0) {
                    WorshipIconButton(systemImage: "textformat.size.smaller", label: "Smaller text",
                                      size: DS.Size.hitTarget + 8, action: onTextSmaller)
                    WorshipIconButton(systemImage: "textformat.size.larger", label: "Larger text",
                                      size: DS.Size.hitTarget + 8, action: onTextLarger)
                }
                .modifier(WorshipGlass(shape: Capsule()))
            }

            WorshipIconButton(systemImage: "xmark", label: "Leave worship mode",
                              size: DS.Size.hitTarget + 8, action: onExit)
                .modifier(WorshipGlass(shape: Circle(), interactive: true))
        }
    }

    // MARK: Bottom: previous / next

    private var bottomBar: some View {
        HStack {
            WorshipIconButton(systemImage: "chevron.left", label: "Previous verse",
                              size: DS.Size.worshipHitTarget, action: onPrevious)
                .modifier(WorshipGlass(shape: Circle(), interactive: true))
                .disabled(!canGoBack)
                .opacity(canGoBack ? 1 : DS.Fill.disabled)
            Spacer()
            WorshipIconButton(systemImage: "chevron.right", label: "Next verse",
                              size: DS.Size.worshipHitTarget, action: onNext)
                .modifier(WorshipGlass(shape: Circle(), interactive: true, tint: surface.tint))
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : DS.Fill.disabled)
        }
    }
}

/// iOS 26: glass grouped so the controls blend as one layer; next is tinted.
/// Fallback: always the *opaque* raised colour — worship mode never relies on
/// translucency, so the controls stay legible over 60 pt lyrics.
private struct WorshipGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive = false
    var tint: Color? = nil
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(shape.fill(tint ?? surface.elevated))
                .overlay(shape.strokeBorder(surface.highContrastForeground.opacity(0.25), lineWidth: 1))
                .foregroundStyle(tint == nil ? surface.highContrastForeground : surface.onTint)
        }
    }

    @available(iOS 26, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        return interactive ? glass.interactive() : glass
    }
}

private struct WorshipIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .bold))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Keep the screen awake

extension View {
    /// Disables auto-lock while this view is on screen (worship mode only).
    func dsKeepsScreenAwake(_ isOn: Bool = true) -> some View {
        modifier(KeepAwake(isOn: isOn))
    }
}

private struct KeepAwake: ViewModifier {
    let isOn: Bool
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = isOn }
            .onChange(of: isOn) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

#Preview("WorshipModeControls") {
    @Previewable @State var verse = 2
    ZStack {
        ChapterVerseBlock(number: verse, lines: ["Perfect submission,", "perfect delight,",
                                                 "Visions of rapture", "now burst on my sight;"],
                          style: .worship, state: .current)
            .padding(.horizontal, DS.Space.gutter)
        WorshipModeControls(hymnNumber: 30, title: "Blessed Assurance", position: "Verse \(verse) of 3",
                            canGoBack: verse > 1, canGoForward: verse < 3,
                            onPrevious: { verse -= 1 }, onNext: { verse += 1 }, onExit: {},
                            onTextSmaller: {}, onTextLarger: {})
    }
    .dsSurface(.black)
    .environment(\.dsWorshipMode, true)
    .dsKeepsScreenAwake()
}

#Preview("WorshipModeControls · Paper, daylight") {
    ZStack {
        ChorusBlock(lines: ["This is my story,", "this is my song,"], style: .worship, state: .current)
            .padding(.horizontal, DS.Space.gutter)
        WorshipModeControls(hymnNumber: 30, title: "Blessed Assurance", position: "Chorus",
                            canGoForward: true, onPrevious: {}, onNext: {}, onExit: {})
    }
    .dsSurface(.paper)
    .environment(\.dsWorshipMode, true)
}
