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
    let reader = ReaderModel()

    private init() {}
}

@main
struct AdventPraiseApp: App {
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
                .tint(services.settings.surface.tint)
        }
    }
}
