//
//  TourRootHost.swift
//  Advent Praise
//
//  Attaches the tour to the reader's root: draws its overlay there, tells
//  the model what the reader did (the tray, a new hymn, the globe, Play,
//  Memorise, church mode, More), keeps its context current (a piano on this
//  hymn, the iPad sidebar) and carries out the few things a Next needs
//  done. A tour asked for while church mode or More was up starts once
//  the screen is clear. Church mode and More host their own overlays
//  (`.tourHost(.church)`, `.tourHost(.more)`) and report their own popovers.
//

import SwiftUI

extension View {
    /// The tour on the reader's root. Attach once, in RootView, above the
    /// reader menu and below the covers and sheets.
    func tourRoot(model: ReaderModel) -> some View {
        modifier(TourRootHost(model: model))
    }
}

private struct TourRootHost: ViewModifier {
    @Bindable var model: ReaderModel
    @Environment(TourModel.self) private var tour
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Bindable private var extras = Extras.shared

    /// Nothing covers the reader: a pending start may go ahead.
    private var isClear: Bool {
        !model.showChurchMode && !model.showMore && extras.sheet == nil && model.paywall == nil
    }

    func body(content: Content) -> some View {
        content
            .tourHost(.root)
            .onChange(of: model.lectern) { _, state in tour.observe(.lectern(state)) }
            .onChange(of: "\(model.hymnal.id)#\(model.hymn.id)") { _, _ in tour.observe(.hymnChanged) }
            .onChange(of: model.isMenuOpen) { _, open in tour.observe(.menuOpen(open)) }
            .onChange(of: player.isPlaying && player.hymn == model.hymn) { _, playing in tour.observe(.playing(playing)) }
            .onChange(of: extras.sheet == .memory) { _, open in tour.observe(.memoriseOpen(open)) }
            .onChange(of: model.showChurchMode) { _, open in tour.observe(.churchOpen(open)) }
            .onChange(of: model.showMore) { _, open in tour.observe(.moreOpen(open)) }
            .onChange(of: model.hymn.hasAccompaniment && player.isAvailable, initial: true) { _, has in
                tour.context.hasAccompaniment = has
            }
            .onChange(of: sizeClass == .regular && model.isSidebarVisible, initial: true) { _, visible in
                tour.context.sidebarVisible = visible
            }
            .onChange(of: sizeClass == .regular, initial: true) { _, regular in tour.context.isRegularWidth = regular }
            // A start asked for under What's New (or its Try Worship Mode)
            // goes ahead the moment the screen is clear: no settling delay.
            .task(id: "\(tour.pending != nil)|\(isClear)") {
                guard tour.pending != nil, isClear else { return }
                tour.startPending()
            }
            .onAppear {
                tour.perform = { [model, player] action in
                    switch action {
                    case .resetChrome:
                        model.closeMenu()
                        model.closeLectern()
                    case .closeLectern: model.closeLectern()
                    case .closeMenu: model.closeMenu()
                    case .stopPlayer: player.stop()
                    case .leaveChurchMode: model.showChurchMode = false
                    case .closeMore: model.showMore = false
                    }
                }
            }
    }
}
