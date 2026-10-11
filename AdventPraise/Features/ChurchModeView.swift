//
//  ChurchModeView.swift
//  Advent Praise
//
//  Worship-in-church mode: one verse or chorus at a time, large, on a
//  maximum-contrast ground. The screen stays awake.
//  Tap the right side to go forward, the left side to go back, or swipe;
//  the controls from WorshipModeControls hide after a few seconds and a tap
//  brings them back. From the controls you can jump to another hymn number,
//  switch translation (same number), and change the text size.
//

import SwiftUI

struct ChurchModeView: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// 1 at the default Dynamic Type size; grows with the system setting.
    @ScaledMetric(relativeTo: .body) private var dynamicUnit: CGFloat = 1
    @State private var index = 0
    @State private var controlsVisible = true
    @State private var hideGeneration = 0
    @State private var showNumberPad = false
    @State private var showTranslations = false
    @State private var digits = ""

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(index) ? sequence[index] : nil }
    private var isLast: Bool { index >= sequence.count - 1 }
    private var isPresenting: Bool { showNumberPad || showTranslations }

    /// Large print makes every church step bigger again.
    private static let largePrintBoost: CGFloat = 1.2
    private static let pointSizeLimits: ClosedRange<CGFloat> = 28...96

    /// The chosen step × Dynamic Type (capped like the reader) × large print, clamped.
    private var lyricSize: CGFloat {
        let scale = DS.LyricScale.worship
        let base = scale.steps[settings.worshipStep.clamped(to: ReadingSettings.worshipStepRange)]
        let print = settings.largePrint ? Self.largePrintBoost : 1
        return (base * min(dynamicUnit, scale.dynamicTypeCap) * print).clamped(to: Self.pointSizeLimits)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                lyric(in: geo.size)
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
                            let dx = value.translation.width
                            guard abs(dx) > abs(value.translation.height) else { return }
                            if dx < -50 { advance() }
                            if dx > 50 { previous() }
                            showControls()
                        }
                    )

                WorshipModeControls(
                    hymnNumber: model.hymn.id,
                    title: model.hymn.title,
                    position: position,
                    language: model.hymnalInfo.language,
                    canGoBack: index > 0,
                    canGoForward: !isLast || model.nextHymn != nil,
                    canShrinkText: settings.worshipStep > ReadingSettings.worshipStepRange.lowerBound,
                    canEnlargeText: settings.worshipStep < ReadingSettings.worshipStepRange.upperBound
                        && lyricSize < Self.pointSizeLimits.upperBound,
                    isVisible: controlsVisible,
                    showNumberPad: $showNumberPad,
                    showTranslations: $showTranslations,
                    onPrevious: previous,
                    onNext: advance,
                    onExit: { dismiss() },
                    onTextSmaller: { changeTextSize(by: -1) },
                    onTextLarger: { changeTextSize(by: 1) },
                    numberPad: { numberPad },
                    translations: { translations }
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
        // Same number in another translation: stay on the verse being sung.
        .onChange(of: model.hymnal.id) { _, _ in index = min(index, max(sequence.count - 1, 0)) }
        .onChange(of: isPresenting) { _, presenting in
            if !presenting { showControls() }
        }
        .onChange(of: voiceOver) { _, _ in showControls() }
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
                        .font(.system(size: lyricSize, weight: .semibold, design: .serif))
                        .italic(isChorus)
                        .lineSpacing(lyricSize * DS.LineSpacing.compact.leading * DS.LyricScale.worship.leadingScale)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: min(size.width - DS.Space.gutter * 2, DS.Space.readingMeasure), alignment: .leading)
                .padding(.horizontal, DS.Space.gutter)
                .padding(.top, 108)
                .padding(.bottom, 112)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(position). \(block.lines.joined(separator: " "))")
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

    // MARK: Jump to a number

    private var numberPad: some View {
        HymnNumberPad(digits: guardedDigits,
                      title: { model.hymnal.hymn(number: $0)?.title },
                      recents: recentSummaries,
                      isStandalone: false) { number in
            showNumberPad = false
            model.open(number: number)
            Haptics.rigid()
        }
        .frame(width: 340)
        .dsSurface(.black, paintsBackground: false)
        .presentationBackground(DSSurface.black.elevated)
        .onAppear { digits = "" }
    }

    /// Never accept a number past the end of the hymnal (like the Lectern pad).
    private var guardedDigits: Binding<String> {
        Binding(get: { digits }, set: { proposed in
            guard proposed.count > digits.count else { digits = proposed; return }
            guard let value = Int(proposed), value <= max(model.hymnal.info.maxNumber, 1) else {
                Haptics.rigid(); return
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

    private var translations: some View {
        let owned = HymnalInfo.catalogue.filter(store.isOwned)
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Hymn \(model.hymn.id) in…")
                .dsEyebrow()
                .foregroundStyle(DSSurface.black.secondary)
                .padding(.horizontal, DS.Space.panel)
                .padding(.top, DS.Space.panel)
            ScrollView {
                VStack(spacing: DS.Space.xxs) {
                    ForEach(owned) { info in
                        TranslationRow(info: info, number: model.hymn.id,
                                       isCurrent: info.id == model.hymnal.id) {
                            showTranslations = false
                            model.switchHymnal(to: info)
                        }
                    }
                }
                .padding(.horizontal, DS.Space.xs)
                .padding(.bottom, DS.Space.xs)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 320)
        .frame(maxHeight: 460)
        .fixedSize(horizontal: false, vertical: true)
        .dsSurface(.black, paintsBackground: false)
        // Opaque, like the rest of worship mode: glass over white lyrics washes out.
        .presentationBackground(DSSurface.black.elevated)
    }

    // MARK: Actions

    private func changeTextSize(by delta: Int) {
        if settings.stepWorshipText(by: delta) { Haptics.selection() } else { Haptics.rigid() }
        showControls()
    }

    private func showControls() {
        controlsVisible = true
        hideGeneration += 1
        let generation = hideGeneration
        Task {
            try? await Task.sleep(for: .seconds(4))
            // Stay up while a popover is open, and always for VoiceOver.
            if generation == hideGeneration, !isPresenting, !voiceOver { controlsVisible = false }
        }
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

/// One owned hymnal in the church-mode translation switcher.
private struct TranslationRow: View {
    let info: HymnalInfo
    let number: Int
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                RoundedRectangle.ds(DS.Radius.swatch).fill(info.color)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text(info.language).font(DS.Typeface.rowTitle)
                    Text(number <= info.maxNumber ? info.name : "No hymn \(number) · opens the first hymn")
                        .font(DS.Typeface.detail)
                        .foregroundStyle(DSSurface.black.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark").font(.body.weight(.bold))
                        .foregroundStyle(DS.Palette.brassOnDark)
                }
            }
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row + 8)
            .background(RoundedRectangle.ds(DS.Radius.tile)
                .fill(isCurrent ? Color.white.opacity(0.1) : .clear))
            .contentShape(RoundedRectangle.ds(DS.Radius.tile))
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel("\(info.language), \(info.name)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
