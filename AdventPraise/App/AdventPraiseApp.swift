//
//  AdventPraiseApp.swift
//  Advent Praise
//
//  Entry point. One shared set of models (AppServices) feeds the UI and the
//  App Intents, so "Open hymn 12" from Siri lands in the same reader.
//

import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()

    let player = HymnMIDIEngine()
    let settings = ReadingSettings()
    let store = PurchaseStore()
    let freePlays = FreePlays()
    let reader = ReaderModel()
    let church = ChurchPresentation()

    private init() {
        // Playlist Play starts the accompaniment; each hymn hands on to the
        // next when it finishes. Wired here, not in a view, so it carries on
        // in church mode and with the screen locked.
        reader.onPlaylistStarted = { [player, reader] hymn in
            player.start(hymn, source: reader.hymnal.name)
        }
        player.onFinish = { [player, reader] in
            guard let next = reader.advancePlaylist() else { return }
            player.start(next, source: reader.hymnal.name)
        }
        player.onNextTrack = { [unowned self] in goToNextHymn(source: .lockScreen) }
        // Free users get a few plays of the accompaniment, then it is Pro.
        // A locked play asks for the paywall instead.
        player.isLocked = { [unowned self] in freePlaysAreUsedUp }
        player.onLocked = { [player, reader] in
            reader.paywall = .player
            Analytics.track(.playLimitPaywallShown(number: player.hymn?.id ?? reader.hymn.id))
        }
        player.onNewPlay = { [player, store, freePlays] in
            guard !store.isPro, let hymn = player.hymn else { return }
            Analytics.track(.freePlayUsed(number: hymn.id, remaining: freePlays.spend()))
        }
        #if DEBUG
        if let used = DebugLaunch.freePlaysUsed { freePlays.debugSet(used: used) }
        #endif
    }

    /// A new play would open the paywall: not Pro, and the free plays are gone.
    var freePlaysAreUsedUp: Bool { !store.isPro && freePlays.isUsedUp }

    /// Next hymn (or next playlist entry); keeps playing if it was. For the
    /// lock screen and Siri, so no haptic.
    @discardableResult
    func goToNextHymn(source: HymnSource) -> Hymn? {
        let wasPlaying = player.isPlaying
        guard let next = reader.goToNextHymn(feedback: nil, source: source) else { return nil }
        if wasPlaying { player.start(next, source: reader.hymnal.name) } else { player.cue(next, source: reader.hymnal.name) }
        return next
    }
}

@main
struct AdventPraiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let services = AppServices.shared

    init() {
        Analytics.start()
        AppServices.shared.store.start()
        HymnShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: services.reader)
                .environment(services.player)
                .environment(services.settings)
                .environment(services.store)
                .environment(services.freePlays)
                .environment(services.church)
                .tint(services.settings.surface.tint)
                .splashReveal()
        }
        .commands { ReaderCommands(model: services.reader) }
    }
}
