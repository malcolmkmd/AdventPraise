//
//  HymnReaderView.swift
//  Advent Praise
//
//  The lyrics of the current hymn with nothing above them, and the Lectern —
//  a single floating glass capsule at the bottom. Tapping the text enters
//  focus mode: everything fades and only the hymn remains.
//

import SwiftUI

struct HymnReaderView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// Pinch-to-zoom: the size while fingers are down; committed to settings on release.
    @State private var pinch = PinchZoom()
    /// Swiping between hymns.
    @State private var pageOffset: CGFloat = 0
    @State private var pageFaded = false
    @State private var isPaging = false
    @State private var dragAxis: Axis?
    @State private var pageWidth: CGFloat = 390
    /// The finger's horizontal travel toward a hymn that exists; drives the edge arrow.
    @State private var pageDrag: CGFloat = 0
    /// Past the threshold: letting go now changes the hymn.
    @State private var pageArmed = false
    /// Undoes any vertical scroll made before a page swipe locked its axis,
    /// so the text moves on x only.
    @State private var pageHoldY: CGFloat = 0
    @State private var pageStartY: CGFloat?
    @State private var scrollProbe = ScrollProbe()
    /// The large header collapsing into the compact one in the bar.
    @State private var morph = HeaderMorph()
    /// Tapping the compact header scrolls back to the top.
    @State private var scrollToTop = 0
    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 46

    /// The accompaniment for this hymn is playing or paused part-way.
    private var isFollowing: Bool { player.isActive && player.hymn == model.hymn }
    private var blocks: [Hymn.Block] { settings.repeatChorus ? model.hymn.sungSequence : model.hymn.blocks }
    /// The saved style, with the live pinch size while a pinch is under way.
    private var style: DSReadingStyle {
        var style = settings.style
        if let size = pinch.liveSize { style.pinchedPointSize = size }
        return style
    }

    var body: some View {
        @Bindable var settings = settings
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: style.horizontalAlignment, spacing: DS.Space.block) {
                    header
                    ForEach(readerBlocks) { item in
                        let state = followState(item)
                        let line = state == .current ? player.position?.line : nil
                        Group {
                            switch item.block {
                            case let .verse(number, lines):
                                ChapterVerseBlock(number: number, lines: lines, style: style, state: state,
                                                  currentLine: line)
                            case let .chorus(lines):
                                ChorusBlock(lines: lines, label: model.hymnal.chorusLabel, style: style,
                                            state: state, currentLine: line)
                            }
                        }
                        .id(item.id)
                        .modifier(ReaderAccessibilityActions(model: model, onNext: { page(.forward) },
                                                             onPrevious: { page(.back) }))
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                // The navigation bar (globe) already sits above the title.
                .padding(.top, DS.Space.m)
                // The top is above the padding: scrolling here leaves the
                // header fully at rest, not a few points into its collapse.
                .id("top")
                .padding(.bottom, DS.Space.l)
                .frame(maxWidth: DS.Space.readingMeasure, alignment: style.frameAlignment)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                // Double-tap resets a zoomed size. Only listening while zoomed,
                // so the single tap for focus mode isn't delayed otherwise.
                .gesture(TapGesture(count: 2).onEnded { resetZoom() },
                         including: settings.style.isDefaultSize ? .none : .all)
                .onTapGesture {
                    withAnimation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion)) { model.toggleFocus() }
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { [scrollProbe] y in
                    scrollProbe.y = y
                }
                .headerMorphContentProbe(morph)
                .offset(x: pageOffset, y: pageHoldY)
                .opacity(pageFaded ? 0 : 1 - min(abs(pageOffset) / max(pageWidth, 1), 1) * 0.5)
            }
            // A page swipe owns the drag: the hymn can't scroll under it.
            .scrollDisabled(dragAxis == .horizontal)
            .trackingHeaderMorph(morph)
            .softTopScrollEdge()
            #if DEBUG
            .debugScrollOffset()
            #endif
            .onChange(of: model.hymn) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .onChange(of: scrollToTop) { _, _ in
                withAnimation(DS.Motion.adaptive(.smooth(duration: 0.45), reduceMotion: reduceMotion)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            // Keep the verse being played in view as the accompaniment moves on.
            .onChange(of: followedBlockID) { _, id in
                guard let id, player.isPlaying else { return }
                withAnimation(DS.Motion.adaptive(DS.Motion.verse, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.2))
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: pageDrag < 0 ? .trailing : .leading) {
            if pageDrag != 0 {
                PageArrow(forward: pageDrag < 0, progress: abs(pageDrag) / pageThreshold)
                    .padding(.horizontal, DS.Space.s)
            }
        }
        // Two fingers can't scroll, so pinching and scrolling never compete.
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(pageGesture)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LecternView(model: model)
                .opacity(model.isFocused ? 0 : 1)
                .offset(y: model.isFocused ? 24 : 0)
                .allowsHitTesting(!model.isFocused)
                .accessibilityHidden(model.isFocused)
        }
        .overlay(alignment: .bottom) {
            DSPlaybackBars(isAnimating: player.isPlaying, color: settings.surface.tint)
                .opacity(model.isFocused && player.isPlaying ? 0.55 : 0)
                .padding(.bottom, 36)
        }
        .animation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion), value: model.isFocused)
        .statusBarHidden(model.isFocused)
        // The bar stays (an empty bar is clear) so focus mode doesn't shift
        // the text; only the globe goes, with the rest of the chrome.
        .toolbar {
            if !model.isFocused {
                CompactHymnHeaderItem(centered: style.centered, barWidth: pageWidth) {
                    CompactHymnHeader(morph: morph, number: model.hymn.id, title: model.hymn.title,
                                      centered: style.centered) { scrollToTop += 1 }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    TranslationGlobeButton(model: model)
                }
            }
        }
        .readerNavigationTitle(sizeClass == .regular ? model.hymn.title : "", centered: style.centered)
        .analyticsScreen(.reader)
        .navigationBarTitleDisplayMode(.inline)
        // Church mode, Mail and the Extras sheets are presented from RootView,
        // above the split view / stack switch, so a size-class change
        // (Split View, Stage Manager, rotation) doesn't dismiss them.
        .dsSurface(settings.surface)
        #if DEBUG
        .task { if let drag = DebugLaunch.pageDrag { pageDrag = drag; pageOffset = drag } }        #endif
        // Opening another hymn stops the one playing and cues the new one.
        // Playlist advance, Siri and the lock screen load theirs first, so
        // this finds it already cued and leaves it playing.
        .task(id: "\(model.hymnal.id)-\(model.hymn.id)") {
            player.cue(model.hymn, source: model.hymnal.name)
        }
    }

    private var title: some View {
        Text(model.hymn.title)
            .font(DS.Typeface.hymnTitle)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Hymn \(model.hymn.id), \(model.hymn.title)")
    }

    /// The hymn number, large: the first thing on the page.
    private var numeral: some View {
        Text(verbatim: String(model.hymn.id))
            .font(.system(size: numeralSize, weight: .regular, design: .serif))
            .monospacedDigit()
            .foregroundStyle(settings.surface.brass)
            .accessibilityHidden(true) // the title's label says "Hymn n"
    }

    private var header: some View {
        Group {
            if style.centered {
                // Centered reads as a title page: the hymnal, its number and
                // a balanced title, the other hymnals' numbers below it.
                VStack(spacing: DS.Space.xs) {
                    Text(model.hymnal.name)
                        .dsEyebrow(tracking: 1.6)
                        .foregroundStyle(settings.surface.brass)
                        .dsBalancedWrap()
                    numeral
                    title.dsBalancedWrap()
                    if !model.hymn.references.isEmpty {
                        Text(model.hymn.references.joined(separator: " · "))
                            .dsEyebrow(tracking: 1.1)
                            .foregroundStyle(settings.surface.secondary)
                            .dsBalancedWrap()
                            .padding(.top, DS.Space.xxs)
                    }
                }
                .padding(.bottom, DS.Space.xs)
            } else {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    numeral
                    title
                    let eyebrow = [model.hymnal.name] + model.hymn.references
                    Text(eyebrow.joined(separator: " · "))
                        .dsEyebrow(tracking: 1.1)
                        .foregroundStyle(settings.surface.secondary)
                        .padding(.top, DS.Space.xxs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: style.frameAlignment)
        // It collapses over its own height (plus the space above it).
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { [morph] height in
            morph.range = height + DS.Space.m
        }
        .modifier(HeaderCollapseEffect(morph: morph, centered: style.centered))
        // VoiceOver: swipe up / down on the title for the next / previous hymn.
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page(.forward)
            case .decrement: page(.back)
            @unknown default: break
            }
        }
        .accessibilityHint("Swipe up or down with one finger for the next or previous hymn.")
        .modifier(ReaderAccessibilityActions(model: model, onNext: { page(.forward) }, onPrevious: { page(.back) }))
    }

    // MARK: Pinch to zoom

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !isPaging, pageOffset != 0 || pageDrag != 0 { pageOffset = 0; pageDrag = 0; pageHoldY = 0 }
                pinch.update(magnification: value.magnification, from: settings.style.basePointSize,
                             in: settings.style.scale.pinchRange)
            }
            .onEnded { _ in
                if let size = pinch.end() { settings.style.pinch(to: size) }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    pinch.settle()
                }
            }
    }

    private func resetZoom() {
        guard !settings.style.isDefaultSize else { return }
        settings.nextSizeMethod = .reset
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { settings.style.resetSize() }
        Haptics.play(.softImpact)
    }

    // MARK: Swiping between hymns

    private enum PageDirection { case forward, back }

    /// How far to drag before letting go changes the hymn.
    private var pageThreshold: CGFloat { min(pageWidth * 0.22, 110) }

    /// Horizontal swipes only. The axis is decided on the first few points of
    /// movement, before the scroll view starts its own pan; a horizontal drag
    /// then disables scrolling and holds the text's vertical position, so it
    /// moves on x alone. Past the threshold the edge arrow fills and a haptic
    /// marks the point of no return; letting go there changes the hymn, and
    /// letting go before it springs back. Under Reduce Motion the text stays
    /// put while dragging (only the arrow responds) and the page cross-fades.
    private var pageGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !pinch.isActive, !isPaging else { return }
                if dragAxis == nil {
                    // The leading edge belongs to the system (back swipe, iPad sidebar).
                    let fromEdge = value.startLocation.x < 24
                    let dx = abs(value.translation.width), dy = abs(value.translation.height)
                    dragAxis = !fromEdge && dx > dy * 1.2 ? .horizontal : .vertical
                    pageStartY = scrollProbe.y
                    if dragAxis == .horizontal { Haptics.prepare(.thresholdCrossed) }
                }
                guard dragAxis == .horizontal else { return }
                if let pageStartY { pageHoldY = pageStartY - scrollProbe.y }
                let dx = value.translation.width
                let hasTarget = dx < 0 ? model.upcomingHymn != nil : model.precedingHymn != nil
                // Rubber band (and no arrow) at either end of the hymnal or playlist.
                if !reduceMotion { pageOffset = hasTarget ? dx : dx * 0.2 }
                pageDrag = hasTarget ? dx : 0
                let armed = hasTarget && abs(dx) >= pageThreshold
                if armed != pageArmed {
                    pageArmed = armed
                    if armed { Haptics.play(.thresholdCrossed) }
                }
            }
            .onEnded { value in
                defer { dragAxis = nil; pageStartY = nil; pageArmed = false }
                guard dragAxis == .horizontal, !isPaging else { return }
                let dx = value.translation.width
                if !pinch.isActive, pageArmed {
                    page(dx < 0 ? .forward : .back)
                } else {
                    if !pinch.isActive, abs(dx) >= pageThreshold { Haptics.play(.limit) } // nothing further that way
                    withAnimation(DS.Motion.adaptive(.spring(duration: 0.3, bounce: 0.2), reduceMotion: reduceMotion)) {
                        pageOffset = 0
                        pageDrag = 0
                        pageHoldY = 0
                    }
                }
            }
    }

    /// Slides the hymn out, swaps it, and slides the new one in from the other
    /// side. Under Reduce Motion it cross-fades instead.
    private func page(_ direction: PageDirection) {
        guard !isPaging, (direction == .forward ? model.upcomingHymn : model.precedingHymn) != nil else { return }
        isPaging = true
        // The compact header leaves with the old hymn; the new one opens at
        // rest, so it stays out until the next scroll brings it back.
        morph.isHidden = true
        let exit = direction == .forward ? -pageWidth : pageWidth
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.16)) {
            if reduceMotion { pageFaded = true; pageOffset = 0 } else { pageOffset = exit }
            pageDrag = 0
        } completion: {
            let hymn = direction == .forward ? model.goToNextHymn(source: .swipe) : model.goToPreviousHymn(source: .swipe)
            if voiceOver, let hymn {
                AccessibilityNotification.Announcement("Hymn \(hymn.id), \(hymn.title)").post()
            }
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) {
                if !reduceMotion { pageOffset = -exit }
                pageHoldY = 0 // the new hymn opens at the top
            }
            Task {
                // Let the off-screen position render before sliding in.
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(reduceMotion ? .easeIn(duration: 0.15) : .spring(duration: 0.35, bounce: 0.12)) {
                    pageOffset = 0
                    pageFaded = false
                } completion: {
                    isPaging = false
                    morph.isHidden = false
                }
            }
        }
    }

    private var readerBlocks: [ReaderBlock] { ReaderBlock.list(blocks) }

    /// While the accompaniment plays, the verse it is on is current and the
    /// rest dim. The chorus is current during the chorus part of each pass;
    /// with "chorus after every verse" on, only the copy after that verse.
    private func followState(_ item: ReaderBlock) -> DSBlockState {
        guard isFollowing, let position = player.position else { return .normal }
        switch item.block {
        case let .verse(number, _):
            return !position.isChorus && number == position.verse ? .current : .dimmed
        case .chorus:
            guard position.isChorus else { return .dimmed }
            // Shown once, or a hymn with no verses: the one chorus is current.
            guard settings.repeatChorus, position.verse != 0 else { return .current }
            return item.precedingVerse == position.verse ? .current : .dimmed
        }
    }

    private var followedBlockID: String? {
        guard isFollowing else { return nil }
        return readerBlocks.first { followState($0) == .current }?.id
    }
}

/// The reader's scroll position, read only by the page swipe. A plain class,
/// so scrolling doesn't re-render the reader on every frame.
@MainActor
private final class ScrollProbe {
    var y: CGFloat = 0
}

/// The round arrow at the edge the next hymn comes from. It grows and its
/// ring fills as the drag nears the threshold; past it the circle fills
/// solid. Reduce Motion keeps its size and position fixed (fill only).
private struct PageArrow: View {
    let forward: Bool
    /// 0 at rest, 1 at the threshold.
    let progress: CGFloat
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var armed: Bool { progress >= 1 }

    var body: some View {
        let p = min(max(progress, 0), 1)
        let size: CGFloat = reduceMotion ? 52 : 30 + 22 * p
        ZStack {
            Circle().fill(armed ? surface.tint : surface.elevated)
            Circle().strokeBorder(surface.tint.opacity(0.3), lineWidth: 2)
            Circle()
                .trim(from: 0, to: p)
                .stroke(surface.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.25)
            Image(systemName: forward ? "chevron.forward" : "chevron.backward")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(armed ? surface.onTint : surface.tint)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(surface.isDark ? 0.4 : 0.12), radius: 6, y: 2)
        .scaleEffect(armed && !reduceMotion ? 1.08 : 1)
        .opacity(min(p * 2.5, 1))
        .offset(x: reduceMotion ? 0 : (forward ? 1 : -1) * 10 * (1 - p))
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.35), value: armed)
        .accessibilityHidden(true)
    }
}

/// A lyric block with an identity that survives "chorus after every verse"
/// being toggled: the nth verse is always "v n", the nth chorus "c n".
/// (Position in the list would shift every block after a toggled chorus.)
private struct ReaderBlock: Identifiable {
    let id: String
    let block: Hymn.Block
    /// For a chorus, the number of the verse just above it (nil at the top).
    var precedingVerse: Int?

    static func list(_ blocks: [Hymn.Block]) -> [ReaderBlock] {
        var verses = 0, choruses = 0
        var lastVerse: Int?
        return blocks.map { block in
            switch block {
            case let .verse(number, _):
                verses += 1
                lastVerse = number
                return ReaderBlock(id: "v\(verses)", block: block)
            case .chorus:
                choruses += 1
                return ReaderBlock(id: "c\(choruses)", block: block, precedingVerse: lastVerse)
            }
        }
    }
}

/// The reader's VoiceOver actions, on every element in the text column
/// (the column itself isn't an element, so actions there wouldn't be found).
private struct ReaderAccessibilityActions: ViewModifier {
    let model: ReaderModel
    let onNext: () -> Void
    let onPrevious: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: model.isFocused ? "Show controls" : "Read full screen") { model.toggleFocus() }
            .accessibilityAction(named: "Next hymn", onNext)
            .accessibilityAction(named: "Previous hymn", onPrevious)
            .accessibilityAction(named: "Church mode") { model.enterChurchMode(from: .voiceover) }
    }
}
