//
//  SheetMusicSyncTests.swift
//  AdventPraiseTests
//
//  The full-screen viewer's layout choice and its timing against the MIDI
//  player: every shipped hymn has timing that fits its pages, the clock maps
//  verse by verse, repeats seek to the right pass, taps find their measure.
//

import Foundation
import Testing
@testable import Advent_Praise

struct SheetMusicSyncTests {
    @Test func padPagesFrom700Points() {
        #expect(SheetMusicLayout.forWidth(402) == .phone)      // iPhone 17 Pro, portrait
        #expect(SheetMusicLayout.forWidth(699) == .phone)
        #expect(SheetMusicLayout.forWidth(700) == .pad)
        #expect(SheetMusicLayout.forWidth(734) == .pad)        // iPhone 14 Pro on its side, inside the safe area
        #expect(SheetMusicLayout.forWidth(1032) == .pad)       // iPad
    }

    @Test func everyShippedHymnHasTimingThatFitsItsPages() throws {
        var withNotes = 0, total = 0
        for number in 1...300 where SheetMusicCatalog.has(hymnal: "english", number: number) {
            total += 1
            let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: number), "hymn \(number)")
            #expect(timing.passLength > 0)
            #expect(timing.match >= 0.85, "hymn \(number) matched \(timing.match)")
            #expect(timing.measureTimes == timing.measureTimes.sorted(), "hymn \(number)")
            #expect(timing.measureTimes.first == 0)
            #expect((timing.measureTimes.last ?? 0) < timing.passLength, "hymn \(number)")
            #expect(timing.noteTimes == timing.noteTimes.sorted(), "hymn \(number)")
            for layout in SheetMusicLayout.allCases {
                let geometry = try #require(timing.geometry[layout], "hymn \(number) \(layout)")
                #expect(geometry.staffSpace > 0)
                #expect(timing.measureOrder.allSatisfy { geometry.measures.indices.contains($0) }, "hymn \(number) \(layout)")
                let page = try #require(SheetMusicCatalog.page(hymnal: "english", number: number, layout: layout))
                #expect(geometry.measures.allSatisfy { $0.x >= 0 && $0.x + $0.width <= page.width + 1 && $0.y + $0.height <= page.height + 1 },
                        "hymn \(number) \(layout)")
                if timing.followsNotes {
                    #expect(geometry.notes.count == timing.noteVoices.count, "hymn \(number) \(layout)")
                }
            }
            if timing.followsNotes {
                withNotes += 1
                #expect(timing.noteOrder.allSatisfy { timing.noteVoices.indices.contains($0) })
            }
        }
        #expect(total == 189)
        // Three hymns' drawings don't pair with their notes one for one; they follow by measure.
        #expect(withNotes >= 185)
    }

    @Test func theClockRepeatsForEachVerse() {
        // Three verses of a 40 s tune.
        #expect(SheetMusicTiming.passOffset(elapsed: 50, duration: 120, passes: 3) == 10)
        #expect(SheetMusicTiming.passIndex(elapsed: 50, duration: 120, passes: 3) == 1)
        #expect(SheetMusicTiming.passOffset(elapsed: 120, duration: 120, passes: 3) == 40)
        #expect(SheetMusicTiming.passIndex(elapsed: 120, duration: 120, passes: 3) == 2)
        #expect(SheetMusicTiming.passOffset(elapsed: 5, duration: 0, passes: 0) == nil)
    }

    @Test func followsWhatAFriendByMeasureNoteAndSyllable() throws {
        let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: 100))
        #expect(timing.verseNumbers == [1, 2, 3])
        #expect(timing.lyricLine(forVerse: 2) == 2)
        #expect(timing.lyricLine(forVerse: nil) == 1)
        // 13 s in: the sixth measure, "car-ry" / "-cour-aged" / "re-fuge".
        let cue = timing.cue(at: 13, verse: 2)
        #expect(cue.measure == 5)
        #expect(cue.note != nil)
        #expect(cue.syllableLine == 2)
        let geometry = try #require(timing.geometry[.phone])
        let highlight = SheetMusicHighlight(cue: cue, geometry: geometry)
        #expect(highlight.measure != nil && highlight.note != nil && highlight.syllable != nil)
        #expect(highlight.script.hasPrefix("{\"m\":{"))
        // The start is the first measure.
        #expect(timing.cue(at: 0, verse: 1).measure == 0)
        // A tap in the middle of measure 6 finds it, and seeks to its start.
        let box = geometry.measures[5]
        #expect(timing.measure(atX: box.x + box.width / 2, y: box.y + box.height / 2, layout: .phone) == 5)
        #expect(timing.measure(atX: -50, y: -50, layout: .phone) == nil)
        let seek = try #require(timing.seekOffset(toMeasure: 5, from: 0))
        #expect(abs(seek - 12.24) < 0.05)
    }

    @Test func repeatsSeekToTheRightPass() throws {
        // He Leadeth Me: the refrain repeats (measures 9 to 12, then a second ending).
        let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: 33))
        #expect(timing.measureOrder.filter { $0 == 9 }.count == 2)
        let first = try #require(timing.seekOffset(toMeasure: 9, from: 5))
        let again = try #require(timing.seekOffset(toMeasure: 9, from: 20))
        let back = try #require(timing.seekOffset(toMeasure: 9, from: 30))
        #expect(first < again)
        #expect(again == back)       // in the repeat, back to its start
        #expect(timing.cue(at: again + 0.1, verse: 1).measure == 9)
    }

    @Test func timingParsesItsJSON() throws {
        let json = """
        {"len": 10, "match": 1, "m": [[0, 0], [5, 1]], "e": [[0, 0], [5, 1]], "l": [0, 0], "nm": [0, 1], "v": [1, 2],
         "geo": {"phone": {"ss": 9, "m": [[0, 0, 100, 50], [100, 0, 100, 50]],
                           "n": [[10, 20, [[1, 8, 60, 20, 12], [2, 8, 75, 20, 12]]], [110, 20, [[1, 108, 60, 20, 12]]]]}}}
        """
        let timing = try #require(SheetMusicTiming(json: Data(json.utf8)))
        #expect(timing.cue(at: 6, verse: 2) == .init(measure: 1, note: 1, syllableNote: 1, syllableLine: 1))
        #expect(timing.cue(at: 1, verse: 2) == .init(measure: 0, note: 0, syllableNote: 0, syllableLine: 2))
        #expect(timing.geometry[.pad] == nil)
        #expect(SheetMusicTiming(json: Data("{}".utf8)) == nil)
    }
}
