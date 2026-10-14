//
//  ChurchWidgetSync.swift
//  Advent Praise
//
//  Keeps the widget's state (Shared/ChurchWidgetState.swift) in the App
//  Group current: the hymn on the reader, and church mode's verse, Blank and
//  TV while presenting. Every change reloads the widget's timelines.
//  Also wires the widget and Live Activity buttons (ChurchRemoteBridge) at
//  launch, so they work whenever the app is running.
//

import Foundation
import Observation
import WidgetKit

@MainActor
final class ChurchWidgetSync {
    static let shared = ChurchWidgetSync()
    private var last: ChurchWidgetState?
    private var reloadTask: Task<Void, Never>?

    func start() {
        ChurchRemoteBridge.handler = { ChurchLiveActivity.perform($0) }
        follow()
        followHymnal()
    }

    private var hymnOfTheDayHymnal = ""

    /// The next 30 days of Hymn of the Day for the reader's hymnal.
    private func followHymnal() {
        let s = AppServices.shared
        let hymnal = withObservationTracking { s.reader.hymnal } onChange: { [weak self] in
            Task { @MainActor in self?.followHymnal() }
        }
        let today = Calendar.current.startOfDay(for: .now)
        let key = "\(hymnal.id)|\(today.timeIntervalSince1970)"
        guard key != hymnOfTheDayHymnal, !hymnal.hymns.isEmpty else { return }
        hymnOfTheDayHymnal = key
        let days = HymnOfTheDayFeed.days(in: hymnal, from: today, count: 30)
        HymnOfTheDay.saveAll(days)
        WidgetCenter.shared.reloadTimelines(ofKind: HymnOfTheDay.widgetKind)
    }

    private func follow() {
        let s = AppServices.shared
        let state = withObservationTracking { Self.state(s) } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        guard state != last else { return }
        last = state
        state.save()
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(150))   // a burst of changes, one reload
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: ChurchWidgetState.widgetKind)
        }
    }

    private static func state(_ s: AppServices) -> ChurchWidgetState {
        let hymn = s.reader.hymn, church = s.church
        let sequence = hymn.sungSequence
        let index = min(church.index, max(sequence.count - 1, 0))
        let presenting = church.isActive
        var position = ""
        if presenting {
            if church.isBlanked {
                position = String(localized: "Screen blank")
            } else if sequence.indices.contains(index) {
                switch sequence[index] {
                case let .verse(number, _): position = String(localized: "Verse \(number) of \(hymn.verseCount)")
                case .chorus: position = s.reader.hymnal.chorusLabel
                }
            }
        }
        return ChurchWidgetState(
            hymnNumber: hymn.id, title: hymn.title, hymnal: s.reader.hymnal.name, position: position,
            isPresenting: presenting, isOnTV: presenting && church.isExternalScreenConnected,
            isBlanked: presenting && church.isBlanked, isPro: s.store.isPro,
            hasNextHymn: s.reader.upcomingHymn != nil, canGoBack: presenting && index > 0)
    }
}

/// adventpraise://… from the widget.
@MainActor
enum WidgetLinks {
    static func handle(_ url: URL) {
        guard url.scheme == "adventpraise" else { return }
        let s = AppServices.shared, reader = s.reader
        // adventpraise://hymn/123 (Hymn of the Day).
        if url.host() == "hymn", let number = Int(url.lastPathComponent) {
            reader.showChurchMode = false
            // The number is only meaningful in its own hymnal.
            let hymnalID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "hymnal" }?.value
            if let hymnalID, hymnalID != reader.hymnal.id, let info = HymnalInfo.with(id: hymnalID) {
                reader.switchHymnal(to: info, feedback: nil, source: .lectern)
            }
            _ = reader.open(number: number, source: .numpad)
            return
        }
        guard let link = WidgetLink(rawValue: url.host() ?? "") else { return }
        switch link {
        case .present:
            if s.store.isPro { reader.enterChurchMode(from: .tray) } else { reader.paywall = .airPlay }
        case .paywall:
            reader.paywall = .airPlay
        case .favourites:
            reader.showChurchMode = false
            reader.libraryTab = .favourites
            reader.openLectern(.library)
        case .numberPad:
            reader.showChurchMode = false
            reader.openLectern(.pad)
        case .hymnOfTheDay:
            reader.showChurchMode = false
            guard let hymn = HymnOfTheDayFeed.hymn(on: .now, in: reader.hymnal) else { return }
            _ = reader.open(number: hymn.id, source: .numpad)
        }
    }
}

/// Hymn of the Day in the app: the hymn for a date, and the widget's feed.
/// Both go through `hymn(on:in:)`, so the widget's number, its link
/// (adventpraise://hymn/<number>) and the app's own link always agree.
enum HymnOfTheDayFeed {
    static func hymn(on date: Date, in hymnal: Hymnal, calendar: Calendar = .current) -> Hymn? {
        guard !hymnal.hymns.isEmpty else { return nil }
        return hymnal.hymns[HymnOfTheDayPicker.index(for: date, count: hymnal.hymns.count, calendar: calendar)]
    }

    static func days(in hymnal: Hymnal, from start: Date, count: Int,
                     calendar: Calendar = .current) -> [HymnOfTheDay] {
        let first = calendar.startOfDay(for: start)
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: first),
                  let hymn = hymn(on: date, in: hymnal, calendar: calendar) else { return nil }
            let verse = hymn.blocks.first { if case .verse = $0 { true } else { false } } ?? hymn.blocks.first
            return HymnOfTheDay(date: date, number: hymn.id, title: hymn.title, hymnal: hymnal.name,
                                hymnalID: hymnal.id, lines: verse?.lines ?? [])
        }
    }
}
