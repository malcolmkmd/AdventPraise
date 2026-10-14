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
        let days = (0..<30).compactMap { offset -> HymnOfTheDay? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            let hymn = hymnal.hymns[HymnOfTheDay.index(for: date, count: hymnal.hymns.count)]
            let verse = hymn.blocks.first { if case .verse = $0 { true } else { false } } ?? hymn.blocks.first
            return HymnOfTheDay(date: date, number: hymn.id, title: hymn.title, hymnal: hymnal.name,
                                lines: verse?.lines ?? [])
        }
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
            let hymns = reader.hymnal.hymns
            guard !hymns.isEmpty else { return }
            _ = reader.open(number: hymns[HymnOfTheDay.index(for: .now, count: hymns.count)].id, source: .numpad)
        }
    }
}
