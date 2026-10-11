//
//  ReaderToolbar.swift
//  Advent Praise 7 — Vesper design system
//
//  The Lectern: the reader's only chrome. One floating glass capsule at the
//  bottom, under the thumb. The 64 pt row is the spine and never moves;
//  panels (number pad, search, library, hymnals, more) unfold upward out of
//  it inside the same glass, then settle back.
//
//  Row:  [▶︎ play]  [30 Blessed Assurance / status]  [⌗ jump]  [🔖 library]
//  Play is hidden (not disabled) when the hymn has no accompaniment file.
//
//  iPhone: full width minus 20 pt. iPad / regular width: centred, ≤ 560 pt.
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
    @ViewBuilder var panel: Panel

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isOpen: Bool { openPanel != .none }
    private var shape: RoundedRectangle { .ds(isOpen ? DS.Radius.panel : DS.Radius.dock) }

    var body: some View {
        VStack(spacing: 0) {
            panel
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            row
                .overlay(alignment: .top) { if isOpen { Divider().opacity(0.6) } }
        }
        .frame(maxWidth: sizeClass == .regular ? DS.Space.lecternMaxWidth : .infinity)
        .clipShape(shape)
        .modifier(LecternGlass(shape: shape))
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: openPanel)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height < -40, !isOpen { onHymn() }
                if value.translation.height > 40, isOpen { onDismiss() }
            }
        )
        .accessibilityAction(.escape) { if isOpen { onDismiss() } }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, DS.Space.l)
        .padding(.bottom, DS.Space.s)
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

            Button(action: openPanel == .hymn ? onDismiss : onHymn) {
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
                .padding(.horizontal, DS.Space.s)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(RoundedRectangle.ds(DS.Radius.key)
                    .fill(surface.tint.opacity(openPanel == .hymn ? DS.Fill.tintActive : 0)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hymn \(number), \(title)")
            .accessibilityValue(status)
            .accessibilityHint(openPanel == .hymn ? "Closes hymn actions" : "Save, change hymnal, text settings, more")
            .accessibilityAddTraits(openPanel == .hymn ? .isSelected : [])

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
