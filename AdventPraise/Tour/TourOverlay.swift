//
//  TourOverlay.swift
//  Advent Praise
//
//  How the tour is drawn. Controls mark themselves with `.tourAnchor(_:)`,
//  an anchor preference; a host (`.tourHost(_:)` on the reader's root,
//  church mode's cover and More's sheet) reads the anchors of its own
//  hierarchy and, while the tour's current stage belongs to it, lays a
//  spotlight over everything: a dim with a rounded cut-out around the real
//  control, a brass ring that breathes, and a card that says what to do.
//  Taps inside the cut-out reach the control; taps outside are swallowed
//  (except on the swipe step, which needs the whole page).
//
//  Motion: the cut-out and the card move on a spring between stages; under
//  Reduce Motion they cross-fade and nothing breathes. The card is opaque
//  (the surface's raised colour), so it reads on paper and on black alike.
//  VoiceOver lands on the card's title at every stage, Next is offered on
//  every card, and Skip tour is always there.
//

import SwiftUI

// MARK: - Anchors

struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks a real control the tour can point at.
    func tourAnchor(_ target: TourTarget) -> some View {
        // Transform, not replace: a tile inside the tray keeps its own
        // anchor beside the tray's.
        transformAnchorPreference(key: TourAnchorKey.self, value: .bounds) { anchors, anchor in
            anchors[target] = anchor
        }
    }

    /// Draws the tour over this hierarchy while its stage belongs to `area`.
    func tourHost(_ area: TourArea) -> some View {
        overlayPreferenceValue(TourAnchorKey.self) { anchors in
            TourOverlay(area: area, anchors: anchors)
        }
    }
}

// MARK: - Overlay

private struct TourOverlay: View {
    let area: TourArea
    let anchors: [TourTarget: Anchor<CGRect>]
    @Environment(TourModel.self) private var tour
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let stage = tour.stage, stage.area == area, !stage.isHidden {
            GeometryReader { proxy in
                let cutout = cutout(for: stage, in: proxy)
                Spotlight(stage: stage, cutout: cutout, size: proxy.size, safeArea: proxy.safeAreaInsets)
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(DS.Motion.adaptive(.spring(duration: 0.5, bounce: 0.18), reduceMotion: reduceMotion),
                       value: tour.cardID)
        }
    }

    /// The frame around the stage's controls, a little roomier than they are.
    private func cutout(for stage: TourStage, in proxy: GeometryProxy) -> CGRect? {
        let rects = stage.targets.compactMap { anchors[$0] }.map { proxy[$0] }
        guard var union = rects.first else { return nil }
        for rect in rects.dropFirst() { union = union.union(rect) }
        guard union.width > 1, union.height > 1 else { return nil }
        return union.insetBy(dx: -DS.Space.s, dy: -DS.Space.s)
    }
}

/// The dim, the ring and the card for one stage.
private struct Spotlight: View {
    let stage: TourStage
    let cutout: CGRect?
    let size: CGSize
    let safeArea: EdgeInsets

    @Environment(TourModel.self) private var tour
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardSize = CGSize(width: 320, height: 200)

    private var radius: CGFloat { DS.Radius.card }
    private var motion: Animation { DS.Motion.adaptive(.spring(duration: 0.5, bounce: 0.18), reduceMotion: reduceMotion) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Dim(cutout: cutout, radius: radius, opacity: surface.isDark ? 0.66 : 0.52)
                .allowsHitTesting(false)
            if stage.blocksTouches { TouchBlockers(cutout: cutout, size: size) }
            if let cutout {
                SpotlightRing(radius: radius)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .allowsHitTesting(false)
            }
            TourCard(stage: stage)
                .frame(width: cardWidth)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
                .position(cardCenter)
                .id(tour.cardID)
                .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .opacity))
        }
        .animation(motion, value: cutout)
        .animation(motion, value: cardSize)
        .accessibilityElement(children: .contain)
    }

    private var margin: CGFloat { DS.Space.l }
    private var cardWidth: CGFloat { min(size.width - margin * 2, 420) }

    /// Below the control when it sits in the upper half, above it otherwise;
    /// centred on it where the width allows, and kept inside the safe area.
    private var cardCenter: CGPoint {
        let half = cardSize.height / 2
        let top = max(safeArea.top, DS.Space.l) + DS.Space.s + half
        let bottom = size.height - max(safeArea.bottom, DS.Space.l) - DS.Space.s - half
        let x: CGFloat
        var y: CGFloat
        if let cutout {
            let gap = DS.Space.l
            let below = cutout.midY < size.height * 0.5
            y = below ? cutout.maxY + gap + half : cutout.minY - gap - half
            x = min(max(cutout.midX, cardWidth / 2 + margin), size.width - cardWidth / 2 - margin)
        } else {
            // A card alone: a little above centre, clear of the Lectern.
            y = size.height * 0.42
            x = size.width / 2
        }
        y = min(max(y, top), max(top, bottom))
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Pieces

/// The dim with a rounded hole. Drawn, never touched (`TouchBlockers` does that).
private struct Dim: View {
    let cutout: CGRect?
    let radius: CGFloat
    let opacity: Double

    var body: some View {
        Color.black.opacity(opacity)
            .mask {
                Rectangle()
                    .overlay {
                        if let cutout {
                            RoundedRectangle.ds(radius)
                                .frame(width: cutout.width, height: cutout.height)
                                .position(x: cutout.midX, y: cutout.midY)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()
            }
            .accessibilityHidden(true)
    }
}

/// Four clear panes around the hole that swallow taps, so only the lit
/// control can be used. Without a hole, one pane over everything.
private struct TouchBlockers: View {
    let cutout: CGRect?
    let size: CGSize

    var body: some View {
        if let cutout {
            pane(CGRect(x: 0, y: 0, width: size.width, height: max(cutout.minY, 0)))
            pane(CGRect(x: 0, y: cutout.maxY, width: size.width, height: max(size.height - cutout.maxY, 0)))
            pane(CGRect(x: 0, y: cutout.minY, width: max(cutout.minX, 0), height: cutout.height))
            pane(CGRect(x: cutout.maxX, y: cutout.minY, width: max(size.width - cutout.maxX, 0), height: cutout.height))
        } else {
            pane(CGRect(origin: .zero, size: size))
        }
    }

    private func pane(_ rect: CGRect) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .onTapGesture {}
            .accessibilityHidden(true)
    }
}

/// A brass ring round the lit control that breathes gently.
private struct SpotlightRing: View {
    let radius: CGFloat
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        RoundedRectangle.ds(radius)
            .strokeBorder(surface.brass, lineWidth: 2.5)
            .shadow(color: surface.brass.opacity(0.55), radius: breathing ? 14 : 6)
            .scaleEffect(breathing ? 1.025 : 1)
            .opacity(breathing ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: breathing)
            .onAppear { if !reduceMotion { breathing = true } }
            .accessibilityHidden(true)
    }
}

/// The card: the step counter, a title, a line or two, Skip tour and,
/// where the stage explains rather than asks, Next.
private struct TourCard: View {
    let stage: TourStage

    @Environment(TourModel.self) private var tour
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AccessibilityFocusState private var focusOnTitle: Bool

    private var isLast: Bool { tour.phase == .finale }
    private var asksForATap: Bool { !stage.showsNext && stage.target != nil }
    /// VoiceOver always has a way on: the control it is asked to find may be hard to reach.
    private var showsNext: Bool { stage.showsNext || voiceOver }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    // A constant value under Reduce Motion: the symbol never bounces.
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? "" : tour.cardID)
                    .accessibilityHidden(true)
                Text(counter).dsEyebrow(tracking: 1.2)
                Spacer(minLength: DS.Space.s)
                Button("Skip tour") { tour.skip() }
                    .font(DS.Typeface.caption.weight(.semibold))
                    .foregroundStyle(surface.secondary)
                    .frame(minHeight: 32)
                    .accessibilityHint("Ends the tour. You can replay it from More.")
                    .accessibilityIdentifier("tour.skip")
            }
            .foregroundStyle(surface.brass)

            Text(stage.title)
                .font(DS.Typeface.panelTitle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusOnTitle)
            Text(stage.body)
                .font(DS.Typeface.detail)
                .foregroundStyle(surface.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: DS.Space.m) {
                if asksForATap {
                    // A symbol effect, not an offset: a repeating layout
                    // animation inside a card that is itself moving would
                    // carry the label off with it.
                    Label {
                        Text("Tap the highlighted control")
                    } icon: {
                        Image(systemName: "hand.tap.fill")
                            .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                    }
                    .font(DS.Typeface.caption.weight(.semibold))
                    .foregroundStyle(surface.tint)
                }
                Spacer(minLength: 0)
                if showsNext {
                    GlassButton(title: isLast ? "Done" : "Next", systemImage: isLast ? "checkmark" : "arrow.right") {
                        tour.advance()
                    }
                    .accessibilityIdentifier("tour.next")
                }
            }
            .padding(.top, DS.Space.xxs)
        }
        .padding(DS.Space.panel + 2)
        .background(RoundedRectangle.ds(DS.Radius.card).fill(surface.elevated)
            .shadow(color: .black.opacity(surface.isDark ? 0.5 : 0.18), radius: 18, y: 8))
        .overlay(RoundedRectangle.ds(DS.Radius.card)
            .strokeBorder(surface.brass.opacity(surface.isDark ? 0.35 : 0.28)))
        .foregroundStyle(surface.foreground)
        .environment(\.dsOnGlass, false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(counter))
        .accessibilityIdentifier("tour.card")
        .onAppear { focusOnTitle = true }
    }

    private var counter: LocalizedStringKey {
        if let step = tour.step { return "Step \(step.rawValue) of \(TourStep.allCases.count)" }
        return "Tour complete"
    }
}

// MARK: - Previews

#Preview("Tour card · paper") {
    let tour = TourModel()
    return ZStack {
        DSPreviewBackdrop()
        Color.black.opacity(0.5)
        TourCard(stage: tour.stages(for: .numberPad)[0]).padding()
    }
    .environment(tour)
    .dsSurface(.paper)
}

#Preview("Tour card · black") {
    let tour = TourModel()
    return ZStack {
        DSPreviewBackdrop()
        Color.black.opacity(0.6)
        TourCard(stage: tour.stages(for: .tray)[1]).padding()
    }
    .environment(tour)
    .dsSurface(.black)
}
