//
//  LecternView.swift
//  Advent Praise
//
//  The Lectern is ReaderToolbar: one floating glass capsule. Panels for the
//  hymn tray, number pad, word search, library and hymnals unfold upward out
//  of the same glass (see LecternPanels.swift); More opens in its own drawer
//  (MoreDrawer.swift). On iPad the number pad is a popover and the library
//  button shows or hides the sidebar.
//

import SwiftUI

struct LecternView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPad = false

    private var toolbarPanel: ReaderToolbarPanel {
        switch model.lectern {
        case .collapsed: .none
        case .pad, .search: .jump
        case .library: .library
        case .hymn, .hymnals: .hymn
        }
    }

    var body: some View {
        ReaderToolbar(
            number: model.hymn.id,
            title: model.hymn.title,
            status: statusLine,
            isPlaying: player.isPlaying && isPlayersHymn,
            hasAccompaniment: model.hymn.hasAccompaniment && player.isAvailable,
            openPanel: toolbarPanel,
            onPlay: { playTapped() },
            onHymn: { hymnFamily ? model.closeLectern() : model.openLectern(.hymn) },
            onJump: { jumpTapped() },
            onLibrary: { libraryTapped() },
            onDismiss: { model.closeLectern() },
            onExpand: { if model.lectern == .collapsed { model.openLectern(.hymn) } }
        ) {
            panel
        }
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: model.lectern)
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: model.libraryTab)
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: showsTransport)
        .popover(isPresented: $showPad, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            // The popover is the chrome; the pad inside draws no glass of its own.
            HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                          onSearchInstead: {
                              showPad = false
                              model.openLectern(.search)
                          }, onGo: { _ in
                              showPad = false
                              model.openPreview()
                          })
                .frame(width: 360)
                .analyticsScreen(.numberPad)
                .environment(\.dsOnGlass, true)
                .dsSurface(settings.surface)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $model.showShare) {
            ShareSheet(items: [AppInfo.shareText, AppInfo.appStoreURL]).presentationDetents([.medium, .large])
                .analyticsScreen(.share)
        }
    }

    @ViewBuilder private var panel: some View {
        switch model.lectern {
        case .collapsed:
            if showsTransport { LecternPlayerStrip().transition(.opacity) }
        case .hymn: LecternHymnTray(model: model)
        case .pad:
            HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                          onSearchInstead: { model.openLectern(.search) },
                          onGo: { _ in model.openPreview() })
                .analyticsScreen(.numberPad)
        case .search: LecternSearchPanel(model: model)
        case .library: LecternLibraryPanel(model: model)
        case .hymnals: HymnalStorePicker(model: model, source: .lectern)
        }
    }

    private var hymnFamily: Bool { [.hymn, .hymnals].contains(model.lectern) }
    private var jumpFamily: Bool { [.pad, .search].contains(model.lectern) || showPad }

    /// The player has this hymn (and not the same number in another hymnal).
    private var isPlayersHymn: Bool { player.hymn == model.hymn }
    /// The transport shows from the first play until the hymn stops or finishes.
    private var showsTransport: Bool { isPlayersHymn && player.isActive && player.isAvailable }

    private func playTapped() {
        let starting = !(isPlayersHymn && player.isPlaying)
        if isPlayersHymn { player.toggle() } else { player.start(model.hymn, source: model.hymnal.name) }
        Haptics.play(.toggle(starting))
    }

    private var statusLine: String {
        // The transport above shows the verse; the row just says what's going on.
        if isPlayersHymn, player.isActive {
            return player.isPlaying ? String(localized: "Playing · piano") : String(localized: "Paused · piano")
        }
        if let progress = model.playlistProgress { return progress }
        return model.hymn.hasAccompaniment ? "\(model.hymnalInfo.name) · piano ready" : model.hymnalInfo.name
    }

    private func jumpTapped() {
        if sizeClass == .regular {
            if jumpFamily { showPad = false; model.closeLectern() } else { showPad = true }
            return
        }
        jumpFamily ? model.closeLectern() : model.openLectern(.pad)
    }

    private func libraryTapped() {
        if sizeClass == .regular {
            model.toggleSidebar = true
            return
        }
        model.lectern == .library ? model.closeLectern() : model.openLectern(.library)
    }

    /// Rejects numbers past the end of the hymnal. The pad writes through this binding.
    private var guardedDigits: Binding<String> {
        Binding(get: { model.digits }, set: { proposed in
            if proposed.count <= model.digits.count {
                model.digits = proposed
                return
            }
            guard let value = Int(proposed), value <= max(model.hymnal.info.maxNumber, 1) else {
                Haptics.play(.limit)
                return
            }
            model.digits = proposed
        })
    }

    private func title(for number: Int) -> String? { model.hymnal.hymn(number: number)?.title }

    private var recentSummaries: [DSHymnSummary] {
        model.recents.compactMap { number in
            model.hymnal.hymn(number: number).map { DSHymnSummary(number: number, title: $0.title) }
        }
    }
}

/// UIActivityViewController for "Recommend".
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // The activity type is iOS's or the share extension's identifier, never what was shared.
        vc.completionWithItemsHandler = { activity, completed, _, _ in
            let type = activity?.rawValue
            Task { @MainActor in Analytics.track(.shareFinished(completed: completed, activity: type)) }
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
