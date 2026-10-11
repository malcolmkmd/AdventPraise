//
//  ExtrasData.swift
//  Advent Praise
//
//  Per-hymn reference data that ships beside the lyrics: stories, scripture
//  links and starting notes. Each lives in Resources/Extras/<name>.json as
//
//      { "version": 1, "hymnals": { "<hymnal key>": { "<hymn number>": … } } }
//
//  The files ship empty. Only add entries that come from a cited source;
//  nothing here is generated or guessed.
//

import Foundation

/// One `{ version, hymnals }` file, keyed by hymnal then hymn number.
struct PerHymnFile<Entry: Decodable & Sendable>: Decodable, Sendable {
    let version: Int
    let hymnals: [String: [String: Entry]]

    func entry(hymnal: String, number: Int) -> Entry? { hymnals[hymnal]?[String(number)] }

    /// Every entry for one hymnal, by hymn number.
    func entries(hymnal: String) -> [(number: Int, entry: Entry)] {
        (hymnals[hymnal] ?? [:])
            .compactMap { key, value in Int(key).map { ($0, value) } }
            .sorted { $0.number < $1.number }
    }

    static var empty: PerHymnFile { PerHymnFile(version: 1, hymnals: [:]) }
}

enum ExtrasBundle {
    /// Decodes `<name>.json` from the bundle; nil if missing or malformed.
    static func decode<T: Decodable>(_ name: String, as type: T.Type = T.self) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Extras: \(name).json failed to decode: \(error)")
            #endif
            return nil
        }
    }
}
