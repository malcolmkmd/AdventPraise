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
        #expect(total == 221)
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

    // MARK: System by system

    @Test func everyPageSplitsIntoSystemsThatHoldTheirMeasures() throws {
        for number in 1...300 where SheetMusicCatalog.has(hymnal: "english", number: number) {
            let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: number))
            for layout in SheetMusicLayout.allCases {
                let g = try #require(timing.geometry[layout])
                #expect(!g.systems.isEmpty, "hymn \(number) \(layout)")
                #expect(g.measureSystems.count == g.measures.count)
                #expect(g.measureSystems == g.measureSystems.sorted(), "hymn \(number) \(layout)")
                #expect(Set(g.measureSystems) == Set(g.systems.indices), "hymn \(number) \(layout)")
                // Bands run top to bottom without gaps, and each measure sits inside its own.
                #expect(g.systems.first?.y == 0)
                for (a, b) in zip(g.systems, g.systems.dropFirst()) {
                    #expect(abs(a.y + a.height - b.y) < 0.2, "hymn \(number) \(layout)")
                }
                for (box, system) in zip(g.measures, g.measureSystems) {
                    let band = g.systems[system]
                    #expect(box.y >= band.y && box.y + box.height <= band.y + band.height + 0.1, "hymn \(number) \(layout)")
                }
                #expect(g.systemExtent.width > 0)
            }
        }
    }

    @Test func systemNavigationByMeasure() throws {
        let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: 100))
        let g = try #require(timing.geometry[.phone])
        #expect(g.systems.count == 5)                  // 2 + 3 + 4 + 4 + 3 measures on a phone page
        #expect(g.system(ofMeasure: 0) == 0)
        #expect(g.system(ofMeasure: 5) == 2)           // "car-ry", measure 6, starts the third line
        #expect(g.firstMeasure(ofSystem: 1) == g.measureSystems.firstIndex(of: 1))
        #expect(g.firstMeasure(ofSystem: g.systems.count) == nil)
        #expect(g.system(ofMeasure: 999) == 0)
        // Playing measure 6 shows its system.
        let cue = timing.cue(at: 13, verse: 1)
        #expect(g.system(ofMeasure: cue.measure) == g.measureSystems[5])
    }

    @Test func aSystemFillsTheWidthAndTapsMapBack() throws {
        let band = SheetMusicTiming.Box(x: 0, y: 360, width: 798, height: 370)
        let rect = CGRect(x: 48, y: 120, width: 306, height: 600)
        let frame = try #require(SheetMusicSystemFrame.fit(band: band, extent: (0, 798), pageWidth: 798, pageHeight: 1665, in: rect))
        #expect(abs(frame.scale - 306.0 / 798) < 1e-9)            // width-limited
        #expect(abs(frame.width - 306) < 1e-9)
        #expect(abs(frame.x - 48) < 1e-9)
        // Centred vertically in the rectangle.
        let top = frame.y + band.y * frame.scale
        #expect(abs(top - (120 + (600 - 370 * frame.scale) / 2)) < 1e-9)
        #expect(abs(frame.clipTop - 360 * frame.scale) < 1e-9)
        #expect(abs(frame.clipBottom - (1665 - 730) * frame.scale) < 1e-9)
        #expect(frame.clipLeft == 0 && frame.clipRight == 0)
        // A tap at the band's centre is the band's centre on the page.
        let point = frame.pagePoint(CGPoint(x: frame.x + 399 * frame.scale, y: frame.y + 545 * frame.scale))
        #expect(abs(point.x - 399) < 1e-6 && abs(point.y - 545) < 1e-6)
        #expect(frame.script.hasPrefix("{\"w\":306.00"))
        // Landscape: height-limited, centred across.
        let wide = try #require(SheetMusicSystemFrame.fit(band: band, extent: (0, 798), pageWidth: 798, pageHeight: 1665,
                                                          in: CGRect(x: 0, y: 0, width: 800, height: 250)))
        #expect(abs(wide.scale - 250.0 / 370) < 1e-9)
        #expect(abs(wide.x - (800 - 798 * wide.scale) / 2) < 1e-9)
        #expect(SheetMusicSystemFrame.fit(band: band, extent: (0, 0), pageWidth: 798, pageHeight: 1665, in: rect) == nil)
    }

    @Test func systemsOnAnUprightPhoneUseTheShortLines() throws {
        #expect(SheetMusicLayout.forSystems(width: 402) == .line)
        #expect(SheetMusicLayout.forSystems(width: 599) == .line)
        #expect(SheetMusicLayout.forSystems(width: 734) == .phone)   // landscape
        #expect(SheetMusicLayout.forSystems(width: 1032) == .phone)  // iPad
        // The whole page never uses them.
        #expect(SheetMusicLayout.forWidth(320) == .phone)
        let timing = try #require(SheetMusicCatalog.timing(hymnal: "english", number: 100))
        let line = try #require(timing.geometry[.line]), phone = try #require(timing.geometry[.phone])
        #expect(line.systems.count > phone.systems.count)
        // A short line fills an upright phone about half as large again as a phone page's line.
        let width = 402.0
        let lineScale = width / line.systemExtent.width, phoneScale = width / phone.systemExtent.width
        #expect(lineScale / phoneScale > 1.35)
    }

    @Test func viewModeIsRememberedByName() {
        #expect(SheetMusicViewMode(rawValue: "page") == .page)
        #expect(SheetMusicViewMode(rawValue: "system") == .system)
        #expect(SheetMusicViewMode.allCases.count == 2)
    }
}
