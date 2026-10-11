//
//  ChurchModeView.swift
//  Advent Praise
//
//  Worship-in-church mode: one verse or chorus at a time, as large as the
//  screen allows, on a maximum-contrast ground. The screen stays awake.
//  Tap the right side to go forward, the left side to go back; the controls
//  from WorshipModeControls sit in the corners and hide after a few seconds.
//

import SwiftUI

struct ChurchModeView: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ReadingSettings.self) private var settings
    /// 1 at the default Dynamic Type size; capped like the worship scale.
    @ScaledMetric(relativeTo: .largeTitle) private var dynamicUnit: CGFloat = 1
    @State private var index = 0
    @State private var controlsVisible = true
    @State private var hideGeneration = 0
    @State private var pinch = PinchZoom()

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(index) ? sequence[index] : nil }
    private var isLast: Bool { index >= sequence.count - 1 }
    private var scale: DS.LyricScale { .worship }
    private var baseSize: CGFloat { pinch.liveSize ?? settings.worshipPointSize }
    private var lyricSize: CGFloat { baseSize * min(dynamicUnit, scale.dynamicTypeCap) }
    private var isDefaultSize: Bool { settings.worshipPointSize == ReadingSettings.defaultWorshipPointSize }

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
                            if value.translation.width < -50 { advance() }
                            if value.translation.width > 50 { previous() }
                            showControls()
                        }
                    )
                    .simultaneousGesture(zoomGesture)

                WorshipModeControls(
                    hymnNumber: model.hymn.id,
                    title: model.hymn.title,
                    position: position,
                    canGoBack: index > 0,
                    canGoForward: !isLast || model.upcomingHymn != nil,
                    isVisible: controlsVisible,
                    onPrevious: previous,
                    onNext: advance,
                    onExit: { dismiss() },
                    onTextSmaller: { stepSize(-1) },
                    onTextLarger: { stepSize(1) }
                )
            }
        }
        .dsSurface(.black)
        .environment(\.dsWorshipMode, true)
        .dsKeepsScreenAwake()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            index = 0
            showControls()
            Analytics.track(.churchModeStarted(hymnal: model.hymnal.id))
        }
        .onChange(of: model.hymn.id) { _, _ in index = 0 }
        // Each showControls() bumps the generation, which cancels the previous
        // countdown and starts a fresh one.
        .task(id: hideGeneration) {
            guard controlsVisible else { return }
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { controlsVisible = false }
        }
        .accessibilityAction(named: "Next verse") { advance() }
        .accessibilityAction(named: "Previous verse") { previous() }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var position: String {
        switch block {
        case let .verse(number, _)?: "Verse \(number) of \(model.hymn.verseCount)"
        case .chorus?: model.hymnal.chorusLabel
        case nil: ""
        }
    }

    @ViewBuilder
    private func lyric(in size: CGSize) -> some View {
        if let block {
            let isChorus: Bool = { if case .chorus = block { return true } else { return false } }()
            // The chorus gets the reader's chorus face, bold italic, and its brass rule.
            let chorusFont = Font.custom(DS.ReadingFont.serif.chorusFace,
                                         fixedSize: lyricSize * DS.ReadingFont.serif.chorusSizeRatio)
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if isChorus {
                    Text(model.hymnal.chorusLabel)
                        .dsEyebrow(tracking: 2)
                        .foregroundStyle(DS.Palette.brassOnDark)
                }
                Text(block.lines.joined(separator: "\n"))
                    .font(isChorus ? chorusFont : .system(size: lyricSize, weight: .semibold, design: .serif))
                    .lineSpacing(lyricSize * DS.LineSpacing.compact.leading * scale.leadingScale)
                    .minimumScaleFactor(0.28)
            }
            .padding(.leading, isChorus ? DS.Space.l : 0)
            .background(alignment: .leading) {
                if isChorus { ChorusRule(color: DS.Palette.brassOnDark).frame(width: 3) }
            }
            .frame(maxWidth: min(size.width - DS.Space.gutter * 2, DS.Space.readingMeasure),
                   maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, 108)
            .padding(.bottom, 112)
            .frame(width: size.width, height: size.height, alignment: .top)
            .id(index)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 24)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isChorus ? String(localized: "Chorus") : position). \(block.lines.joined(separator: " "))")
            .accessibilityAddTraits(.updatesFrequently)
        } else {
            Text("This hymn has no text yet.")
                .font(DS.Typeface.sheetTitle)
                .italic()
                .foregroundStyle(DSSurface.black.secondary)
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinch.update(magnification: value.magnification, from: settings.worshipPointSize,
                             in: scale.pinchRange)
            }
            .onEnded { _ in
                if let size = pinch.end() { settings.worshipPointSize = size }
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
        Haptics.soft()
        showControls()
    }

    /// The text size buttons move to the next worship step from wherever a pinch left it.
    private func stepSize(_ delta: Int) {
        let current = settings.worshipPointSize
        let steps = scale.steps
        let target = delta > 0 ? steps.first { $0 > current + 0.5 } : steps.last { $0 < current - 0.5 }
        guard let target else { Haptics.light(); return }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            settings.worshipPointSize = target
        }
    }

    private func showControls() {
        controlsVisible = true
        hideGeneration += 1
    }

    private func advance() {
        if isLast { nextHymn() } else { next() }
        showControls()
    }

    private func next() {
        guard !isLast else { return }
        withAnimation(.easeOut(duration: 0.22)) { index += 1 }
        Haptics.light()
    }

    private func previous() {
        guard index > 0 else { return }
        withAnimation(.easeOut(duration: 0.22)) { index -= 1 }
        Haptics.light()
        showControls()
    }

    private func nextHymn() {
        if model.goToNextHymn() != nil {
            index = 0
            Haptics.rigid()
        } else {
            dismiss()
        }
    }
}
