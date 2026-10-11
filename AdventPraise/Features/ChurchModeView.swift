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
    @ScaledMetric(relativeTo: .largeTitle) private var lyricSize: CGFloat = 48
    @State private var index = 0
    @State private var controlsVisible = true
    @State private var hideGeneration = 0
    @State private var worshipStep = DS.LyricScale.worship.defaultStep

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(index) ? sequence[index] : nil }
    private var isLast: Bool { index >= sequence.count - 1 }
    private var style: DSReadingStyle {
        DSReadingStyle(scale: .worship, step: worshipStep, font: .serif, lineSpacing: .compact, centered: false)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                lyric(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            if !controlsVisible {
                                showControls()
                                return
                            }
                            value.location.x < geo.size.width * 0.33 ? previous() : advance()
                        }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30).onEnded { value in
                            if value.translation.width < -50 { advance() }
                            if value.translation.width > 50 { previous() }
                            showControls()
                        }
                    )

                WorshipModeControls(
                    hymnNumber: model.hymn.id,
                    title: model.hymn.title,
                    position: position,
                    canGoBack: index > 0,
                    canGoForward: !isLast || model.nextHymn != nil,
                    isVisible: controlsVisible,
                    onPrevious: previous,
                    onNext: advance,
                    onExit: { dismiss() },
                    onTextSmaller: { worshipStep = max(worshipStep - 1, 0) },
                    onTextLarger: { worshipStep = min(worshipStep + 1, DS.LyricScale.worship.steps.count - 1) }
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
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if isChorus {
                    Text(model.hymnal.chorusLabel)
                        .dsEyebrow(tracking: 2)
                        .foregroundStyle(DS.Palette.brassOnDark)
                }
                Text(block.lines.joined(separator: "\n"))
                    .font(.system(size: lyricSize, weight: .semibold, design: .serif))
                    .italic(isChorus)
                    .lineSpacing(lyricSize * DS.LineSpacing.compact.leading * DS.LyricScale.worship.leadingScale)
                    .minimumScaleFactor(0.28)
                    .frame(maxWidth: min(size.width - DS.Space.gutter * 2, DS.Space.readingMeasure),
                           maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, 108)
            .padding(.bottom, 112)
            .frame(width: size.width, height: size.height, alignment: .top)
            .id(index)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 24)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(position). \(block.lines.joined(separator: " "))")
            .accessibilityAddTraits(.updatesFrequently)
        } else {
            Text("This hymn has no text yet.")
                .font(DS.Typeface.sheetTitle)
                .italic()
                .foregroundStyle(DSSurface.black.secondary)
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
