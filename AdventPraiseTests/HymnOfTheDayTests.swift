//
//  HymnOfTheDayTests.swift
//  AdventPraiseTests
//
//  Hymn of the Day: one pure rule (HymnOfTheDayPicker), a full cycle with
//  no repeats, deterministic, and the widget's feed, its link and the app's
//  own link all land on the same hymn.
//

import Foundation
import Testing
@testable import Advent_Praise

@MainActor
struct HymnOfTheDayTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Africa/Johannesburg")!
        return c
    }

    @Test(arguments: [1, 2, 3, 7, 12, 100, 695, 1000])
    func everyHymnOncePerCycle(count: Int) {
        for cycle in [-1, 0, 1, 2, 57] {
            let picks = (0..<count).map { HymnOfTheDayPicker.index(dayIndex: cycle * count + $0, count: count) }
            #expect(Set(picks).count == count, "cycle \(cycle) of \(count) repeats")
            #expect(picks.allSatisfy { (0..<count).contains($0) })
        }
    }

    @Test func deterministic() {
        for day in [-400, 0, 1, 1018, 5000] {
            #expect(HymnOfTheDayPicker.index(dayIndex: day, count: 695) == HymnOfTheDayPicker.index(dayIndex: day, count: 695))
        }
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 23, minute: 59))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 0, minute: 1))!
        #expect(HymnOfTheDayPicker.index(for: date, count: 695, calendar: calendar)
                == HymnOfTheDayPicker.index(for: morning, count: 695, calendar: calendar))
        #expect(HymnOfTheDayPicker.dayIndex(for: date, calendar: calendar) == 1017)
    }

    @Test func neighbouringDaysAreScattered() {
        let picks = (0..<30).map { HymnOfTheDayPicker.index(dayIndex: 1000 + $0, count: 695) }
        let steps = zip(picks, picks.dropFirst()).filter { abs($0 - $1) == 1 }
        #expect(steps.isEmpty)
    }

    /// The widget shows the feed's entry and opens adventpraise://hymn/<number>;
    /// the app's Hymn of the Day link uses the same function: all one hymn.
    @Test func feedLinkAndAppAgree() {
        let reader = AppServices.shared.reader
        let hymnal = reader.hymnal
        let start = Date()
        let feed = HymnOfTheDayFeed.days(in: hymnal, from: start, count: 30, calendar: .current)
        #expect(feed.count == 30)
        for (offset, day) in feed.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            #expect(HymnOfTheDayFeed.hymn(on: date, in: hymnal)?.id == day.number)
            #expect(hymnal.hymn(number: day.number)?.title == day.title)
            #expect(day.url.absoluteString == "adventpraise://hymn/\(day.number)?hymnal=\(hymnal.id)")
        }
        // Tapping the widget.
        WidgetLinks.handle(feed[0].url)
        #expect(reader.hymn.id == feed[0].number)
        // A feed written for another hymnal opens in that hymnal.
        if let other = HymnalInfo.catalogue.first(where: { $0.id != hymnal.id }) {
            let original = HymnalInfo.with(id: hymnal.id)!
            let otherHymnal = Hymnal.load(other)!
            let otherDay = HymnOfTheDayFeed.days(in: otherHymnal, from: start, count: 1)[0]
            WidgetLinks.handle(otherDay.url)
            #expect(reader.hymnal.id == other.id)
            #expect(reader.hymn.id == otherDay.number && reader.hymn.title == otherDay.title)
            reader.switchHymnal(to: original, feedback: nil, source: .lectern)
        }
        // The Church Remote widget's Hymn of the Day link.
        _ = reader.open(number: 1, feedback: nil, source: .numpad)
        WidgetLinks.handle(WidgetLink.hymnOfTheDay.url)
        #expect(reader.hymn.id == feed[0].number)
    }
}
