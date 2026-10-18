//
//  HymnStories.swift
//  Advent Praise
//
//  A short, sourced note on who wrote a hymn and where it came from.
//  Data: Resources/Extras/hymn_stories.json (ships empty), e.g.
//
//      "english": { "12": { "words": "…", "music": "…", "year": "…",
//                           "story": "…", "sources": ["…"] } }
//
//  Every field is optional; the sheet shows whatever is present.
//

import Foundation

struct HymnStory: Decodable, Hashable, Sendable {
    /// Author of the words (and translator, if any).
    var words: String?
    /// Composer or tune name.
    var music: String?
    var year: String?
    /// A few sentences on how the hymn came to be.
    var story: String?
    /// Where the facts above come from.
    var sources: [String]?

    var isEmpty: Bool {
        [words, music, year, story].allSatisfy { ($0 ?? "").isEmpty } && (sources ?? []).isEmpty
    }
}

enum HymnStories {
    private static let file: PerHymnFile<HymnStory> = ExtrasBundle.decode("hymn_stories") ?? .empty

    static func story(hymnal: String, number: Int) -> HymnStory? {
        if let own = file.entry(hymnal: hymnal, number: number), !own.isEmpty { return own }
        // An SDA Hymnal hymn sung to its Christ In Song version's tune shares
        // that version's note (written from the SDA Hymnal's own credits).
        if hymnal == HymnalInfo.sdahID, let cis = SDAHTunes.cisTune(for: number) {
            return story(hymnal: HymnalInfo.default.id, number: cis)
        }
        return nil
    }
}
