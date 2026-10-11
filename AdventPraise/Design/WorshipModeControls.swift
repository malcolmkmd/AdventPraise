//
//  WorshipModeControls.swift
//  Advent Praise 7 — Vesper design system
//
//  The overlay for reading in church: lyrics at worship scale on a maximum-
//  contrast ground, screen kept awake, and a few large controls floating
//  over it. Everything is ≥ 60 pt; previous / next are 72 pt.
//
//  Top: the hymn chip (number, title, position; tap it to jump to another
//  number), the translation globe, and leave.
//  Bottom, where a thumb already is: previous, text size, next.
//
//  Bluetooth page-turners and keyboards work too: ← / → / space / page keys.
//
//  The parent owns verse state, presents the number pad and translation
//  switcher through the two bindings, and auto-hides the controls after
//  ~4 s idle (`isVisible`). A tap anywhere on the lyrics shows them again.
//

import SwiftUI
import UIKit

struct WorshipModeControls<NumberPad: View, Translations: View>: View {
    let hymnNumber: Int
    let title: String
    /// e.g. "Verse 2 of 4", "Chorus", or the hymnal's refrain label.
    let position: String
    /// The open hymnal's language, read out on the globe button.
    var language = ""
    var canGoBack = true
    var canGoForward = true
    var canShrinkText = true
    var canEnlargeText = true
    var isVisible = true
    @Binding var showNumberPad: Bool
    @Binding var showTranslations: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onExit: () -> Void
    var onTextSmaller: (() -> Void)? = nil
    var onTextLarger: (() -> Void)? = nil
    @ViewBuilder var numberPad: () -> NumberPad
    @ViewBuilder var translations: () -> Translations

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var hasKeyFocus: Bool

    private let topSize: CGFloat = 60

    var body: some View {
        // Fade the container, not its children: a GlassEffectContainer draws
        // its glass itself, so opacity applied inside it leaves the buttons up.
        // Spacing just above the text-size pair's gap: those two blend into one
        // pill, while the other controls stay separate shapes.
        DSGlassGroup(spacing: DS.Space.m) {
            VStack {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.s)
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion), value: isVisible)
        // Key handling stays live even while the controls are hidden.
        .focusable()
        .focused($hasKeyFocus)
        .focusEffectDisabled()
        .onAppear { hasKeyFocus = true }
        .onChange(of: showNumberPad || showTranslations) { _, presenting in
            if !presenting { hasKeyFocus = true }
        }
        .onKeyPress(keys: [.rightArrow, .downArrow, .space, .pageDown]) { _ in
            guard canGoForward else { return .ignored }
            onNext(); return .handled
        }
        .onKeyPress(keys: [.leftArrow, .upArrow, .pageUp]) { _ in
            guard canGoBack else { return .ignored }
            onPrevious(); return .handled
        }
        .onKeyPress(.escape) { onExit(); return .handled }
        // No haptic on `position` here: the parent plays one per verse step.
        // Chrome only; the lyric itself follows Dynamic Type (see ChurchModeView).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // MARK: Top: what's showing (tap to jump) · translation · leave

    private var topBar: some View {
        HStack(spacing: DS.Space.m) {
            hymnChip
            Spacer(minLength: 0)

            WorshipButton(systemImage: "globe", label: "Translation", size: topSize) {
                showTranslations = true
            }
            .accessibilityValue(language)
            .accessibilityHint("Shows this hymn in another hymnal")
            .popover(isPresented: $showTranslations, arrowEdge: .top) {
                translations().presentationCompactAdaptation(.popover)
            }

            WorshipButton(systemImage: "xmark", label: "Leave worship mode", size: topSize, action: onExit)
        }
    }

    private var hymnChip: some View {
        Button { showNumberPad = true } label: {
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
                        Text(String(hymnNumber))
                            .font(DS.Typeface.numeral).monospacedDigit()
                            .contentTransition(.numericText())
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(surface.brass)
                    Text(title).font(DS.Typeface.label).lineLimit(1)
                }
                Text(position).dsEyebrow().foregroundStyle(surface.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DS.Space.xs)
            .frame(minHeight: topSize - DS.Space.m, alignment: .leading)
            .contentShape(Capsule())
        }
        .modifier(WorshipButtonChrome(shape: Capsule(), border: .capsule))
        .accessibilityLabel("Hymn \(hymnNumber), \(title). \(position)")
        .accessibilityHint("Opens the number pad to jump to another hymn")
        .popover(isPresented: $showNumberPad, arrowEdge: .top) {
            numberPad().presentationCompactAdaptation(.popover)
        }
    }

    // MARK: Bottom: previous · text size · next

    private var bottomBar: some View {
        HStack(spacing: DS.Space.m) {
            WorshipButton(systemImage: "chevron.left", label: "Previous verse",
                          size: DS.Size.worshipHitTarget, action: onPrevious)
                .disabled(!canGoBack)
            Spacer(minLength: 0)
            if let onTextSmaller, let onTextLarger {
                HStack(spacing: DS.Space.s) {
                    WorshipButton(systemImage: "textformat.size.smaller", label: "Smaller text",
                                  size: topSize, action: onTextSmaller)
                        .disabled(!canShrinkText)
                    WorshipButton(systemImage: "textformat.size.larger", label: "Larger text",
                                  size: topSize, action: onTextLarger)
                        .disabled(!canEnlargeText)
                }
            }
            Spacer(minLength: 0)
            // The one primary action on this screen: the only prominent control.
            WorshipButton(systemImage: "chevron.right", label: "Next verse",
                          size: DS.Size.worshipHitTarget, prominent: true, action: onNext)
                .disabled(!canGoForward)
        }
    }
}

extension WorshipModeControls where NumberPad == EmptyView, Translations == EmptyView {
    /// Previews and callers without the jump / translation popovers.
    init(hymnNumber: Int, title: String, position: String, canGoBack: Bool = true, canGoForward: Bool = true,
         onPrevious: @escaping () -> Void, onNext: @escaping () -> Void, onExit: @escaping () -> Void,
         onTextSmaller: (() -> Void)? = nil, onTextLarger: (() -> Void)? = nil) {
        self.init(hymnNumber: hymnNumber, title: title, position: position,
                  canGoBack: canGoBack, canGoForward: canGoForward,
                  showNumberPad: .constant(false), showTranslations: .constant(false),
                  onPrevious: onPrevious, onNext: onNext, onExit: onExit,
                  onTextSmaller: onTextSmaller, onTextLarger: onTextLarger,
                  numberPad: { EmptyView() }, translations: { EmptyView() })
    }
}

/// iOS 26: the system glass button styles (`.glass`, and `.glassProminent`
/// for next), grouped by the parent's `GlassEffectContainer`.
/// Fallback: always an *opaque* raised colour — worship mode never relies on
/// translucency, so the controls stay legible over 60 pt lyrics.
private struct WorshipButtonChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    let border: ButtonBorderShape
    var prominent = false
    @Environment(\.dsSurface) private var surface
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            Group {
                if prominent {
                    content.buttonStyle(.glassProminent).foregroundStyle(surface.onTint)
                } else {
                    content.buttonStyle(.glass)
                }
            }
            .buttonBorderShape(border)
            .tint(prominent ? surface.tint : nil)
            // The system's disabled glass is too subtle to read across a pew.
            .opacity(isEnabled ? 1 : DS.Fill.disabled)
        } else {
            content
                .buttonStyle(DSPressStyle())
                .padding(border == .capsule ? DS.Space.s : 0)
                .background(shape.fill(prominent ? surface.tint : surface.elevated))
                .overlay(shape.strokeBorder(surface.highContrastForeground.opacity(prominent ? 0 : 0.25), lineWidth: 1))
                .foregroundStyle(prominent ? surface.onTint : surface.highContrastForeground)
                .opacity(isEnabled ? 1 : DS.Fill.disabled)
        }
    }
}

private struct WorshipButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let size: CGFloat
    var prominent = false
    let action: () -> Void

    /// The glass style pads the label by ~6 pt a side; take that back off so
    /// the visible circle lands on `size` on every OS.
    private var labelSize: CGFloat {
        if #available(iOS 26, *) { size - DS.Space.m } else { size }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .bold))
                .frame(width: labelSize, height: labelSize)
                .contentShape(Circle())
        }
        .modifier(WorshipButtonChrome(shape: Circle(), border: .circle, prominent: prominent))
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
