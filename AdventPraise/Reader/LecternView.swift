//
//  LecternView.swift
//  Advent Praise
//
//  The Lectern is ReaderToolbar: one floating glass capsule. Panels for the
//  hymn tray, number pad, word search, library and hymnals unfold upward out
//  of the same glass (see LecternPanels.swift); More opens in its own drawer
//  (MoreDrawer.swift). On iPad the number pad is a popover and the library
//  button opens the sidebar.
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
            isPlaying: player.isPlaying && player.hymn?.id == model.hymn.id,
            hasAccompaniment: model.hymn.hasAccompaniment,
            openPanel: toolbarPanel,
            onPlay: { player.toggle(); Haptics.light() },
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
                .environment(\.dsOnGlass, true)
                .dsSurface(settings.surface)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $model.showShare) {
            ShareSheet(items: [AppInfo.shareText, AppInfo.appStoreURL]).presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var panel: some View {
        switch model.lectern {
        case .collapsed: EmptyView()
        case .hymn: LecternHymnTray(model: model)
        case .pad:
            HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                          onSearchInstead: { model.openLectern(.search) },
                          onGo: { _ in model.openPreview() })
        case .search: LecternSearchPanel(model: model)
        case .library: LecternLibraryPanel(model: model)
        case .hymnals: HymnalStorePicker(model: model)
        }
    }

    private var hymnFamily: Bool { [.hymn, .hymnals].contains(model.lectern) }
    private var jumpFamily: Bool { [.pad, .search].contains(model.lectern) || showPad }

    private var statusLine: String {
        if player.isPlaying, player.hymn?.id == model.hymn.id {
            return player.currentVerse.map { "Playing · verse \($0) · piano" } ?? "Playing · intro · piano"
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
            model.revealSidebar = true
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
                Haptics.rigid()
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
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
