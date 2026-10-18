//
//  MIDICatalog.swift
//  Advent Praise
//
//  Which hymns have accompaniment. `Resources/Midi/midi-manifest.json` lists
//  the hymn numbers per hymnal and how their files are named; it is written
//  by `Tools/sync_midi.py` from the Cyber Hymnal ledger, so adding files is
//  "re-run the script, rebuild" with no code change. A listed number only
//  counts if its file is actually in the bundle.
//
//      {"hymnals": {"english": {"file": "hymn-%03d", "hymns": [1, 2, 3]}}}
//

import Foundation

enum MIDICatalog {
    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let file: String
            let hymns: [Int]
        }
        let hymnals: [String: Entry]
    }

    /// Hymnal key → hymn number → bundle resource name (no extension).
    private static let resources: [String: [Int: String]] = {
        guard let url = Bundle.main.url(forResource: "midi-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [:] }
        // Synced folders copy resources flat, so the files sit at the bundle root.
        let bundled = Set((Bundle.main.urls(forResourcesWithExtension: "mid", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent })
        return manifest.hymnals.mapValues { entry in
            Dictionary(entry.hymns.compactMap { number in
                let name = String(format: entry.file, number)
                return bundled.contains(name) ? (number, name) : nil
            }, uniquingKeysWith: { first, _ in first })
        }
    }()

    /// The MIDI resource for hymn `number` in `hymnal`, if one ships. An SDA
    /// Hymnal hymn plays its Christ In Song version's file when the two are
    /// sung to the same tune (SDAHTunes).
    static func resource(hymnal: String, number: Int) -> String? {
        if hymnal == HymnalInfo.sdahID {
            return SDAHTunes.cisTune(for: number).flatMap { resources[HymnalInfo.default.id]?[$0] }
        }
        return resources[hymnal]?[number]
    }
}
