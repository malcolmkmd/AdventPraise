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
    @Environment(PurchaseStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var showHymnals = false
    /// Pinch-to-zoom: the size while fingers are down; committed to settings on release.
    @State private var pinch = PinchZoom()
    /// Swiping between hymns.
    @State private var pageOffset: CGFloat = 0
    @State private var pageFaded = false
    @State private var isPaging = false
    @State private var dragAxis: Axis?
    @State private var pageWidth: CGFloat = 390

    /// The accompaniment for this hymn is playing or paused part-way.
    private var isFollowing: Bool { player.isActive && player.hymn == model.hymn }
    private var blocks: [Hymn.Block] { settings.repeatChorus ? model.hymn.sungSequence : model.hymn.blocks }
    private var ownedHymnals: [DSHymnal] {
        HymnalInfo.catalogue.filter(store.isOwned).map(\.designHymnal)
    }
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
                    header.id("top")
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
                .padding(.top, DS.Space.top)
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
                .offset(x: pageOffset)
                .opacity(pageFaded ? 0 : 1 - min(abs(pageOffset) / max(pageWidth, 1), 1) * 0.5)
            }
            .onChange(of: model.hymn) { _, _ in proxy.scrollTo("top", anchor: .top) }
            // Keep the verse being played in view as the accompaniment moves on.
            .onChange(of: followedBlockID) { _, id in
                guard let id, player.isPlaying else { return }
                withAnimation(DS.Motion.adaptive(DS.Motion.verse, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.2))
                }
            }
        }
        .scrollIndicators(.hidden)
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
        .toolbar(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
        .toolbar {
            if sizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageMenuButton(current: model.hymnalInfo.designHymnal, owned: ownedHymnals,
                                       onSelect: selectHymnal(_:), onShowAll: { showHymnals = true })
                }
            }
        }
        .navigationTitle(sizeClass == .regular ? model.hymn.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHymnals) {
            NavigationStack {
                ScrollView {
                    HymnalStorePicker(model: model, onSelected: { showHymnals = false })
                        .padding(DS.Space.l)
                }
                .navigationTitle("Hymnals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showHymnals = false }
                    }
                }
            }
            .dsSurface(settings.surface)
        }
        .onChange(of: settings.style.scale) { _, scale in
            Analytics.track(.largePrintChanged(on: scale == .largePrint))
        }
        // Church mode, Mail and the Extras sheets are presented from RootView,
        // above the split view / stack switch, so a size-class change
        // (Split View, Stage Manager, rotation) doesn't dismiss them.
        .dsSurface(settings.surface)
        // Opening another hymn stops the one playing and cues the new one.
        // Playlist advance, Siri and the lock screen load theirs first, so
        // this finds it already cued and leaves it playing.
        .task(id: "\(model.hymnal.id)-\(model.hymn.id)") {
            player.cue(model.hymn, source: model.hymnal.name)
        }
    }

    private var header: some View {
        VStack(alignment: settings.style.horizontalAlignment, spacing: DS.Space.s) {
            Text(model.hymn.title)
                .font(DS.Typeface.hymnTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Hymn \(model.hymn.id), \(model.hymn.title)")
            let eyebrow = ["\(model.hymnal.name) \(model.hymn.id)"] + model.hymn.references
            Text(eyebrow.joined(separator: " · "))
                .dsEyebrow(tracking: 1.1)
                .foregroundStyle(settings.surface.secondary)
        }
        .frame(maxWidth: .infinity, alignment: style.frameAlignment)
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
                if !isPaging, pageOffset != 0 { pageOffset = 0 }
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
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { settings.style.resetSize() }
        Haptics.soft()
    }

    // MARK: Swiping between hymns

    private enum PageDirection { case forward, back }

    /// Horizontal swipes only. The axis is decided on the first movement, so a
    /// vertical scroll never pages and a page swipe never scrolls the hymn away.
    private var pageGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard !pinch.isActive, !isPaging else { return }
                if dragAxis == nil {
                    // The leading edge belongs to the system (back swipe, iPad sidebar).
                    let fromEdge = value.startLocation.x < 24
                    let dx = abs(value.translation.width), dy = abs(value.translation.height)
                    dragAxis = !fromEdge && dx > dy * 1.4 ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                let dx = value.translation.width
                let hasTarget = dx < 0 ? model.upcomingHymn != nil : model.precedingHymn != nil
                // Rubber band at either end of the hymnal or playlist.
                pageOffset = hasTarget ? dx : dx * 0.2
            }
            .onEnded { value in
                defer { dragAxis = nil }
                guard dragAxis == .horizontal, !isPaging else { return }
                let dx = value.translation.width
                let projected = value.predictedEndTranslation.width
                let threshold = min(pageWidth * 0.22, 110)
                let forward = dx < -threshold || projected < -pageWidth * 0.5
                let back = dx > threshold || projected > pageWidth * 0.5
                if !pinch.isActive, forward, model.upcomingHymn != nil {
                    page(.forward)
                } else if !pinch.isActive, back, model.precedingHymn != nil {
                    page(.back)
                } else {
                    if !pinch.isActive, forward || back { Haptics.rigid() } // nothing further that way
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) { pageOffset = 0 }
                }
            }
    }

    /// Slides the hymn out, swaps it, and slides the new one in from the other
    /// side. Under Reduce Motion it cross-fades instead.
    private func page(_ direction: PageDirection) {
        guard !isPaging, (direction == .forward ? model.upcomingHymn : model.precedingHymn) != nil else { return }
        isPaging = true
        let exit = direction == .forward ? -pageWidth : pageWidth
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.16)) {
            if reduceMotion { pageFaded = true; pageOffset = 0 } else { pageOffset = exit }
        } completion: {
            let hymn = direction == .forward ? model.goToNextHymn() : model.goToPreviousHymn()
            Haptics.light()
            if voiceOver, let hymn {
                AccessibilityNotification.Announcement("Hymn \(hymn.id), \(hymn.title)").post()
            }
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { if !reduceMotion { pageOffset = -exit } }
            Task {
                // Let the off-screen position render before sliding in.
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(reduceMotion ? .easeIn(duration: 0.15) : .spring(duration: 0.35, bounce: 0.12)) {
                    pageOffset = 0
                    pageFaded = false
                } completion: {
                    isPaging = false
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

    private func selectHymnal(_ hymnal: DSHymnal) { model.select(hymnal, store: store) }
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
            .accessibilityAction(named: "Church mode") { model.showChurchMode = true }
    }
}
