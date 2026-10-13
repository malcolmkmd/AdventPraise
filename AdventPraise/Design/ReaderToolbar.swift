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
//  Row:  [▶︎ play]  [30 Blessed Assurance / status]  [⌗ jump]  [🔖 library]
//  Play (play / pause) is hidden, not disabled, when the hymn has no
//  accompaniment file. While a hymn plays, the reader passes the transport
//  (LecternPlayerStrip) as the collapsed Lectern's panel.
//
//  The handle (and the title) open the hymn tray: what you do with the
//  hymn (church mode, Memorise, playlist, save, more). Tap or swipe up to
//  expand; tap or swipe down to collapse.
//
//  Motion: the caller changes `openPanel` inside one
//  `withAnimation(DS.Motion.lecternTransition)` (ReaderModel.setLectern), a
//  spring with no bounce. Nothing in here adds an implicit animation to a
//  container. Every part keeps its identity across states (one chevron, one
//  divider, one play slot), so it moves instead of popping. The open
//  highlight is one shape that slides between the title, jump and library
//  with matchedGeometryEffect; on iOS 26 the glass reshapes inside a
//  GlassEffectContainer. The panel slot clips, so panels rise out of the
//  row's top edge rather than sliding across it.
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
    /// Free: play opens the Pro paywall, and a small lock says so.
    var playIsLocked = false
    var openPanel: ReaderToolbarPanel = .none
    /// iPad: the sidebar stands in for the library panel. Non-nil lights the
    /// library button while it shows, and the button always calls `onLibrary`.
    var libraryIsOn: Bool? = nil
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
    @Namespace private var lectern

    private var isOpen: Bool { openPanel != .none }
    private var shape: RoundedRectangle { .ds(isOpen ? DS.Radius.panel : DS.Radius.dock) }

    var body: some View {
        VStack(spacing: 0) {
            LecternHandle(isOpen: isOpen, onToggle: isOpen ? onDismiss : expand)
                .simultaneousGesture(swipe)
            // Panels unfold from the row: they rise out of its top edge and
            // fade, while the glass grows around them in the same transaction.
            // The slot clips, so a panel sliding in or out never crosses the row.
            VStack(spacing: 0) {
                panel
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
            .frame(maxWidth: .infinity)
            .clipped()
            row
                .overlay(alignment: .top) { Divider().opacity(isOpen ? 0.6 : 0) }
        }
        .frame(maxWidth: DS.Space.lecternMaxWidth)
        .clipShape(shape)
        .modifier(LecternGlass(shape: shape))
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
            HStack(spacing: 0) {
                playButton
                HymnHandleButton(number: number, title: title, status: status, isPlaying: isPlaying,
                                 isOpen: openPanel == .hymn, selection: selection(.hymn),
                                 action: openPanel == .hymn ? onDismiss : onHymn)
            }

            ToolbarIconButton(systemImage: "circle.grid.3x3.fill", label: "Go to a hymn number or search",
                              isOn: openPanel == .jump, selection: selection(.jump),
                              action: openPanel == .jump ? onDismiss : onJump)
            let libraryOn = libraryIsOn ?? (openPanel == .library)
            // iPad: lit by the sidebar, which can show alongside an open panel,
            // so it keeps a highlight of its own instead of sharing the slide.
            ToolbarIconButton(systemImage: libraryOn ? "bookmark.fill" : "bookmark",
                              label: "Favourites and playlists", isOn: libraryOn,
                              selection: libraryIsOn == nil ? selection(.library) : selection(.library, shared: false),
                              action: openPanel == .library ? onDismiss : onLibrary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: DS.Size.lecternRow)
    }

    /// Always in the row so the title beside it slides rather than jumps when a
    /// hymn with (or without) accompaniment opens. Without one it folds to no
    /// width, fades and stops taking touches.
    private var playButton: some View {
        Button(action: onPlay) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(surface.onTint)
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background(Circle().fill(surface.tint)
                    .shadow(color: surface.tint.opacity(0.35), radius: 6, y: 3))
                .contentTransition(.symbolEffect(.replace))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(surface.onTint)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(surface.brass))
                        .offset(x: 3, y: -3)
                        .opacity(playIsLocked ? 1 : 0)
                }
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel(isPlaying ? "Pause accompaniment" : "Play accompaniment")
        .accessibilityHint(playIsLocked ? "Advent Praise Pro. Shows what Pro includes." : "")
        .scaleEffect(hasAccompaniment || reduceMotion ? 1 : 0.5)
        .opacity(hasAccompaniment ? 1 : 0)
        .frame(width: hasAccompaniment ? DS.Size.hitTarget + DS.Space.s : 0, alignment: .leading)
        .allowsHitTesting(hasAccompaniment)
        .accessibilityHidden(!hasAccompaniment)
    }

    /// The open highlight's matched-geometry group. Under Reduce Motion each
    /// button keeps its own, so the highlight fades in place instead of sliding.
    private func selection(_ panel: ReaderToolbarPanel, shared: Bool = true) -> LecternSelection {
        let id = shared && !reduceMotion ? "open" : "open.\(panel)"
        return LecternSelection(id: id, namespace: lectern)
    }
}

/// Where a button's open highlight belongs. Buttons whose `id` matches share
/// one highlight, which moves between them.
private struct LecternSelection {
    let id: String
    let namespace: Namespace.ID
}

/// The tint wash behind an open button. Inserted only while open; when another
/// button opens in the same transaction, matchedGeometryEffect morphs the one
/// wash from the old frame to the new.
private struct LecternSelectionWash: View {
    let selection: LecternSelection
    let radius: CGFloat
    let opacity: Double
    @Environment(\.dsSurface) private var surface

    var body: some View {
        RoundedRectangle.ds(radius)
            .fill(surface.tint.opacity(opacity))
            .matchedGeometryEffect(id: selection.id, in: selection.namespace)
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
/// The container renders the Lectern as one glass surface that reshapes (dock
/// radius to panel radius, row height to panel height) in the open/close
/// transaction. No glassEffectID: with a single shape there's nothing to
/// merge, and its morph moved the content's clip out of step with the layout
/// (the row's lower edge was cut off mid-transition).
private struct LecternGlass: ViewModifier {
    let shape: RoundedRectangle
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content
                    .environment(\.dsOnGlass, true)
                    .glassEffect(.regular.interactive(), in: shape)
            }
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
        .accessibilityLabel("Hymn actions")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityHint(isOpen ? "Collapses the bar. You can also swipe down on it."
                                  : "Expands the bar to church mode, Memorise, playlists, save and more. You can also swipe up on it.")
        .accessibilityAction(named: isOpen ? "Collapse" : "Expand", onToggle)
    }

    /// One glyph in every state. It turns with the Lectern; under Reduce
    /// Motion it stays upright and swaps to chevron.down instead.
    private var chevron: some View {
        Image(systemName: reduceMotion && isOpen ? "chevron.down" : "chevron.up")
            .contentTransition(.symbolEffect(.replace))
            .rotationEffect(.degrees(!reduceMotion && isOpen ? 180 : 0))
    }
}

/// The hymn number and title, which also open the hymn tray. The handle's
/// chevron above is the cue that there is more; a tint wash marks it open.
private struct HymnHandleButton: View {
    let number: Int
    let title: String
    let status: String
    let isPlaying: Bool
    let isOpen: Bool
    let selection: LecternSelection
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
                            .fixedSize()
                        Text(title).font(DS.Typeface.label).lineLimit(1)
                    }
                    HStack(spacing: DS.Space.s) {
                        Text(status).font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                            .contentTransition(.numericText())
                        // Always present, so starting playback doesn't reflow the status.
                        DSPlaybackBars(isAnimating: isPlaying, color: surface.tint, height: 12)
                            .opacity(isPlaying ? 1 : 0)
                    }
                }
                // Lines keep their height while the row's width changes.
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background { if isOpen { LecternSelectionWash(selection: selection, radius: DS.Radius.key,
                                                           opacity: DS.Fill.tintActive) } }
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
        }
        .buttonStyle(LecternRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hymn \(number), \(title)")
        .accessibilityValue(status)
        .accessibilityHint(isOpen ? "Closes the hymn's actions"
                                  : "Opens the hymn's actions: church mode, Memorise, add to playlist, save and more")
        .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
    }
}

/// Pressed state for the hymn title: a quiet fill and a slight dip with a
/// short ease-out. The open tray's tint wash is the shared selection, drawn
/// by the label.
private struct LecternRowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(RoundedRectangle.ds(DS.Radius.key)
                .fill(Color.primary.opacity(pressed ? DS.Fill.hairline : 0)))
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .animation(DS.Motion.press, value: pressed)
    }
}

private struct ToolbarIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isOn = false
    let selection: LecternSelection
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background { if isOn { LecternSelectionWash(selection: selection, radius: DS.Radius.tile,
                                                             opacity: DS.Fill.tintOn) } }
                .background(RoundedRectangle.ds(DS.Radius.tile)
                    .fill(Color.primary.opacity(isOn ? 0 : DS.Fill.inset)))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(isOn ? surface.tint : .primary)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
        // Flipping the phase (re)starts the breathing whenever playback starts.
        .onAppear { phase = isAnimating }
        .onChange(of: isAnimating) { _, animating in phase = animating }
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
