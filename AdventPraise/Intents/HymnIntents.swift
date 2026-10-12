//
//  HymnIntents.swift
//  Advent Praise
//
//  Siri and Shortcuts: open a hymn by number, play a hymn (opens it, and
//  starts the accompaniment when one ships), go to the next hymn, and start
//  church mode. All of them open the app — the hymn is read on screen.
//

import AppIntents

struct OpenHymnIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Hymn"
    static let description = IntentDescription("Opens a hymn by number in the hymnal you are reading.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Hymn number", inclusiveRange: (1, 999),
               requestValueDialog: IntentDialog("Which hymn number?"))
    var number: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Open hymn \(\.$number)")
    }

    init() {}
    init(number: Int) { self.number = number }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reader = AppServices.shared.reader
        Analytics.track(.shortcutRun(intent: "open_hymn"))
        guard reader.open(number: number, feedback: nil) else {
            throw HymnIntentError.noSuchHymn(number, reader.hymnal.name)
        }
        return .result(dialog: "Hymn \(number), \(reader.hymn.title).")
    }
}

struct PlayHymnIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Hymn"
    static let description = IntentDescription("Opens a hymn by number and plays its accompaniment when one is available.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Hymn number", inclusiveRange: (1, 999),
               requestValueDialog: IntentDialog("Which hymn number?"))
    var number: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Play hymn \(\.$number)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let services = AppServices.shared
        Analytics.track(.shortcutRun(intent: "play_hymn"))
        guard services.reader.open(number: number, feedback: nil) else {
            throw HymnIntentError.noSuchHymn(number, services.reader.hymnal.name)
        }
        let hymn = services.reader.hymn
        guard services.store.isPro || !hymn.hasAccompaniment else {
            services.reader.paywall = .player
            return .result(dialog: "Hymn \(number), \(hymn.title), is open. Playing along needs Advent Praise Pro.")
        }
        if services.player.start(hymn, source: services.reader.hymnal.name) {
            return .result(dialog: "Playing hymn \(number), \(hymn.title).")
        }
        return .result(dialog: "Hymn \(number), \(hymn.title), is open. Accompaniment isn’t available for it yet.")
    }
}

struct NextHymnIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Hymn"
    static let description = IntentDescription("Goes to the next hymn, or the next hymn in the playlist you are using.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reader = AppServices.shared.reader
        Analytics.track(.shortcutRun(intent: "next_hymn"))
        guard let next = AppServices.shared.goToNextHymn() else {
            return .result(dialog: "That’s the last hymn in \(reader.hymnal.name).")
        }
        return .result(dialog: "Hymn \(next.id), \(next.title).")
    }
}

struct ChurchModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Church Mode"
    static let description = IntentDescription("Shows the open hymn one verse at a time in large text.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Analytics.track(.shortcutRun(intent: "church_mode"))
        AppServices.shared.reader.showChurchMode = true
        return .result()
    }
}

enum HymnIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noSuchHymn(Int, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .noSuchHymn(number, hymnal): "There’s no hymn \(number) in \(hymnal)."
        }
    }
}

struct HymnShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenHymnIntent(), phrases: [
            "Open hymn in \(.applicationName)",
            "Open a hymn in \(.applicationName)",
            "Find a hymn in \(.applicationName)",
        ], shortTitle: "Open Hymn", systemImageName: "book")
        AppShortcut(intent: PlayHymnIntent(), phrases: [
            "Play hymn in \(.applicationName)",
            "Play a hymn in \(.applicationName)",
        ], shortTitle: "Play Hymn", systemImageName: "play")
        AppShortcut(intent: NextHymnIntent(), phrases: [
            "Next hymn in \(.applicationName)",
            "Go to the next hymn in \(.applicationName)",
        ], shortTitle: "Next Hymn", systemImageName: "forward")
        AppShortcut(intent: ChurchModeIntent(), phrases: [
            "Start church mode in \(.applicationName)",
        ], shortTitle: "Church Mode", systemImageName: "rectangle.on.rectangle")
    }
}
