//
//  SheetMusicCatalog.swift
//  Advent Praise
//
//  Which hymns have sheet music, and their pages. The scores are engraved
//  ahead of time from The Cyber Hymnal's scores (Tools/sheet-music in the
//  repo) into one vector page per hymn in three widths: `phone`, `pad` and
//  `line` (short lines for system by system on an upright phone).
//  They ship as a pack per width, `sheet-music-phone.pack`,
//  `sheet-music-pad.pack` and `sheet-music-line.pack`: each page raw
//  DEFLATE, back to back.
//  `sheet-music-manifest.json` gives each page's place in its pack and size:
//
//      {"hymnal": "english", "packs": {"phone": "sheet-music-phone", ...},
//       "hymns": {"100": {"phone": {"w": 798, "h": 1726, "o": 0, "n": 21033}, "pad": {...}}}}
//
//  The pages draw in `currentColor`, so the viewer inks them for the
//  reading surface (light or dark) with one CSS colour.
//
//  `sheet-music-sync.pack` holds each hymn's timing against its MIDI file and
//  where its measures, notes and syllables sit on each page (SheetMusicTiming),
//  so the viewer can follow the accompaniment. The manifest's `"sync"` entry
//  gives its place in that pack.
//

import Foundation

enum SheetMusicLayout: String, Sendable, CaseIterable {
    /// Narrow: an iPhone in portrait, or iPad in a narrow split.
    case phone
    /// Wide: iPad, a wide split, or an iPhone in landscape.
    case pad
    /// Shortest lines (two or three measures): system by system on a phone held upright.
    case line

    /// The pad pages once the music has this much width.
    static let padWidth: CGFloat = 700

    /// The whole page.
    static func forWidth(_ width: CGFloat) -> SheetMusicLayout {
        width >= padWidth ? .pad : .phone
    }

    /// Below this width, system by system uses the shortest lines.
    static let lineWidth: CGFloat = 600

    /// System by system: one line as large as fits. The phone's lines when
    /// there's room (landscape, iPad), the shortest held upright.
    static func forSystems(width: CGFloat) -> SheetMusicLayout {
        width < lineWidth ? .line : .phone
    }
}

/// One engraved page: its SVG and its size in SVG units.
struct SheetMusicPage: Sendable, Equatable {
    let svg: String
    let width: Double
    let height: Double
}

enum SheetMusicCatalog {
    struct Manifest: Decodable, Sendable {
        struct Page: Decodable, Sendable {
            let w: Double
            let h: Double
            /// Offset of the page in its pack.
            let o: Int
            /// Its length in the pack (compressed).
            let n: Int
        }
        struct Chunk: Decodable, Sendable {
            let o: Int
            let n: Int
        }
        struct Entry: Decodable, Sendable {
            let pages: [String: Page]
            let sync: Chunk?

            private struct Key: CodingKey {
                var stringValue: String
                var intValue: Int? { nil }
                init(stringValue: String) { self.stringValue = stringValue }
                init?(intValue: Int) { nil }
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: Key.self)
                var pages: [String: Page] = [:]
                for layout in SheetMusicLayout.allCases {
                    let key = Key(stringValue: layout.rawValue)
                    if container.contains(key) { pages[layout.rawValue] = try container.decode(Page.self, forKey: key) }
                }
                self.pages = pages
                sync = try container.decodeIfPresent(Chunk.self, forKey: Key(stringValue: "sync"))
            }
        }
        let hymnal: String
        let packs: [String: String]
        let hymns: [String: Entry]
    }

    private static let manifest: Manifest? = {
        guard let url = Bundle.main.url(forResource: "sheet-music-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }()

    /// The manifest entry for hymn `number` in `hymnal`. An SDA Hymnal hymn
    /// shows its Christ In Song version's score only when it's the same tune
    /// and the setting is public domain (SDAHTunes); otherwise it has none.
    private static func entry(hymnal: String, number: Int) -> Manifest.Entry? {
        guard let manifest else { return nil }
        if manifest.hymnal == hymnal { return manifest.hymns[String(number)] }
        guard hymnal == HymnalInfo.sdahID, manifest.hymnal == HymnalInfo.default.id,
              let cis = SDAHTunes.cisScore(for: number) else { return nil }
        return manifest.hymns[String(cis)]
    }

    /// Whether hymn `number` in `hymnal` has sheet music.
    static func has(hymnal: String, number: Int) -> Bool {
        entry(hymnal: hymnal, number: number) != nil
    }

    /// How many hymns have sheet music in `hymnal`.
    static func count(hymnal: String) -> Int {
        guard let manifest else { return 0 }
        if manifest.hymnal == hymnal { return manifest.hymns.count }
        guard let info = HymnalInfo.with(id: hymnal), info.numbering == .sdah else { return 0 }
        return (1...max(info.maxNumber, 1)).count { entry(hymnal: hymnal, number: $0) != nil }
    }

    /// The page for hymn `number` in `layout`, read from its pack and
    /// inflated. Nil if it doesn't ship or can't be read.
    static func page(hymnal: String, number: Int, layout: SheetMusicLayout) -> SheetMusicPage? {
        guard let manifest, let entry = entry(hymnal: hymnal, number: number)?.pages[layout.rawValue],
              let pack = manifest.packs[layout.rawValue],
              let url = Bundle.main.url(forResource: pack, withExtension: "pack") else { return nil }
        return read(url: url, entry: entry)
    }

    static func read(url: URL, entry: Manifest.Page) -> SheetMusicPage? {
        guard let inflated = inflate(url: url, offset: entry.o, length: entry.n),
              let svg = String(data: inflated, encoding: .utf8) else { return nil }
        return SheetMusicPage(svg: svg, width: entry.w, height: entry.h)
    }

    /// Hymn `number`'s timing against its MIDI file and its page geometry. Nil if none ships.
    static func timing(hymnal: String, number: Int) -> SheetMusicTiming? {
        guard let manifest, let chunk = entry(hymnal: hymnal, number: number)?.sync,
              let pack = manifest.packs["sync"],
              let url = Bundle.main.url(forResource: pack, withExtension: "pack"),
              let data = inflate(url: url, offset: chunk.o, length: chunk.n) else { return nil }
        return SheetMusicTiming(json: data)
    }

    private static func inflate(url: URL, offset: Int, length: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: UInt64(offset))) != nil,
              let compressed = try? handle.read(upToCount: length), compressed.count == length,
              let inflated = try? (compressed as NSData).decompressed(using: .zlib) else { return nil }
        return inflated as Data
    }
}
