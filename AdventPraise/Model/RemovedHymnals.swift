//
//  RemovedHymnals.swift
//  Advent Praise
//
//  Hymnals the 7.0 betas shipped and 7.0 doesn't: it relaunches with the
//  nine 6.3 listed. Saved state that names one of these (the open hymnal,
//  favourites, playlists, service plans) falls back to English. The originals
//  stay in UserDefaults, untouched, in case a hymnal comes back. (The SDA
//  Hymnal did: it is bundled again, and its saved state reappears with it.)
//
//  Tools/convert_hymnals.py --all can still build their files.
//

import Foundation

struct RemovedHymnals {
    /// Key → language, for naming the English copies of playlists and plans.
    static let languages: [String: String] = [
        "twi": "Twi", "pt": "Português", "es": "Español", "ru": "Русский",
        "dg": "Français", "kinyarwanda": "Kinyarwanda", "tumbuka": "Tumbuka", "abagusii": "Abagusii",
        "tonga": "Tonga", "dholuo": "Dholuo", "xitsonga": "Xitsonga", "sepedi": "Sepedi",
        "gikuyu": "Kikuyu", "icibemba": "Icibemba", "swahili": "Swahili",
    ]

    /// Numbered like Christ In Song up to this hymn (as in Tools/build_collections.py).
    private static let cisNumbered: [String: Int] = [
        "xitsonga": 300, "tonga": 300, "tumbuka": 300, "sepedi": 300, "icibemba": 300, "kinyarwanda": 200,
    ]

    static func contains(_ key: String) -> Bool { languages[key] != nil }

    private let english: Hymnal

    init(english: Hymnal) {
        self.english = english
    }

    /// The English hymn that is hymn `number` of `key`, or nil when no match
    /// is known (the hymnals with their own numbering).
    func englishNumber(_ number: Int, in key: String) -> Int? {
        let mapped: Int? = if let last = Self.cisNumbered[key], number <= last {
            number
        } else {
            nil
        }
        return mapped.flatMap { english.hymn(number: $0)?.id }
    }

    /// "Sabbath · Tonga"
    static func copyName(_ name: String, from key: String) -> String {
        "\(name) · \(languages[key] ?? key)"
    }
}
