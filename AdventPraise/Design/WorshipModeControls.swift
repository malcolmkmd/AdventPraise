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
        // Spacing just above the text-size pair's gap: those two blend into one
        // pill, while leave, the title and previous / next stay separate shapes.
        DSGlassGroup(spacing: DS.Space.s) {
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
                // Two neighbouring glass buttons; the container blends them into one pill.
                HStack(spacing: DS.Space.xxs) {
                    WorshipIconButton(systemImage: "textformat.size.smaller", label: "Smaller text",
                                      size: DS.Size.hitTarget + 8, action: onTextSmaller)
                    WorshipIconButton(systemImage: "textformat.size.larger", label: "Larger text",
                                      size: DS.Size.hitTarget + 8, action: onTextLarger)
                }
            }

            WorshipIconButton(systemImage: "xmark", label: "Leave worship mode",
                              size: DS.Size.hitTarget + 8, action: onExit)
        }
    }

    // MARK: Bottom: previous / next

    private var bottomBar: some View {
        HStack {
            WorshipIconButton(systemImage: "chevron.left", label: "Previous verse",
                              size: DS.Size.worshipHitTarget, action: onPrevious)
                .disabled(!canGoBack)
            Spacer()
            // The one primary action on this screen: the only prominent control.
            WorshipIconButton(systemImage: "chevron.right", label: "Next verse",
                              size: DS.Size.worshipHitTarget, isProminent: true, action: onNext)
                .disabled(!canGoForward)
        }
    }
}

/// Informational glass for the title pill (not a control, so not interactive).
/// Fallback: always the *opaque* raised colour — worship mode never relies on
/// translucency, so the controls stay legible over 60 pt lyrics.
private struct WorshipGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(shape.fill(surface.elevated))
                .overlay(shape.strokeBorder(surface.highContrastForeground.opacity(0.25), lineWidth: 1))
                .foregroundStyle(surface.highContrastForeground)
        }
    }
}

/// iOS 26: the native `.glass` / `.glassProminent` button styles with a
/// circular border shape, so press, highlight and Reduce Transparency come
/// from the system. Fallback: an opaque circle (prominent = solid tint).
private struct WorshipIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let size: CGFloat
    var isProminent = false
    let action: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if #available(iOS 26, *) {
            // The glass style pads the label by ~6 pt a side; the circle still lands on `size`.
            let button = Button(action: action) { glyph(side: size - DS.Space.m) }
                .buttonBorderShape(.circle)
                .tint(surface.tint)
                .accessibilityLabel(label)
                // The system's disabled glass is too subtle to read across a pew.
                .opacity(isEnabled ? 1 : DS.Fill.disabled)
            if isProminent {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.glass)
            }
        } else {
            Button(action: action) {
                glyph(side: size)
                    .background(Circle().fill(isProminent ? surface.tint : surface.elevated))
                    .overlay(Circle().strokeBorder(surface.highContrastForeground.opacity(isProminent ? 0 : 0.25), lineWidth: 1))
                    .foregroundStyle(isProminent ? surface.onTint : surface.highContrastForeground)
                    .opacity(isEnabled ? 1 : DS.Fill.disabled)
            }
            .buttonStyle(DSPressStyle())
            .accessibilityLabel(label)
        }
    }

    private func glyph(side: CGFloat) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.36, weight: .bold))
            .frame(width: side, height: side)
            .contentShape(Circle())
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
