//
//  Hymnal.swift
//  Advent Praise
//
//  The vernacular hymnals. Every language ships in the bundle as one minified
//  JSON file (Resources/Hymnals/<key>.json, built by Tools/convert_hymnals.py)
//  and is decoded only when the reader opens it. Ownership lives in
//  PurchaseStore; this file only knows about text.
//

import SwiftUI

// MARK: - Catalogue

struct HymnalInfo: Identifiable, Hashable, Sendable {
    let id: String              // file key, e.g. "english", "ndebele"
    let name: String            // the hymnal's own title, e.g. "Christ In Song"
    let language: String
    let hymnCount: Int
    let maxNumber: Int
    let color: Color

    var isFree: Bool { PurchaseConfig.freeHymnals.contains(id) }

    static let catalogue: [HymnalInfo] = {
        struct Entry: Decodable { let key, title, language: String; let count, maxNumber: Int }
        guard let url = Bundle.main.url(forResource: "hymnals", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [HymnalInfo(id: "english", name: "Christ In Song", language: "English",
                               hymnCount: 300, maxNumber: 300, color: palette[0])]
        }
        return entries.enumerated().map { index, e in
            HymnalInfo(id: e.key, name: e.title, language: e.language, hymnCount: e.count,
                       maxNumber: e.maxNumber, color: palette[index % palette.count])
        }
    }()

    static let `default`: HymnalInfo = catalogue.first { $0.id == "english" } ?? catalogue[0]

    static func with(id: String?) -> HymnalInfo? { catalogue.first { $0.id == id } }

    private static let palette: [Color] = [
        Color(hex: 0x4B2E83), Color(hex: 0x5C3A2E), Color(hex: 0x7A2C4A), Color(hex: 0x3A5A8C),
        Color(hex: 0xD9632E), Color(hex: 0x5A8A2E), Color(hex: 0x4A8A96), Color(hex: 0x1F7466),
        Color(hex: 0x7F5B1C), Color(hex: 0x8C3A3A),
    ]
}

// MARK: - A loaded hymnal

struct SearchHit: Identifiable, Hashable, Sendable {
    var id: Int { hymn.id }
    let hymn: Hymn
    let snippet: String        // the matching line, for highlighting
}

struct Hymnal: Sendable {
    let info: HymnalInfo
    /// What this language calls the chorus ("Refrain", "Coro", "Ciindululo"…).
    let chorusLabel: String
    let hymns: [Hymn]
    private let index: [Int: Int]
    private let foldedTitles: [String]
    private let foldedLines: [[String]]

    var count: Int { hymns.count }
    var name: String { info.name }
    var id: String { info.id }

    func hymn(number: Int) -> Hymn? { index[number].map { hymns[$0] } }

    /// The hymn after (or before) `number` in hymnal order.
    func hymn(after number: Int, offset: Int = 1) -> Hymn? {
        guard let i = index[number] else { return hymns.first }
        let j = i + offset
        return hymns.indices.contains(j) ? hymns[j] : nil
    }

    /// Accent-, case- and apostrophe-insensitive word search. Every word must
    /// appear; title matches rank above lyric matches. A bare number jumps to
    /// that hymn first.
    func search(_ query: String, inLyrics: Bool) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = Self.fold(trimmed).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        var titleHits: [SearchHit] = []
        var lyricHits: [SearchHit] = []
        if let n = Int(trimmed), let hymn = hymn(number: n) { titleHits.append(SearchHit(hymn: hymn, snippet: hymn.title)) }
        for (i, hymn) in hymns.enumerated() where hymn.id != Int(trimmed) {
            if words.allSatisfy(foldedTitles[i].contains) {
                titleHits.append(SearchHit(hymn: hymn, snippet: hymn.title))
            } else if inLyrics {
                let lines = foldedLines[i]
                guard words.allSatisfy({ w in lines.contains { $0.contains(w) } }) else { continue }
                let phrase = words.joined(separator: " ")
                let best = lines.firstIndex { $0.contains(phrase) } ?? lines.firstIndex { $0.contains(words[0]) } ?? 0
                let original = hymn.blocks.flatMap(\.lines)
                lyricHits.append(SearchHit(hymn: hymn, snippet: original.indices.contains(best) ? original[best] : hymn.title))
            }
        }
        return titleHits + lyricHits
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: Loading

    private struct File: Decodable {
        let refrain: String
        let hymns: [Record]
    }
    private struct Record: Decodable {
        let number: Int
        let title: String
        let refs: [String: Int]
        let blocks: [BlockRecord]
    }
    private struct BlockRecord: Decodable {
        let t: String
        let n: Int?
        let l: [String]
    }

    private static let refOrder = ["vern", "cs", "ah", "ch", "sdah"]

    /// Decodes `<key>.json` from the bundle. Roughly 10–40 ms for the largest
    /// hymnals, so it is fine to call on demand from the main actor.
    static func load(_ info: HymnalInfo) -> Hymnal? {
        guard let url = Bundle.main.url(forResource: info.id, withExtension: "json"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        let hymns = file.hymns.map { record in
            let refs = record.refs
                .filter { !($0.key == "vern" && $0.value == record.number) }   // same as the hymn number
                .sorted { (refOrder.firstIndex(of: $0.key) ?? 99, $0.key) < (refOrder.firstIndex(of: $1.key) ?? 99, $1.key) }
                .map { "\($0.key == "vern" ? "Vern" : $0.key.uppercased()) \($0.value)" }
            let blocks: [Hymn.Block] = record.blocks.map {
                $0.t == "c" ? .chorus(lines: $0.l) : .verse(number: $0.n ?? 1, lines: $0.l)
            }
            return Hymn(id: record.number, title: record.title, references: refs, blocks: blocks,
                        midiResource: MIDICatalog.resource(hymnal: info.id, number: record.number))
        }
        return Hymnal(info: info, chorusLabel: file.refrain, hymns: hymns)
    }

    private init(info: HymnalInfo, chorusLabel: String, hymns: [Hymn]) {
        self.info = info
        self.chorusLabel = chorusLabel
        self.hymns = hymns
        index = Dictionary(hymns.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        foldedTitles = hymns.map { Self.fold($0.title) }
        foldedLines = hymns.map { $0.blocks.flatMap(\.lines).map(Self.fold) }
    }

    /// An empty stand-in, only used if a bundled file is missing or corrupt.
    static func empty(_ info: HymnalInfo) -> Hymnal { Hymnal(info: info, chorusLabel: "Chorus", hymns: []) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
