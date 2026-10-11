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
    @State private var showHymnals = false

    private var isFollowing: Bool { player.isPlaying && player.hymn?.id == model.hymn.id }
    private var blocks: [Hymn.Block] { settings.repeatChorus ? model.hymn.sungSequence : model.hymn.blocks }
    private var ownedHymnals: [DSHymnal] {
        HymnalInfo.catalogue.filter(store.isOwned).map(\.designHymnal)
    }

    var body: some View {
        @Bindable var settings = settings
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: settings.style.horizontalAlignment, spacing: DS.Space.block) {
                    header.id("top")
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case let .verse(number, lines):
                            ChapterVerseBlock(number: number, lines: lines, style: settings.style, state: verseState(number))
                        case let .chorus(lines):
                            ChorusBlock(lines: lines, label: model.hymnal.chorusLabel, style: settings.style,
                                        state: isFollowing ? .dimmed : .normal)
                        }
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.top, DS.Space.top)
                .padding(.bottom, DS.Space.l)
                .frame(maxWidth: DS.Space.readingMeasure, alignment: settings.style.frameAlignment)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion)) { model.toggleFocus() }
                }
                .accessibilityAction(named: model.isFocused ? "Show controls" : "Read full screen") { model.toggleFocus() }
                .accessibilityAction(named: "Next hymn") { model.goToNextHymn() }
                .accessibilityAction(named: "Previous hymn") { model.goToPreviousHymn() }
                .accessibilityAction(named: "Church mode") { model.showChurchMode = true }
            }
            .onChange(of: model.hymn) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
        .scrollIndicators(.hidden)
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
                    LanguagePicker(hymnals: HymnalInfo.catalogue.map(\.designHymnal),
                                   access: access(for:),
                                   unlockAllPrice: store.allHymnalsPrice,
                                   isUnlockingAll: store.purchasing == PurchaseConfig.allHymnalsProductID,
                                   ownsEverything: store.ownsEverything || PurchaseConfig.allHymnalsProductID == nil,
                                   onSelect: { selectHymnal($0); showHymnals = false },
                                   onUnlockAll: { Task { await store.purchaseAll() } },
                                   onRestore: { Task { await store.restore() } })
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
        .sheet(item: $model.mail) { request in
            MailComposeView(draft: .make(request.kind, hymnal: model.hymnal, hymn: model.hymn))
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $model.showChurchMode) {
            ChurchModeView(model: model)
        }
        .dsSurface(settings.surface)
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
        .frame(maxWidth: .infinity, alignment: settings.style.frameAlignment)
    }

    private func verseState(_ number: Int) -> DSBlockState {
        guard isFollowing else { return .normal }
        return player.currentVerse == number ? .current : .dimmed
    }

    private func access(for hymnal: DSHymnal) -> DSHymnalAccess {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return .locked(price: nil) }
        if store.purchasing == info.id { return .purchasing }
        if info.id == model.hymnal.id { return .current }
        if store.isOwned(info) { return .owned }
        return .locked(price: store.price(for: info))
    }

    private func selectHymnal(_ hymnal: DSHymnal) {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return }
        if store.isOwned(info) {
            model.switchHymnal(to: info)
        } else {
            Task { if await store.purchase(info) { model.switchHymnal(to: info) } }
        }
    }
}
