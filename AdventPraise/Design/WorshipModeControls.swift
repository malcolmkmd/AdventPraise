//
//  WorshipModeControls.swift
//  Advent Praise 7 — Vesper design system
//
//  The overlay for reading in church: lyrics at worship scale on a maximum-
//  contrast ground, screen kept awake, and a few large controls floating
//  over it. Top buttons are 52 pt, the rest ≥ 60 pt; previous / next are 72 pt.
//
//  Top, two rows so a long title never has to share a line with buttons:
//  leave on the leading edge, AirPlay and the translation globe trailing;
//  under them the hymn card (number in brass, the full title over up to
//  two lines, "Verse 2 of 4" and progress dots; tap it to jump to another
//  number). From xLarge text up the number sits above the title.
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
    /// Where the sung sequence is (0-based) and how long it is, for the
    /// progress dots. No dots when there's one block or too many to count.
    var step = 0
    var stepCount = 0
    /// The open hymnal's language, read out on the globe button.
    var language = ""
    var canGoBack = true
    var canGoForward = true
    var canShrinkText = true
    var canEnlargeText = true
    var isVisible = true
    /// The AirPlay button: hidden, the route picker, or (without Pro) a
    /// button that calls `onAirPlayLocked` for the paywall.
    var airPlay: WorshipAirPlay = .hidden
    var onAirPlayLocked: () -> Void = {}
    /// The hymn is also showing on a TV or projector.
    var isOnExternalScreen = false
    @Binding var showNumberPad: Bool
    @Binding var showTranslations: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onExit: () -> Void
    var onTextSmaller: (() -> Void)? = nil
    var onTextLarger: (() -> Void)? = nil
    /// The top bar's height, so the parent can start the lyric below it.
    var onTopBarHeight: (CGFloat) -> Void = { _ in }
    @ViewBuilder var numberPad: () -> NumberPad
    @ViewBuilder var translations: () -> Translations

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var hasKeyFocus: Bool

    /// Text size buttons.
    private let topSize: CGFloat = 60
    /// Leave, AirPlay and globe: their own row now, so a little smaller.
    private let barSize: CGFloat = 52
    /// More blocks than this and the dots stop being countable at a glance.
    private let maxDots = 12

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

    // MARK: Top: leave · AirPlay · translation, then what's showing (tap to jump)

    private var topBar: some View {
        // Wider than the glass group's spacing, so the card stays its own shape.
        VStack(alignment: .leading, spacing: DS.Space.panel) {
            controlsRow
            hymnCard
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onTopBarHeight($0) }
    }

    private var controlsRow: some View {
        HStack(spacing: DS.Space.m) {
            WorshipButton(systemImage: "xmark", label: "Leave worship mode", size: barSize, action: onExit)
            Spacer(minLength: 0)

            switch airPlay {
            case .hidden:
                EmptyView()
            case .locked:
                WorshipButton(systemImage: "airplayvideo", label: "AirPlay", size: barSize, action: onAirPlayLocked)
                    .accessibilityHint("Showing the hymn on a TV or projector needs Advent Praise Pro")
            case .available:
                AirPlayRouteButton(size: barSize)
            }

            WorshipButton(systemImage: "globe", label: "Translation", size: barSize) {
                showTranslations = true
            }
            .accessibilityValue(language)
            .accessibilityHint("Shows this hymn in another hymnal")
            .popover(isPresented: $showTranslations, arrowEdge: .top) {
                translations().presentationCompactAdaptation(.popover)
            }
        }
    }

    /// Number beside the title; from xLarge text up the number gets its own
    /// line (with the position) so the title keeps the full width. Beside it,
    /// a 45-character title already needs three lines at xLarge on 375 pt.
    private var stacksNumber: Bool { dynamicTypeSize >= .xLarge }

    private var hymnCard: some View {
        Button { showNumberPad = true } label: {
            Group {
                if stacksNumber {
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        HStack(alignment: .center, spacing: DS.Space.m) {
                            numberLabel
                            Spacer(minLength: 0)
                            positionLabel
                        }
                        titleLabel
                    }
                } else {
                    HStack(alignment: .center, spacing: DS.Space.m) {
                        numberLabel
                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                            titleLabel
                            positionLabel
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .contentShape(RoundedRectangle.ds(DS.Radius.card))
        }
        .modifier(WorshipButtonChrome(shape: RoundedRectangle.ds(DS.Radius.card),
                                      border: .roundedRectangle(radius: DS.Radius.card)))
        // A readable measure on iPad and in landscape.
        .frame(maxWidth: DS.Space.lecternMaxWidth, alignment: .leading)
        .accessibilityLabel(isOnExternalScreen ? "Hymn \(hymnNumber), \(title). \(position). Also on the big screen."
                                               : "Hymn \(hymnNumber), \(title). \(position)")
        .accessibilityHint("Opens the number pad to jump to another hymn")
        .popover(isPresented: $showNumberPad, arrowEdge: .top) {
            numberPad().presentationCompactAdaptation(.popover)
        }
    }

    private var numberLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
            Text(String(hymnNumber))
                .font(DS.Typeface.display).monospacedDigit()
                .contentTransition(.numericText())
            Image(systemName: "chevron.down").font(.caption.weight(.bold))
        }
        .foregroundStyle(surface.brass)
        .fixedSize()
    }

    private var titleLabel: some View {
        // Two lines covers every title in the bundled hymnals at these widths;
        // the third is a safety net rather than truncating.
        Text(title)
            .font(DS.Typeface.rowTitle)
            .foregroundStyle(surface.highContrastForeground)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var positionLabel: some View {
        HStack(spacing: DS.Space.s) {
            if isOnExternalScreen {
                Image(systemName: "tv").font(.caption2.weight(.bold)).foregroundStyle(surface.tint)
            }
            Text(position).dsEyebrow().foregroundStyle(surface.secondary)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
            if stepCount > 1, stepCount <= maxDots, !stacksNumber {
                progressDots
            }
        }
    }

    /// Already said by the position label; decoration for VoiceOver.
    private var progressDots: some View {
        HStack(spacing: DS.Space.xxs) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == step ? surface.brass : surface.secondary.opacity(0.45))
                    .frame(width: 5, height: 5)
            }
        }
        .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: step)
        .accessibilityHidden(true)
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

enum WorshipAirPlay: Equatable, Sendable {
    case hidden, locked, available
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
