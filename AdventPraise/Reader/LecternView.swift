//
//  LecternView.swift
//  Advent Praise
//
//  The Lectern is ReaderToolbar: one floating glass capsule. Panels for the
//  hymn tray, number pad, word search and library unfold upward out of the
//  same glass (see LecternPanels.swift); More opens in its own drawer
//  (MoreDrawer.swift). Translation, theme and text live at the top, in the
//  reader menu (ReaderMenu.swift). On iPad the number pad is a popover and
//  the library button shows or hides the sidebar.
//

import SwiftUI

struct LecternView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(PurchaseStore.self) private var store
    @Environment(FreePlays.self) private var freePlays
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showPad = false
    /// What the Lectern shows of the player. The player changes its state
    /// outside any transaction (playback ends, a hymn loads), so this copy
    /// follows it inside the Lectern's animation instead of snapping.
    @State private var shownPlayer = PlayerChrome()

    private struct PlayerChrome: Equatable {
        var transport = false
        var accompaniment = false
    }

    private var toolbarPanel: ReaderToolbarPanel {
        switch model.lectern {
        case .collapsed: .none
        case .pad, .search: .jump
        case .library: .library
        case .hymn: .hymn
        }
    }

    var body: some View {
        ReaderToolbar(
            number: model.hymn.id,
            title: model.hymn.title,
            status: statusLine,
            isPlaying: player.isPlaying && isPlayersHymn,
            hasAccompaniment: shownPlayer.accompaniment,
            playIsLocked: playIsLocked,
            openPanel: toolbarPanel,
            libraryIsOn: sizeClass == .regular ? model.isSidebarVisible : nil,
            onPlay: { playTapped() },
            // The title only opens the tray: tapping it again leaves the tray as it is.
            onHymn: { if model.lectern != .hymn { model.openLectern(.hymn) } },
            onJump: { jumpTapped() },
            onLibrary: { libraryTapped() },
            onDismiss: { model.closeLectern() },
            onExpand: { if model.lectern == .collapsed { model.openLectern(.hymn) } }
        ) {
            panel
        }
        .onChange(of: playerChrome, initial: true) { old, new in
            guard old != new else { shownPlayer = new; return }
            withAnimation(DS.Motion.lecternTransition) { shownPlayer = new }
        }
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

    /// The transport sits on the row, collapsed or under the hymn tray, so
    /// opening the tray from the title never hides or reveals the player.
    /// The pad, search and library take its place while they're open.
    @ViewBuilder private var panel: some View {
        switch model.lectern {
        case .collapsed: EmptyView()
        case .hymn: LecternHymnTray(model: model)
        case .pad:
            HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                          onSearchInstead: { model.openLectern(.search) },
                          onGo: { _ in model.openPreview() })
                .analyticsScreen(.numberPad)
        case .search: LecternSearchPanel(model: model)
        case .library: LecternLibraryPanel(model: model)
        }
        if shownPlayer.transport, [.collapsed, .hymn].contains(model.lectern) {
            LecternPlayerStrip().transition(.opacity)
        }
    }

    private var jumpFamily: Bool { [.pad, .search].contains(model.lectern) || showPad }

    /// The player has this hymn (and not the same number in another hymnal).
    private var isPlayersHymn: Bool { player.hymn == model.hymn }
    /// The transport shows from the first play until the hymn stops or finishes.
    private var showsTransport: Bool { isPlayersHymn && player.isActive && player.isAvailable }
    private var playerChrome: PlayerChrome {
        PlayerChrome(transport: showsTransport, accompaniment: model.hymn.hasAccompaniment && player.isAvailable)
    }

    private func playTapped() {
        let starting = !(isPlayersHymn && player.isPlaying)
        if isPlayersHymn { player.toggle() } else { player.start(model.hymn, source: model.hymnal.name) }
        // Free plays used up: the engine opened the paywall instead, so no play haptic.
        if starting, !player.isPlaying { return }
        Haptics.play(.toggle(starting))
    }

    /// Play would start a new play (the hymn isn't up in the player).
    private var playStartsNewPlay: Bool { !(isPlayersHymn && player.isActive) }
    /// Play opens the paywall: the lock on the button.
    private var playIsLocked: Bool { playStartsNewPlay && !store.isPro && freePlays.isUsedUp }

    private var statusLine: String {
        // The transport above shows the verse; the row just says what's going on.
        if isPlayersHymn, player.isActive {
            return player.isPlaying ? String(localized: "Playing · piano") : String(localized: "Paused · piano")
        }
        if let progress = model.playlistProgress { return progress }
        guard model.hymn.hasAccompaniment else { return model.hymnalInfo.name }
        // A quiet word before the last free play (alone: the row is too short for more).
        if !store.isPro, freePlays.allowance.isLastPlay { return String(localized: "1 free play left") }
        return "\(model.hymnalInfo.name) · piano ready"
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
