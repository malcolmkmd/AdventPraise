//
//  HymnReaderView.swift
//  Advent Praise
//
//  The lyrics of the current hymn with nothing above them, and the Lectern —
//  a single floating glass capsule at the bottom that morphs into the number
//  pad, word search, the library and the hymnals. Tapping the text enters
//  focus mode: everything fades and only the hymn remains.
//

import SwiftUI

struct HymnReaderView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ReadingSettings.self) private var settings
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var env: ReadingEnvironment { settings.environment }
    private var isFollowing: Bool { player.isPlaying && player.hymn?.id == model.hymn.id }
    private var blocks: [Hymn.Block] { settings.repeatChorus ? model.hymn.sungSequence : model.hymn.blocks }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header.id("top")
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case let .verse(number, lines):
                            VerseView(number: number, lines: lines,
                                      isCurrent: isFollowing && player.currentVerse == number,
                                      isDimmed: isFollowing && player.currentVerse != number)
                        case let .chorus(lines):
                            ChorusView(label: model.hymnal.chorusLabel, lines: lines, isDimmed: isFollowing)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 38)   // nothing above the text but the safe area
                .padding(.bottom, 40)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(settings.alignment)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { model.toggleFocus() } }
                .accessibilityAction(named: model.isFocused ? "Show controls" : "Read full screen") { model.toggleFocus() }
                .accessibilityAction(named: "Next hymn") { model.goToNextHymn() }
                .accessibilityAction(named: "Previous hymn") { model.goToPreviousHymn() }
                .accessibilityAction(named: "Church mode") { model.showChurchMode = true }
            }
            .onChange(of: model.hymn) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
        .scrollIndicators(.hidden)
        .background(env.background.ignoresSafeArea())
        .foregroundStyle(env.foreground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LecternView(model: model)
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .opacity(model.isFocused ? 0 : 1)
                .offset(y: model.isFocused ? 24 : 0)
                .allowsHitTesting(!model.isFocused)
                .accessibilityHidden(model.isFocused)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .overlay(alignment: .bottom) {
            // Focus mode keeps one faint signal that music is sounding.
            PlaybackBars(isAnimating: player.isPlaying, color: env.tint)
                .opacity(model.isFocused && player.isPlaying ? 0.55 : 0)
                .padding(.bottom, 36)
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: model.isFocused)
        .statusBarHidden(model.isFocused)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $model.showAppearance) {
            AppearanceSheet()
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackground(.regularMaterial)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))
        }
        .sheet(item: $model.mail) { request in
            MailComposeView(draft: .make(request.kind, hymnal: model.hymnal, hymn: model.hymn))
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $model.showChurchMode) {
            ChurchModeView(model: model)
        }
        .environment(\.colorScheme, env.colorScheme)
        .task(id: model.hymn.id) {
            guard model.hymn.hasAccompaniment else {
                if player.hymn?.id != model.hymn.id { player.stop() }
                return
            }
            try? player.load(model.hymn)
            player.onFinish = { [model] in
                if let next = model.advancePlaylist(), next.hasAccompaniment { try? player.load(next); player.play() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: settings.alignment == .center ? .center : .leading, spacing: 8) {
            Text(model.hymn.title)
                .font(settings.titleFont(scale: typeScale))
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Hymn \(model.hymn.id), \(model.hymn.title)")
            let eyebrow = ["\(model.hymnal.name) \(model.hymn.id)"] + model.hymn.references
            Text(eyebrow.joined(separator: " · "))
                .scaledFont(size: 11, weight: .semibold, relativeTo: .caption)
                .tracking(1.1).textCase(.uppercase)
                .foregroundStyle(env.secondary)
        }
        .frame(maxWidth: .infinity, alignment: settings.alignment == .center ? .center : .leading)
    }
}

// MARK: - Lyric blocks

struct VerseView: View {
    let number: Int
    let lines: [String]
    var isCurrent = false
    var isDimmed = false
    @Environment(ReadingSettings.self) private var settings
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    private var env: ReadingEnvironment { settings.environment }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(number))
                .scaledFont(size: settings.largePrint ? 22 : 15, weight: isCurrent ? .semibold : .medium, design: .serif)
                .foregroundStyle(isCurrent ? env.brass : env.secondary)
                .frame(minWidth: 26, minHeight: 26)
                .background(Circle().fill(env.brass.opacity(isCurrent ? 0.14 : 0)))
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(lines.joined(separator: "\n"))
                .font(settings.lyricFont(scale: typeScale))
                .lineSpacing(settings.lineSpacingPoints(scale: typeScale))
                .frame(maxWidth: .infinity, alignment: settings.alignment == .center ? .center : .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verse \(number). \(lines.joined(separator: " "))")
        .opacity(isDimmed ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.35), value: isCurrent)
        .animation(.easeInOut(duration: 0.35), value: isDimmed)
    }
}

struct ChorusView: View {
    var label = "Chorus"
    let lines: [String]
    var isDimmed = false
    @Environment(ReadingSettings.self) private var settings
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    private var env: ReadingEnvironment { settings.environment }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .scaledFont(size: settings.largePrint ? 15 : 11, weight: .bold, relativeTo: .caption)
                .tracking(1.5).textCase(.uppercase)
                .foregroundStyle(env.brass)
            Text(lines.joined(separator: "\n"))
                .font(settings.lyricFont(scale: typeScale).italic())
                .lineSpacing(settings.lineSpacingPoints(scale: typeScale))
                .frame(maxWidth: .infinity, alignment: settings.alignment == .center ? .center : .leading)
        }
        .padding(.leading, settings.alignment == .center ? 0 : 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(lines.joined(separator: " "))")
        .opacity(isDimmed ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.35), value: isDimmed)
    }
}

/// Four bars that breathe while playing.
struct PlaybackBars: View {
    var isAnimating: Bool
    var color: Color
    var height: CGFloat = 16
    @State private var phase = false
    private let heights: [CGFloat] = [0.9, 0.5, 1.0, 0.65]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: height)
                    .scaleEffect(y: isAnimating ? (phase ? heights[i] : heights[(i + 2) % 4]) : 0.3, anchor: .bottom)
                    .animation(isAnimating ? .easeInOut(duration: 0.45 + Double(i) * 0.08).repeatForever(autoreverses: true) : .default,
                               value: phase)
            }
        }
        .frame(height: height)
        .onAppear { phase = true }
        .accessibilityHidden(true)
    }
}
