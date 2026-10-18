import Foundation
import Testing
@testable import Advent_Praise

/// The sheet music button beside the globe shows only for a hymn that has
/// sheet music in the hymnal being read.
@MainActor
@Suite(.serialized)
struct ReaderSheetMusicButtonTests {
    private static let keys = ["reader.hymnal", "reader.lastHymn", "reader.lastHymn.sdah",
                               "reader.recents", "reader.recents.sdah"]

    @Test func theButtonFollowsTheHymnOnScreen() throws {
        let defaults = UserDefaults.standard
        let saved = Self.keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(Self.keys, saved) { defaults.set(value, forKey: key) } }
        defaults.set("english", forKey: "reader.hymnal")
        defaults.set(1, forKey: "reader.lastHymn")

        let model = ReaderModel()
        #expect(model.hymn.id == 1 && model.hasSheetMusic)              // CIS 1 has a score
        #expect(model.open(number: 4, feedback: nil, source: .numpad))
        #expect(!model.hasSheetMusic)                                     // CIS 4 has none
        #expect(model.open(number: 1, feedback: nil, source: .numpad))

        // SDA Hymnal: 368 is CIS 1's public domain tune, so it has the score.
        model.switchHymnal(to: try #require(HymnalInfo.sdah), feedback: nil, source: .translation)
        #expect(model.hymn.id == 368 && model.hasSheetMusic)
        #expect(model.open(number: 489, feedback: nil, source: .numpad))
        #expect(!model.hasSheetMusic)                                     // another tune than CIS 59
        #expect(model.open(number: 1, feedback: nil, source: .numpad))
        #expect(!model.hasSheetMusic)                                     // not in Christ In Song

        // Every hymn agrees with the catalogue, in every hymnal.
        for info in HymnalInfo.catalogue {
            guard let hymnal = Hymnal.load(info) else { continue }
            let withMusic = hymnal.hymns.filter { SheetMusicCatalog.has(hymnal: info.id, number: $0.id) }.count
            if info.id == "english" { #expect(withMusic == SheetMusicCatalog.count(hymnal: "english")) }
            if info.id != "english" && info.id != "sdah" { #expect(withMusic == 0, "\(info.id)") }
        }
    }
}
