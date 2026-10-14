//
//  ChurchActivity.swift
//  Advent Praise (app + AdventPraiseWidgets)
//
//  Church mode's Live Activity (Lock Screen and Dynamic Island): what's
//  being presented, and Previous / Next / End buttons. The buttons are
//  LiveActivityIntents, so they run in the app's process, where
//  ChurchRemoteBridge hands them to church mode (ChurchLiveActivity.swift).
//  Compiled into both targets; the widget extension only draws.
//

import ActivityKit
import AppIntents
import Foundation

struct ChurchActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var hymnNumber: Int
        var title: String
        /// "Verse 2 of 4", the chorus label, or "Screen blank".
        var position: String
        var step: Int
        var stepCount: Int
        var canGoBack: Bool
        /// The words are also on a TV (AirPlay, mirroring or a cable).
        var isOnTV: Bool
    }

    var hymnal: String
}

enum ChurchRemoteAction: String, Sendable {
    case next, previous, end, blank, nextHymn
}

/// Set by the app at launch; nil in the extension.
@MainActor
enum ChurchRemoteBridge {
    static var handler: ((ChurchRemoteAction) -> Void)?
}

struct ChurchNextVerseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Verse"
    static let description = IntentDescription("Shows the next verse in church mode.")
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await MainActor.run { ChurchRemoteBridge.handler?(.next) }
        return .result()
    }
}

struct ChurchPreviousVerseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Previous Verse"
    static let description = IntentDescription("Shows the previous verse in church mode.")
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await MainActor.run { ChurchRemoteBridge.handler?(.previous) }
        return .result()
    }
}

struct ChurchEndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Church Mode"
    static let description = IntentDescription("Stops presenting in church mode.")
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await MainActor.run { ChurchRemoteBridge.handler?(.end) }
        return .result()
    }
}

struct ChurchBlankIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Blank the Screen"
    static let description = IntentDescription("Blanks the TV in church mode, or shows the words again.")
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await MainActor.run { ChurchRemoteBridge.handler?(.blank) }
        return .result()
    }
}

struct ChurchNextHymnIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Hymn"
    static let description = IntentDescription("Goes to the next hymn in the playlist or hymnal.")
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await MainActor.run { ChurchRemoteBridge.handler?(.nextHymn) }
        return .result()
    }
}
