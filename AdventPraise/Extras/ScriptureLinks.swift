//
//  ScriptureLinks.swift
//  Advent Praise
//
//  Bible passages each hymn draws on, and the reverse index: from a passage
//  to every hymn that cites it. Data: Resources/Extras/scripture_links.json,
//  built and checked by Tools/build_scripture_links.py. Each hymn holds rows
//  of `[ref, source, confidence]`:
//
//      "english": { "157": [ ["Psalms 23:1", "lyric", "high"],
//                            ["John 10:11", "lyric", "medium"] ] }
//
//  `ref` is "Book C", "Book C:V" or "Book C:V-W", with `Book` one of
//  `BibleBook.names`. `source` says where the reference comes from
//  (`ScriptureSource`); `confidence` is "high" (the hymn quotes the verse)
//  or "medium" (it clearly echoes it).
//

import Foundation

struct Passage: Hashable, Sendable, Comparable, Identifiable {
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

    /// Parses "Book C", "Book C:V" or "Book C:V-W" (hyphen or en dash).
    init?(reference: String) {
        guard let space = reference.lastIndex(of: " ") else { return nil }
        let book = String(reference[..<space])
        guard BibleBook.usfm(for: book) != nil else { return nil }
        let numbers = reference[reference.index(after: space)...]
            .split(whereSeparator: { ":-–".contains($0) }).map { Int($0) }
        guard !numbers.isEmpty, numbers.count <= 3, numbers.allSatisfy({ ($0 ?? 0) > 0 }) else { return nil }
        self.book = book
        self.chapter = numbers[0]!
        self.from = numbers.count > 1 ? numbers[1] : nil
        self.to = numbers.count > 2 ? numbers[2] : nil
    }

    /// The passage on bible.com in the King James Version. A universal link:
    /// it opens the YouVersion Bible app when installed, otherwise Safari.
    var bibleURL: URL? {
        guard let code = BibleBook.usfm(for: book) else { return nil }
        var path = "\(code).\(chapter)"
        if let from { path += ".\(from)" + (to.map { $0 != from ? "-\($0)" : "" } ?? "") }
        return URL(string: "https://www.bible.com/bible/1/\(path)")
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

/// Where a reference comes from.
enum ScriptureSource: String, Decodable, Sendable {
    /// The hymn's own words quote or paraphrase the passage (checked against the KJV).
    case lyric
    /// The scripture text printed with the hymn in Christ in Song (1908).
    case hymnal = "cis1908"
    /// Hymnary.org's scripture index for the hymn.
    case hymnary

    var label: String {
        switch self {
        case .lyric: "From the hymn’s words"
        case .hymnal: "Printed in Christ in Song (1908)"
        case .hymnary: "Hymnary.org scripture index"
        }
    }
}

enum ScriptureConfidence: String, Decodable, Sendable {
    /// The hymn quotes the verse.
    case high
    /// The hymn clearly echoes the passage without quoting it.
    case medium
}

/// One cited passage with where it came from. Decodes from `[ref, source, confidence]`.
struct ScriptureLink: Decodable, Hashable, Sendable, Identifiable {
    let passage: Passage
    let source: ScriptureSource
    let confidence: ScriptureConfidence

    var id: String { passage.id }

    init(from decoder: Decoder) throws {
        var row = try decoder.unkeyedContainer()
        let ref = try row.decode(String.self)
        guard let passage = Passage(reference: ref) else {
            throw DecodingError.dataCorruptedError(in: row, debugDescription: "Bad reference “\(ref)”")
        }
        self.passage = passage
        source = try row.decode(ScriptureSource.self)
        confidence = try row.decode(ScriptureConfidence.self)
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

    /// USFM book codes, the IDs bible.com uses, in the same order as `names`.
    private static let codes = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH",
        "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK",
        "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
        "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH",
        "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD",
        "REV",
    ]

    private static let index = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })

    /// Position in the canon; unknown names sort after Revelation.
    static func order(of book: String) -> Int { index[book] ?? names.count }

    static func usfm(for book: String) -> String? { index[book].map { codes[$0] } }
}

/// One passage and the hymns (in one hymnal) that cite it.
struct PassageHymns: Identifiable, Hashable, Sendable {
    var id: String { passage.id }
    let passage: Passage
    let numbers: [Int]
}

enum ScriptureLinks {
    private static let file: PerHymnFile<[ScriptureLink]> = ExtrasBundle.decode("scripture_links") ?? .empty

    static func links(hymnal: String, number: Int) -> [ScriptureLink] {
        (file.entry(hymnal: hymnal, number: number) ?? []).sorted { $0.passage < $1.passage }
    }

    /// Every cited passage in a hymnal, in canonical order, with its hymns.
    static func index(hymnal: String) -> [PassageHymns] {
        var byPassage: [Passage: [Int]] = [:]
        for (number, links) in file.entries(hymnal: hymnal) {
            for link in links { byPassage[link.passage, default: []].append(number) }
        }
        return byPassage.keys.sorted().map { PassageHymns(passage: $0, numbers: byPassage[$0]!.sorted()) }
    }

    /// Hymns whose passages overlap `passage`, excluding `excluding`.
    static func hymns(citing passage: Passage, hymnal: String, excluding: Int? = nil) -> [Int] {
        file.entries(hymnal: hymnal)
            .filter { $0.number != excluding && $0.entry.contains { $0.passage.overlaps(passage) } }
            .map(\.number)
    }
}
