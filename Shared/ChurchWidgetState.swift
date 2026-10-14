//
//  ChurchWidgetState.swift
//  Advent Praise (app + AdventPraiseWidgets)
//
//  What the Home Screen / Lock Screen widget shows, written by the app
//  (ChurchWidgetSync.swift) into the App Group and read by the widget, and
//  the widget's deep links (adventpraise://…) handled by WidgetLinks.swift.
//

import Foundation

struct ChurchWidgetState: Codable, Hashable, Sendable {
    var hymnNumber: Int
    var title: String
    var hymnal: String
    /// "Verse 2 of 4", the chorus label, "Screen blank", or "" when not presenting.
    var position: String
    var isPresenting: Bool
    var isOnTV: Bool
    var isBlanked: Bool
    var isPro: Bool
    var hasNextHymn: Bool
    var canGoBack: Bool

    static let placeholder = ChurchWidgetState(
        hymnNumber: 1, title: "Watchman Blow The Gospel Trumpet", hymnal: "Christ In Song",
        position: "", isPresenting: false, isOnTV: false, isBlanked: false, isPro: true,
        hasNextHymn: true, canGoBack: false)

    static let appGroup = "group.com.mDev.Advent-Praise"
    static let widgetKind = "ChurchRemote"
    private static let key = "churchWidget.state.v1"

    static func load() -> ChurchWidgetState {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              let state = try? JSONDecoder().decode(ChurchWidgetState.self, from: data) else { return placeholder }
        return state
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}

/// Hymn of the day, written by the app for the coming days (the widget has
/// no hymnal of its own). Deterministic per date: the same hymn all day.
struct HymnOfTheDay: Codable, Hashable, Sendable {
    var date: Date          // the day's start
    var number: Int
    var title: String
    var hymnal: String
    var lines: [String]     // the first verse

    static let widgetKind = "HymnOfTheDay"
    private static let key = "hymnOfTheDay.days.v1"

    static let placeholder = HymnOfTheDay(
        date: Calendar.current.startOfDay(for: .now), number: 1, title: "Watchman Blow The Gospel Trumpet",
        hymnal: "Christ In Song",
        lines: ["Watchman, blow the gospel trumpet,", "Every soul a warning give;",
                "Whosoever hears the message", "May repent, and turn, and live."])

    /// The index for a date into a hymnal of `count` hymns.
    static func index(for date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return (day &* 7919) % count   // a stride, so neighbouring days aren't neighbouring hymns
    }

    static func loadAll() -> [HymnOfTheDay] {
        guard let data = UserDefaults(suiteName: ChurchWidgetState.appGroup)?.data(forKey: key),
              let days = try? JSONDecoder().decode([HymnOfTheDay].self, from: data) else { return [] }
        return days
    }

    static func saveAll(_ days: [HymnOfTheDay]) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults(suiteName: ChurchWidgetState.appGroup)?.set(data, forKey: key)
    }

    var url: URL { URL(string: "adventpraise://hymn/\(number)")! }
}

enum WidgetLink: String, Sendable {
    /// Open church mode on the current hymn (resume presenting). Pro.
    case present
    case favourites
    case hymnOfTheDay = "hymn-of-the-day"
    case numberPad = "number-pad"
    case paywall

    var url: URL { URL(string: "adventpraise://\(rawValue)")! }
}
