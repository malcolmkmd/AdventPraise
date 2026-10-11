//
//  ScriptureLinks.swift
//  Advent Praise
//
//  Bible passages each hymn draws on, and the reverse index: from a passage
//  to every hymn that cites it. Data: Resources/Extras/scripture_links.json
//  (ships empty), e.g.
//
//      "english": { "12": [ { "book": "Psalms", "chapter": 23 },
//                           { "book": "John", "chapter": 3, "from": 16, "to": 17 } ] }
//
//  `book` must be one of `BibleBook.names` (full English name).
//

import Foundation

struct Passage: Decodable, Hashable, Sendable, Comparable, Identifiable {
    let book: String
    let chapter: Int
    /// First verse; nil means the whole chapter.
    var from: Int?
    /// Last verse; nil means a single verse (or the whole chapter).
    var to: Int?

    var id: String { reference }

    var reference: String {
        guard let from else { return "\(book) \(chapter)" }
        guard let to, to != from else { return "\(book) \(chapter):\(from)" }
        return "\(book) \(chapter):\(from)–\(to)"
    }

    /// Canonical order: book, chapter, then verse.
    static func < (a: Passage, b: Passage) -> Bool {
        (BibleBook.order(of: a.book), a.chapter, a.from ?? 0, a.to ?? 0)
            < (BibleBook.order(of: b.book), b.chapter, b.from ?? 0, b.to ?? 0)
    }

    /// True when the two passages share at least one verse (a whole-chapter
    /// passage overlaps every passage in that chapter).
    func overlaps(_ other: Passage) -> Bool {
        guard book == other.book, chapter == other.chapter else { return false }
        guard let a = from, let b = other.from else { return true }
        return a <= (other.to ?? b) && b <= (to ?? a)
    }
}

enum BibleBook {
    static let names = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
        "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah",
        "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
        "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
        "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    ]

    private static let index = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })

    /// Position in the canon; unknown names sort after Revelation.
    static func order(of book: String) -> Int { index[book] ?? names.count }
}

/// One passage and the hymns (in one hymnal) that cite it.
struct PassageHymns: Identifiable, Hashable, Sendable {
    var id: String { passage.id }
    let passage: Passage
    let numbers: [Int]
}

enum ScriptureLinks {
    private static let file: PerHymnFile<[Passage]> = ExtrasBundle.decode("scripture_links") ?? .empty

    static func passages(hymnal: String, number: Int) -> [Passage] {
        (file.entry(hymnal: hymnal, number: number) ?? []).sorted()
    }

    /// Every cited passage in a hymnal, in canonical order, with its hymns.
    static func index(hymnal: String) -> [PassageHymns] {
        var byPassage: [Passage: [Int]] = [:]
        for (number, passages) in file.entries(hymnal: hymnal) {
            for passage in passages { byPassage[passage, default: []].append(number) }
        }
        return byPassage.keys.sorted().map { PassageHymns(passage: $0, numbers: byPassage[$0]!.sorted()) }
    }

    /// Hymns whose passages overlap `passage`, excluding `excluding`.
    static func hymns(citing passage: Passage, hymnal: String, excluding: Int? = nil) -> [Int] {
        file.entries(hymnal: hymnal)
            .filter { $0.number != excluding && $0.entry.contains { $0.overlaps(passage) } }
            .map(\.number)
    }
}
