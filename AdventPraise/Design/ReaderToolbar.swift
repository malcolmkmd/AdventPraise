//
//  ReaderToolbar.swift
//  Advent Praise 7 — Vesper design system
//
//  The Lectern: the reader's only chrome. One floating glass capsule at the
//  bottom, under the thumb. The 64 pt row is the spine and never moves;
//  panels (number pad, search, library, hymnals, more) unfold upward out of
//  it inside the same glass, then settle back.
//
//         [ ⌃ handle ]
//  Row:  [▶︎ play]  [30 Blessed Assurance / status  ⋯]  [⌗ jump]  [🔖 library]
//  Play is hidden (not disabled) when the hymn has no accompaniment file.
//
//  The handle (and the ⋯ on the title) open the hymn tray, the fuller
//  settings view. Tap or swipe up to expand; tap or swipe down to collapse.
//  Motion is a short ease-out with no overshoot.
//
//  Full width minus 20 pt, centred and capped at 560 pt — so it stays a
//  thumb-sized capsule on iPad, in landscape and in wide windows alike.
//

import SwiftUI

enum ReaderToolbarPanel: Equatable, Sendable {
    case none, hymn, jump, library
}

struct ReaderToolbar<Panel: View>: View {
    let number: Int
    let title: String
    var status: String
    var isPlaying = false
    var hasAccompaniment = false
    var openPanel: ReaderToolbarPanel = .none
    var onPlay: () -> Void = {}
    var onHymn: () -> Void = {}
    var onJump: () -> Void = {}
    var onLibrary: () -> Void = {}
    var onDismiss: () -> Void = {}
    /// Opens the hymn tray if nothing is open. Must be idempotent: a swipe
    /// may be reported by both the handle and the capsule. Defaults to `onHymn`.
    var onExpand: (() -> Void)? = nil
    @ViewBuilder var panel: Panel

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOpen: Bool { openPanel != .none }
    private var shape: RoundedRectangle { .ds(isOpen ? DS.Radius.panel : DS.Radius.dock) }

    var body: some View {
        VStack(spacing: 0) {
            LecternHandle(isOpen: isOpen, onToggle: isOpen ? onDismiss : expand)
                .simultaneousGesture(swipe)
            panel
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            row
                .overlay(alignment: .top) { if isOpen { Divider().opacity(0.6) } }
        }
        .frame(maxWidth: DS.Space.lecternMaxWidth)
        .clipShape(shape)
        .modifier(LecternGlass(shape: shape))
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: openPanel)
        .gesture(swipe)
        .accessibilityAction(.escape) { if isOpen { onDismiss() } }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, DS.Space.l)
        .padding(.bottom, DS.Space.s)
    }

    private func expand() { (onExpand ?? onHymn)() }

    /// Swipe up expands, swipe down collapses.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.height < -40, !isOpen { expand() }
            if value.translation.height > 40, isOpen { onDismiss() }
        }
    }

    // MARK: Row

    private var row: some View {
        HStack(spacing: DS.Space.s) {
            if hasAccompaniment {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(surface.onTint)
                        .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                        .background(Circle().fill(surface.tint)
                            .shadow(color: surface.tint.opacity(0.35), radius: 6, y: 3))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(DSPressStyle())
                .accessibilityLabel(isPlaying ? "Stop accompaniment" : "Play accompaniment")
            }

            HymnHandleButton(number: number, title: title, status: status, isPlaying: isPlaying,
                             isOpen: openPanel == .hymn,
                             action: openPanel == .hymn ? onDismiss : onHymn)

            ToolbarIconButton(systemImage: "circle.grid.3x3.fill", label: "Go to a hymn number or search",
                              isOn: openPanel == .jump, action: openPanel == .jump ? onDismiss : onJump)
            ToolbarIconButton(systemImage: openPanel == .library ? "bookmark.fill" : "bookmark",
                              label: "Favourites and playlists",
                              isOn: openPanel == .library, action: openPanel == .library ? onDismiss : onLibrary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: DS.Size.lecternRow)
    }
}

extension ReaderToolbar where Panel == EmptyView {
    init(number: Int, title: String, status: String, isPlaying: Bool = false, hasAccompaniment: Bool = false,
         onPlay: @escaping () -> Void = {}, onHymn: @escaping () -> Void = {},
         onJump: @escaping () -> Void = {}, onLibrary: @escaping () -> Void = {}) {
        self.init(number: number, title: title, status: status, isPlaying: isPlaying,
                  hasAccompaniment: hasAccompaniment, openPanel: .none, onPlay: onPlay, onHymn: onHymn,
                  onJump: onJump, onLibrary: onLibrary, onDismiss: {}) { EmptyView() }
    }
}

/// iOS 26: interactive Liquid Glass so the capsule responds to touch and
/// reshapes as panels open. It is the only glass in the Lectern: controls
/// inside read `\.dsOnGlass` and draw plain fills. Fallback: dock-depth
/// material with warm shadow (opaque under Reduce Transparency).
private struct LecternGlass: ViewModifier {
    let shape: RoundedRectangle
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .environment(\.dsOnGlass, true)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content.dsGlass(shape, depth: .dock)
        }
    }
}

/// A small chevron at the top of the capsule that expands the Lectern to the
/// hymn tray and collapses whatever is open. The visible strip is 18 pt; the
/// hit area is 114 × 44 pt. Swipes on it are handled by the parent.
private struct LecternHandle: View {
    let isOpen: Bool
    let onToggle: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onToggle) {
            chevron
                .font(.caption.weight(.bold))
                .foregroundStyle(surface.secondary)
                .frame(width: 88, height: 18)
                .contentShape(Rectangle().inset(by: -13))
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel("Settings panel")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityHint(isOpen ? "Collapses the bar. You can also swipe down on it."
                                  : "Expands the bar to save, church mode, hymnal, text size and more. You can also swipe up on it.")
        .accessibilityAction(named: isOpen ? "Collapse" : "Expand", onToggle)
    }

    /// Rotates with the Lectern's ease-out; under Reduce Motion the glyph swaps instead.
    @ViewBuilder private var chevron: some View {
        if reduceMotion {
            Image(systemName: isOpen ? "chevron.down" : "chevron.up")
        } else {
            Image(systemName: "chevron.up").rotationEffect(.degrees(isOpen ? 180 : 0))
        }
    }
}

/// The hymn number and title, which also open the hymn tray. A trailing ⋯
/// shows there is more behind it; it fills while the tray is open.
private struct HymnHandleButton: View {
    let number: Int
    let title: String
    let status: String
    let isPlaying: Bool
    let isOpen: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.s) {
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                        Text(String(number))
                            .font(DS.Typeface.numeral).monospacedDigit()
                            .foregroundStyle(surface.brass)
                        Text(title).font(DS.Typeface.label).lineLimit(1)
                    }
                    HStack(spacing: DS.Space.s) {
                        Text(status).font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                            .contentTransition(.numericText())
                        if isPlaying { DSPlaybackBars(isAnimating: true, color: surface.tint, height: 12) }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "ellipsis.circle")
                    .symbolVariant(isOpen ? .fill : .none)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isOpen ? surface.tint : surface.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
        }
        .buttonStyle(LecternRowPressStyle(isOn: isOpen))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hymn \(number), \(title)")
        .accessibilityValue(status)
        .accessibilityHint(isOpen ? "Closes hymn settings"
                                  : "Opens hymn settings: save, church mode, hymnal, text size and more")
        .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
    }
}

/// Pressed state for the hymn title: a quiet fill and a slight dip with a
/// short ease-out. The tint wash marks the open tray.
private struct LecternRowPressStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(RoundedRectangle.ds(DS.Radius.key).fill(fill(pressed: pressed)))
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .animation(DS.Motion.press, value: pressed)
    }

    private func fill(pressed: Bool) -> Color {
        if pressed { return Color.primary.opacity(DS.Fill.hairline) }
        return surface.tint.opacity(isOn ? DS.Fill.tintActive : 0)
    }
}

private struct ToolbarIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isOn = false
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background(RoundedRectangle.ds(DS.Radius.tile)
                    .fill(isOn ? surface.tint.opacity(DS.Fill.tintOn) : Color.primary.opacity(DS.Fill.inset)))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(isOn ? surface.tint : .primary)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(DS.Motion.quick, value: isOn)
    }
}

/// Four bars that breathe while music sounds. Static under Reduce Motion.
struct DSPlaybackBars: View {
    var isAnimating: Bool
    var color: Color
    var height: CGFloat = 16
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let heights: [CGFloat] = [0.9, 0.5, 1.0, 0.65]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: height)
                    .scaleEffect(y: scale(i), anchor: .bottom)
                    .animation(isAnimating && !reduceMotion
                               ? .easeInOut(duration: 0.45 + Double(i) * 0.08).repeatForever(autoreverses: true)
                               : .default, value: phase)
            }
        }
        .frame(height: height)
        .onAppear { phase = true }
        .accessibilityHidden(true)
    }

    private func scale(_ i: Int) -> CGFloat {
        guard isAnimating else { return 0.3 }
        if reduceMotion { return heights[i] }
        return phase ? heights[i] : heights[(i + 2) % 4]
    }
}

#Preview("ReaderToolbar · collapsed") {
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        VStack(spacing: DS.Space.m) {
            ReaderToolbar(number: 30, title: "Blessed Assurance", status: "Christ In Song · lyrics only")
            ReaderToolbar(number: 30, title: "Blessed Assurance", status: "Playing · verse 2 · piano",
                          isPlaying: true, hasAccompaniment: true)
        }
    }
    .dsSurface(.paper)
}

#Preview("ReaderToolbar · pad open") {
    @Previewable @State var digits = "25"
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        ReaderToolbar(number: 30, title: "Blessed Assurance", status: "Christ In Song · lyrics only",
                      openPanel: .jump) {
            HymnNumberPad(digits: $digits, title: DSPreview.title(for:), isStandalone: false,
                          onSearchInstead: {}) { _ in }
        }
    }
    .dsSurface(.black)
}
