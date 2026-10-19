import Foundation
import SwiftUI
import Testing
@testable import Advent_Praise

/// The SDA Hymnal (1985): bundled whole, picked like any translation, its
/// own numbers, and matched to Christ In Song only by cross-reference.
@MainActor
@Suite(.serialized)
struct SDAHymnalTests {
    private static let keys = ["reader.hymnal", "reader.lastHymn", "reader.lastHymn.sdah",
                               "reader.recents", "reader.recents.sdah"]

    @Test func everyHymnIsThereNumberedOneTo695() throws {
        let info = try #require(HymnalInfo.sdah)
        #expect(info.name == "SDA Hymnal (1985)")
        #expect(info.language == "English")
        #expect(info.hymnCount == 695 && info.maxNumber == 695)
        #expect(info.numbering == .sdah && HymnalInfo.default.numbering == .christInSong)
        let sdah = try #require(Hymnal.load(info))
        #expect(sdah.count == 695)
        #expect(sdah.hymns.map(\.id) == Array(1...695))
        #expect(sdah.hymns.allSatisfy { !$0.title.isEmpty && !$0.blocks.isEmpty })
        #expect(!RemovedHymnals.contains("sdah"))
        #expect(HymnalInfo.catalogue.map(\.designHymnal).filter(\.isOwnBook).map(\.id) == ["sdah"])
    }

    @Test func pickerShowsTheSDAHymnalFirst() {
        let hymnals = HymnalInfo.catalogue.map(\.designHymnal)
        let (ownBooks, translations) = LanguageTileGrid<EmptyView>.ordered(hymnals)
        #expect(ownBooks.map(\.id) == ["sdah"])
        #expect((ownBooks + translations).first?.id == "sdah")
        #expect(translations.map(\.id) == hymnals.filter { !$0.isOwnBook }.map(\.id))
        #expect(ownBooks.count + translations.count == hymnals.count)
    }

    @Test func numberLookupFindsTheSDAHymnalsOwnHymns() throws {
        let sdah = try #require(HymnalInfo.sdah.flatMap(Hymnal.load))
        #expect(sdah.hymn(number: 1)?.title == "Praise to the Lord")
        #expect(sdah.hymn(number: 100)?.title == "Great Is Thy Faithfulness")
        #expect(sdah.hymn(number: 695)?.title == "Praise God, From Whom All Blessings")
        #expect(sdah.hymn(number: 696) == nil)
        #expect(sdah.search("368", inLyrics: false).first?.hymn.title.hasPrefix("Watchman") == true)
        #expect(sdah.search("bleak midwinter", inLyrics: true).first?.hymn.id == 126)
    }

    @Test func crossReferencesMatchByHymnNotByNumber() throws {
        let english = HymnalInfo.default
        let sdah = try #require(HymnalInfo.sdah)
        let shona = try #require(HymnalInfo.with(id: "shona"))
        #expect(HymnalCrossReference.number(1, from: english, to: sdah) == 368)
        #expect(HymnalCrossReference.number(368, from: sdah, to: english) == 1)
        #expect(HymnalCrossReference.number(1, from: shona, to: sdah) == 368)
        #expect(HymnalCrossReference.number(71, from: english, to: sdah) == nil)   // not in the SDA Hymnal
        #expect(HymnalCrossReference.number(1, from: sdah, to: english) == nil)    // "Praise to the Lord" isn't in Christ In Song
        #expect(HymnalCrossReference.number(12, from: english, to: shona) == 12)
        // The SDA Hymnal's own "CIS n" refs agree with the English "SDAH n" ones.
        let loaded = try #require(Hymnal.load(sdah))
        for hymn in loaded.hymns {
            let cis = hymn.references.first { $0.hasPrefix("CIS ") }.flatMap { Int($0.dropFirst(4)) }
            #expect(cis == HymnalCrossReference.cisForSDAH[hymn.id], "SDAH \(hymn.id)")
        }
    }

    @Test func accompanimentAndSheetMusicOnlyForTheSameTune() throws {
        // 368 Watchman, Blow the Gospel Trumpet is sung to CIS 1's tune.
        #expect(MIDICatalog.resource(hymnal: "sdah", number: 368) != nil)
        #expect(MIDICatalog.resource(hymnal: "sdah", number: 368) == MIDICatalog.resource(hymnal: "english", number: 1))
        // 489 Jesus, Lover of My Soul is MARTYN in the SDA Hymnal, ABERYSTWYTH in CIS 59.
        #expect(MIDICatalog.resource(hymnal: "sdah", number: 489) == nil)
        #expect(!SheetMusicCatalog.has(hymnal: "sdah", number: 489))
        // No cross-reference, no music.
        #expect(MIDICatalog.resource(hymnal: "sdah", number: 1) == nil)
        #expect(!SheetMusicCatalog.has(hymnal: "sdah", number: 1))
        // 113 As Pants the Hart isn't in Christ In Song, but is sung to CIS 227's
        // MARTYRDOM: that accompaniment, and its own score with its own words.
        #expect(MIDICatalog.resource(hymnal: "sdah", number: 113) == MIDICatalog.resource(hymnal: "english", number: 227))
        #expect(SheetMusicCatalog.has(hymnal: "sdah", number: 113))
        #expect(SDAHTunes.cisScore(for: 113) == nil)
        #expect(SDAHTunes.cisVersion(for: 113) == nil)
        for n in 1...695 where SheetMusicCatalog.has(hymnal: "sdah", number: n) {
            #expect(SDAHTunes.cisTune(for: n) != nil, "SDAH \(n)")
            #expect(SheetMusicCatalog.timing(hymnal: "sdah", number: n) != nil, "SDAH \(n)")
            #expect(SheetMusicCatalog.page(hymnal: "sdah", number: n, layout: .phone) != nil, "SDAH \(n)")
        }
    }

    @Test func collectionsCoverTheWholeHymnal() {
        let numbers = HymnCollections.available(in: "sdah").flatMap { $0.numbers(in: "sdah") }
        #expect(numbers.sorted() == Array(1...695))
        #expect(HymnCollections.containing(368, hymnal: "sdah").count == 1)
    }

    @Test func theChoiceIsRememberedAndEachNumberingKeepsItsPlace() throws {
        let defaults = UserDefaults.standard
        let saved = Self.keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(Self.keys, saved) { defaults.set(value, forKey: key) } }
        for key in Self.keys { defaults.removeObject(forKey: key) }
        defaults.set("english", forKey: "reader.hymnal")
        defaults.set(1, forKey: "reader.lastHymn")
        let sdah = try #require(HymnalInfo.sdah)

        let model = ReaderModel()
        #expect(model.hymnal.id == "english" && model.hymn.id == 1)
        model.switchHymnal(to: sdah, feedback: nil, source: .translation)
        #expect(model.hymnal.id == "sdah")
        #expect(model.hymn.id == 368)                              // the same hymn, its SDA number
        #expect(defaults.string(forKey: "reader.hymnal") == "sdah")
        #expect(model.open(number: 100, feedback: nil, source: .numpad))
        #expect(model.hymn.title == "Great Is Thy Faithfulness")

        let relaunched = ReaderModel()
        #expect(relaunched.hymnal.id == "sdah" && relaunched.hymn.id == 100)
        #expect(relaunched.recents.first == 100)

        // 100 has no Christ In Song version: back to the last CIS hymn read.
        relaunched.switchHymnal(to: .default, feedback: nil, source: .translation)
        #expect(relaunched.hymnal.id == "english" && relaunched.hymn.id == 1)
        #expect(!relaunched.recents.contains(100))
        #expect(defaults.integer(forKey: "reader.lastHymn.sdah") == 100)
    }
}
