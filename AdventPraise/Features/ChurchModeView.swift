//
//  ChurchModeView.swift
//  Advent Praise
//
//  Worship-in-church mode: one verse or chorus at a time, large, on a
//  maximum-contrast ground. The screen stays awake.
//  Tap the right side to go forward, the left side to go back, or swipe;
//  pinch to size the text, double-tap to reset it. The controls from
//  WorshipModeControls hide after a few seconds and a tap brings them back.
//  From the controls you can jump to another hymn number, switch
//  translation (same number), and change the text size. With Pro, AirPlay
//  or a cable puts the worship display on a TV or projector
//  (ExternalDisplay.swift) and this screen becomes its remote, with Next
//  hymn and Blank too. Without Pro a connected screen mirrors this one, and
//  the Go Pro banner sits under the controls (ScreenMirroring.swift).
//

import SwiftUI

struct ChurchModeView: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// 1 at the default Dynamic Type size; capped like the worship scale.
    @ScaledMetric(relativeTo: .largeTitle) private var dynamicUnit: CGFloat = 1
    @Environment(ChurchPresentation.self) private var church
    @Environment(PurchaseStore.self) private var store
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ScreenMirroring.self) private var mirroring
    @Environment(TourModel.self) private var tour
    @State private var controlsVisible = true
    /// The Go Pro banner's height while it shows (0 otherwise); the controls sit above it.
    @State private var bannerHeight: CGFloat = 0
    @State private var hideGeneration = 0
    @State private var pinch = PinchZoom()
    @State private var showNumberPad = false
    @State private var showTranslations = false
    @State private var digits = ""
    /// The controls' top bar (buttons and hymn card); the lyric starts below it.
    @State private var topBarHeight: CGFloat = 92
    /// For `church_mode_exited`.
    @State private var enteredAt = ContinuousClock.now
    @State private var versesShown = 1
    @State private var hymnsShown = 1

    /// Shared with an external screen, which shows the same block.
    private var index: Int {
        get { church.index }
        nonmutating set { church.index = newValue }
    }
    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(index) ? sequence[index] : nil }
    private var isLast: Bool { index >= sequence.count - 1 }
    private var isPresenting: Bool {
        showNumberPad || showTranslations || showActions || showAnnouncement || showImages
    }
    @State private var showActions = false
    @State private var showAnnouncement = false
    @State private var showImages = false
    private var scale: DS.LyricScale { .worship }

    /// Large print makes every church size bigger again.
    private static let largePrintBoost: CGFloat = 1.2
    private static let pointSizeLimits: ClosedRange<CGFloat> = 28...96

    private var baseSize: CGFloat { pinch.liveSize ?? settings.worshipPointSize }
    /// The chosen size × Dynamic Type (capped like the reader) × large print, clamped.
    private var lyricSize: CGFloat {
        let print = settings.largePrint ? Self.largePrintBoost : 1
        return (baseSize * min(dynamicUnit, scale.dynamicTypeCap) * print).clamped(to: Self.pointSizeLimits)
    }
    private var isDefaultSize: Bool { settings.worshipPointSize == ReadingSettings.defaultWorshipPointSize }
    /// The worship display is up on a TV or projector (Pro).
    private var isOnExternalScreen: Bool { church.isExternalScreenConnected && store.isPro }
    private var bannerInset: CGFloat { bannerHeight > 0 ? bannerHeight + DS.Space.s : 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                lyric(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    // Double-tap resets a zoomed size. Only listening while
                    // zoomed, so tapping through verses is never delayed.
                    .gesture(SpatialTapGesture(count: 2).onEnded { _ in resetZoom() },
                             including: isDefaultSize ? .none : .all)
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            guard !pinch.isActive else { return }
                            if !controlsVisible {
                                showControls()
                                return
                            }
                            value.location.x < geo.size.width * 0.33 ? previous() : advance()
                        }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30).onEnded { value in
                            guard !pinch.isActive else { return }
                            let dx = value.translation.width
                            // Vertical drags scroll a long verse.
                            guard abs(dx) > abs(value.translation.height) else { return }
                            if dx < -50 { advance() }
                            if dx > 50 { previous() }
                            showControls()
                        }
                    )
                    .simultaneousGesture(zoomGesture)
                    // The phone is the remote: dimmed while the big screen is blank.
                    .opacity(church.isBlanked || church.isShowingSpecial ? 0.35 : 1)

                WorshipModeControls(
                    hymnNumber: model.hymn.id,
                    title: model.hymn.title,
                    position: tvStatus ?? position,
                    step: index,
                    stepCount: sequence.count,
                    language: model.hymnalInfo.language,
                    canGoBack: index > 0,
                    canGoForward: !isLast || model.upcomingHymn != nil,
                    canShrinkText: settings.worshipStepTarget(by: -1) != nil,
                    canEnlargeText: settings.worshipStepTarget(by: 1) != nil
                        && lyricSize < Self.pointSizeLimits.upperBound,
                    isVisible: controlsVisible,
                    airPlay: store.isPro ? .available : .locked,
                    onAirPlayLocked: { model.paywall = .airPlay },
                    isOnExternalScreen: isOnExternalScreen,
                    remote: isOnExternalScreen
                        ? WorshipRemote(isBlanked: church.isBlanked, hasNextHymn: model.upcomingHymn != nil,
                                        onToggleBlank: toggleBlank, onNextHymn: nextHymnFromRemote)
                        : nil,
                    showNumberPad: $showNumberPad,
                    showTranslations: $showTranslations,
                    showActions: $showActions,
                    onPrevious: previous,
                    onNext: advance,
                    onExit: { dismiss() },
                    onTextSmaller: { changeTextSize(by: -1) },
                    onTextLarger: { changeTextSize(by: 1) },
                    onTopBarHeight: { topBarHeight = $0 },
                    actions: WorshipActions(
                        isBlanked: church.isBlanked, hasAnnouncement: church.announcement != nil,
                        hasImage: church.image != nil, isLocked: !store.isPro,
                        onToggleBlank: { presenterAction { toggleBlank() } },
                        onAnnouncement: { presenterAction { showAnnouncement = true } },
                        onImage: { presenterAction { showImages = true } },
                        onClear: { church.clearSpecial(); Haptics.play(.toggleOff); showControls() }),
                    numberPad: { numberPad },
                    translations: { translations }
                )
                .padding(.bottom, bannerInset)

                // Mirrored without Pro: under the controls, and up even when they hide.
                MirroringBannerSlot(model: model, inChurchMode: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bannerHeight = $0 }
                    .padding(.horizontal, DS.Space.l)
                    .padding(.bottom, DS.Space.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            // The tour's church-mode stages: the root's overlay is under this cover.
            .tourHost(.church)
        }
        .onChange(of: showActions) { _, open in tour.observe(.churchActionsOpen(open)) }
        // The root's paywall is under this cover, so church mode shows its own,
        // inside the black surface.
        .proPaywall(feature: $model.paywall, context: .churchMode) { feature in
            if feature == .player { player.start(model.hymn, source: model.hymnal.name) }
        }
        .dsSurface(.black)
        .environment(\.dsWorshipMode, true)
        .dsKeepsScreenAwake()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            index = 0
            church.isActive = true
            church.isBlanked = false
            showControls()
            enteredAt = .now
            Analytics.track(.churchModeEntered(source: model.churchModeSource))
            Analytics.screen(.churchMode)
            if church.isExternalScreenConnected { trackCast(true) }
            // No paywall pops up for a screen connected without Pro: it would
            // be mirrored over the words. The Go Pro banner offers it instead.
            #if DEBUG
            if sequence.indices.contains(DebugLaunch.churchBlock) { index = DebugLaunch.churchBlock }
            if DebugLaunch.showsChurchPad { showNumberPad = true }
            if DebugLaunch.showsChurchTranslations { showTranslations = true }
            switch UserDefaults.standard.string(forKey: "uiDebugChurchSheet") {
            case "announcement": showAnnouncement = true
            case "image": showImages = true
            case "actions": showActions = true
            default: break
            }
            #endif
        }
        .onDisappear {
            AirPlayLyricsCaster.shared.stop()
            ChurchLiveActivity.shared.stop()
            church.endRequested = false
            church.isActive = false
            church.isBlanked = false
            let seconds = Int((ContinuousClock.now - enteredAt).components.seconds)
            Analytics.track(.churchModeExited(seconds: seconds, versesShown: versesShown, hymnsShown: hymnsShown))
        }
        .onChange(of: church.isExternalScreenConnected) { _, connected in trackCast(connected) }
        // The words as AirPlay video, for a TV picked from the AirPlay button (Pro).
        .background { if store.isPro { AirPlayLyricsLayer().ignoresSafeArea() } }
        .onChange(of: store.isPro, initial: true) { _, isPro in
            if isPro {
                AirPlayLyricsCaster.shared.start()
                ChurchLiveActivity.shared.start()
            } else {
                AirPlayLyricsCaster.shared.stop()
                ChurchLiveActivity.shared.stop()
            }
        }
        .sheet(isPresented: $showAnnouncement) { ChurchAnnouncementSheet(church: church) }
        .sheet(isPresented: $showImages) { ChurchImageSheet(church: church) }
        // The Live Activity's End button.
        .onChange(of: church.endRequested) { _, requested in
            guard requested else { return }
            church.endRequested = false
            dismiss()
        }
        .onChange(of: model.hymn.id) { _, _ in
            index = 0
            church.isBlanked = false
            versesShown += 1
            hymnsShown += 1
        }
        // Same number in another translation: stay on the verse being sung.
        .onChange(of: model.hymnal.id) { _, _ in index = min(index, max(sequence.count - 1, 0)) }
        .onChange(of: isPresenting) { _, presenting in
            if !presenting { showControls() }
        }
        .onChange(of: voiceOver) { _, _ in showControls() }
        // Each showControls() bumps the generation, which cancels the previous
        // countdown and starts a fresh one. The controls stay up while a
        // popover is open, always for VoiceOver, and while the tour points at them.
        .task(id: "\(hideGeneration)|\(tour.isActive)") {
            guard controlsVisible, !isPresenting, !voiceOver, !tour.isActive else { return }
            #if DEBUG
            if DebugLaunch.keepsChurchControls { return }
            #endif
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled, !isPresenting, !voiceOver { controlsVisible = false }
        }
        .accessibilityAction(named: "Next verse") { advance() }
        .accessibilityAction(named: "Previous verse") { previous() }
        .accessibilityAction(named: "Jump to hymn number") { showControls(); showNumberPad = true }
        .accessibilityAction(named: "Change translation") { showControls(); showTranslations = true }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var position: String {
        switch block {
        case let .verse(number, _)?: "Verse \(number) of \(model.hymn.verseCount)"
        case .chorus?: model.hymnal.chorusLabel
        case nil: ""
        }
    }

    // MARK: Lyric

    @ViewBuilder
    private func lyric(in size: CGSize) -> some View {
        if let block {
            let isChorus: Bool = { if case .chorus = block { return true } else { return false } }()
            // The chorus gets the reader's chorus face, bold italic, and its brass rule.
            let chorusFont = Font.custom(DS.ReadingFont.serif.chorusFace,
                                         fixedSize: lyricSize * DS.ReadingFont.serif.chorusSizeRatio)
            // The chosen size is honoured exactly; a verse too long for the
            // screen scrolls instead of being shrunk back down.
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    if isChorus {
                        Text(model.hymnal.chorusLabel)
                            .dsEyebrow(tracking: 2)
                            .foregroundStyle(DS.Palette.brassOnDark)
                    }
                    Text(block.lines.joined(separator: "\n"))
                        .font(isChorus ? chorusFont : .system(size: lyricSize, weight: .semibold, design: .serif))
                        .lineSpacing(lyricSize * DS.LineSpacing.compact.leading * scale.leadingScale)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, isChorus ? DS.Space.l : 0)
                .background(alignment: .leading) {
                    if isChorus { ChorusRule(color: DS.Palette.brassOnDark).frame(width: 3) }
                }
                .frame(maxWidth: min(size.width - DS.Space.gutter * 2, DS.Space.readingMeasure), alignment: .leading)
                .padding(.horizontal, DS.Space.gutter)
                // Below the top bar (plus the controls' own inset), so the
                // first line is never under the hymn card.
                .padding(.top, topBarHeight + DS.Space.s + DS.Space.l)
                .padding(.bottom, 112 + bannerInset)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(isChorus ? String(localized: "Chorus") : position). \(block.lines.joined(separator: " "))")
                .accessibilityAddTraits(.updatesFrequently)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id("\(model.hymnal.id)-\(model.hymn.id)-\(index)")
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 24)))
        } else {
            Text("This hymn has no text yet.")
                .font(DS.Typeface.sheetTitle)
                .italic()
                .foregroundStyle(DSSurface.black.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Text size

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinch.update(magnification: value.magnification, from: settings.worshipPointSize,
                             in: scale.pinchRange)
            }
            .onEnded { _ in
                if let size = pinch.end() {
                    settings.worshipPointSize = size
                    trackTextSize(.pinch)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    pinch.settle()
                }
            }
    }

    private func resetZoom() {
        guard !isDefaultSize else { return }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            settings.worshipPointSize = ReadingSettings.defaultWorshipPointSize
        }
        Haptics.play(.softImpact)
        trackTextSize(.reset)
        showControls()
    }

    /// The buttons move to the next worship step from wherever a pinch left it.
    private func changeTextSize(by delta: Int) {
        let changed = withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            settings.stepWorshipText(by: delta)
        }
        Haptics.play(changed ? .selection : .limit)
        if changed { trackTextSize(.buttons) }
        showControls()
    }

    private func trackTextSize(_ method: TextSizeMethod) {
        Analytics.track(.textSizeChanged(context: .churchMode, method: method, pointSize: Int(settings.worshipPointSize)))
    }

    /// A TV or projector connected or gone while church mode is open. Without
    /// Pro it mirrors the phone rather than showing the worship display.
    private func trackCast(_ connected: Bool) {
        Analytics.track(.churchModeCastChanged(isConnected: connected, showsHymn: connected && store.isPro))
    }

    // MARK: Jump to a number

    /// With a playlist or service plan running, its hymns sit above the keys:
    /// the next one highlighted, any one a tap away.
    private var numberPad: some View {
        VStack(spacing: 0) {
            if let queue = model.runningQueue {
                ChurchQueueList(queue: queue, title: { model.hymnal.hymn(number: $0)?.title }) { index in
                    showNumberPad = false
                    model.jumpInQueue(to: index)
                }
                .padding([.horizontal, .top], DS.Space.panel)
            }
            HymnNumberPad(digits: guardedDigits,
                          title: { model.hymnal.hymn(number: $0)?.title },
                          recents: model.runningQueue == nil ? recentSummaries : [],
                          isStandalone: false) { number in
                showNumberPad = false
                // A number on the running list jumps within it; any other leaves it.
                if let index = model.runningQueue?.index(of: number) {
                    model.jumpInQueue(to: index)
                } else {
                    model.open(number: number, source: .numpad)
                }
            }
        }
        .frame(width: 340)
        .analyticsScreen(.numberPad)
        .dsSurface(.black, paintsBackground: false)
        .presentationBackground(DSSurface.black.elevated)
        .onAppear { digits = "" }
    }

    /// Never accept a number past the end of the hymnal (like the Lectern pad).
    private var guardedDigits: Binding<String> {
        Binding(get: { digits }, set: { proposed in
            guard proposed.count > digits.count else { digits = proposed; return }
            guard let value = Int(proposed), value <= max(model.hymnal.info.maxNumber, 1) else {
                Haptics.play(.limit); return
            }
            digits = proposed
        })
    }

    private var recentSummaries: [DSHymnSummary] {
        model.recents.compactMap { number in
            model.hymnal.hymn(number: number).map { DSHymnSummary(number: number, title: $0.title) }
        }
    }

    // MARK: Translation

    /// The same switcher as the reader's globe, on the black ground.
    private var translations: some View {
        TranslationSwitcher(model: model, source: .churchMode, onSwitched: { showTranslations = false })
            .dsSurface(.black, paintsBackground: false)
        // Opaque, like the rest of worship mode: glass over white lyrics washes out.
        .presentationBackground(DSSurface.black.elevated)
    }

    // MARK: Actions

    private func showControls() {
        controlsVisible = true
        hideGeneration += 1
    }

    private func advance() {
        church.isBlanked = false
        if isLast { nextHymn() } else { next() }
        showControls()
    }

    /// What the TV shows instead of the words, for the hymn card.
    private var tvStatus: String? {
        if church.image != nil { return String(localized: "Image on TV") }
        if church.announcement != nil { return String(localized: "Announcement on TV") }
        if church.isBlanked { return String(localized: "TV blank") }
        return nil
    }

    /// Presenter actions are Pro, like presenting itself.
    private func presenterAction(_ action: () -> Void) {
        guard store.isPro else { model.paywall = .airPlay; return }
        action()
    }

    // MARK: Remote (the worship display is up)

    /// Blank shows only the display's ground; turning a verse brings the words back.
    private func toggleBlank() {
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { church.isBlanked.toggle() }
        Haptics.play(church.isBlanked ? .toggleOn : .toggleOff)
        showControls()
    }

    private func nextHymnFromRemote() {
        church.isBlanked = false
        guard model.goToNextHymn(source: .churchMode) != nil else { Haptics.play(.limit); return }
        index = 0
        showControls()
    }

    private func next() {
        guard !isLast else { return }
        withAnimation(.easeOut(duration: 0.22)) { index += 1 }
        versesShown += 1
        Haptics.play(.lightImpact)
    }

    private func previous() {
        guard index > 0 else { Haptics.play(.limit); return }   // first verse of the hymn
        church.isBlanked = false
        withAnimation(.easeOut(duration: 0.22)) { index -= 1 }
        Haptics.play(.lightImpact)
        showControls()
    }

    private func nextHymn() {
        if model.goToNextHymn(source: .churchMode) != nil {
            index = 0
        } else {
            dismiss()
        }
    }
}

