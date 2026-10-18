//
//  SheetMusicCatalog.swift
//  Advent Praise
//
//  Which hymns have sheet music, and their pages. The scores are engraved
//  ahead of time from The Cyber Hymnal's scores (sheet-music/pipeline in the
//  repo) into one vector page per hymn in two widths: `phone` and `pad`.
//  They ship as two packs, `sheet-music-phone.pack` and
//  `sheet-music-pad.pack`: each page raw DEFLATE, back to back.
//  `sheet-music-manifest.json` gives each page's place in its pack and size:
//
//      {"hymnal": "english", "packs": {"phone": "sheet-music-phone", ...},
//       "hymns": {"100": {"phone": {"w": 798, "h": 1726, "o": 0, "n": 21033}, "pad": {...}}}}
//
//  The pages draw in `currentColor`, so the viewer inks them for the
//  reading surface (light or dark) with one CSS colour.
//

import Foundation

enum SheetMusicLayout: String, Sendable, CaseIterable {
    /// Narrow: an iPhone, or iPad in a narrow split.
    case phone
    /// Wide: iPad full screen or a wide split.
    case pad
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
        let hymnal: String
        let packs: [String: String]
        let hymns: [String: [String: Page]]
    }

    private static let manifest: Manifest? = {
        guard let url = Bundle.main.url(forResource: "sheet-music-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }()

    /// Whether hymn `number` in `hymnal` has sheet music.
    static func has(hymnal: String, number: Int) -> Bool {
        guard let manifest, manifest.hymnal == hymnal else { return false }
        return manifest.hymns[String(number)] != nil
    }

    /// How many hymns have sheet music in `hymnal`.
    static func count(hymnal: String) -> Int {
        guard let manifest, manifest.hymnal == hymnal else { return 0 }
        return manifest.hymns.count
    }

    /// The page for hymn `number` in `layout`, read from its pack and
    /// inflated. Nil if it doesn't ship or can't be read.
    static func page(hymnal: String, number: Int, layout: SheetMusicLayout) -> SheetMusicPage? {
        guard let manifest, manifest.hymnal == hymnal,
              let entry = manifest.hymns[String(number)]?[layout.rawValue],
              let pack = manifest.packs[layout.rawValue],
              let url = Bundle.main.url(forResource: pack, withExtension: "pack") else { return nil }
        return read(url: url, entry: entry)
    }

    static func read(url: URL, entry: Manifest.Page) -> SheetMusicPage? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: UInt64(entry.o))) != nil,
              let compressed = try? handle.read(upToCount: entry.n), compressed.count == entry.n,
              let inflated = try? (compressed as NSData).decompressed(using: .zlib),
              let svg = String(data: inflated as Data, encoding: .utf8) else { return nil }
        return SheetMusicPage(svg: svg, width: entry.w, height: entry.h)
    }
}
