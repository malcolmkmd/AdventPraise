//
//  HymnOfTheDayPicker.swift
//  Advent Praise (app + AdventPraiseWidgets)
//
//  The one Hymn of the Day rule, a pure function of the local calendar day:
//  day index = whole local days since 1 Jan 2024. Days run in cycles of N
//  (the hymnal's size); inside a cycle the hymn is (a·pos + b) mod N, with a
//  coprime to N, so every hymn appears exactly once per cycle and
//  neighbouring days are scattered. a and b come from a SplitMix64 hash of
//  the cycle number, so each cycle has a new order. The result is an index
//  into the hymnal's `hymns` array; the app turns that into the hymn and its
//  number once (HymnOfTheDayFeed), and the widget only shows that.
//

import Foundation

enum HymnOfTheDayPicker {
    /// Whole local days from 1 Jan 2024 to `date` (negative before it).
    static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let epoch = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? .distantPast
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func index(for date: Date, count: Int, calendar: Calendar = .current) -> Int {
        index(dayIndex: dayIndex(for: date, calendar: calendar), count: count)
    }

    /// Index into a hymnal of `count` hymns for a day.
    static func index(dayIndex day: Int, count n: Int) -> Int {
        guard n > 1 else { return 0 }
        let cycle = day >= 0 ? day / n : (day - n + 1) / n     // floor division
        let pos = day - cycle * n                               // 0..<n
        let h1 = splitMix64(UInt64(bitPattern: Int64(cycle)))
        let h2 = splitMix64(h1)
        // A multiplier coprime to n, other than 1 when there's a choice (1
        // would walk the hymnal in order).
        var a = Int(h1 % UInt64(n))
        if n > 2, a < 2 { a = 2 }
        while gcd(a, n) != 1 { a = a + 1 >= n ? 1 : a + 1 }
        let b = Int(h2 % UInt64(n))
        return (a * pos + b) % n
    }

    static func splitMix64(_ seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
