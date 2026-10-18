//
//  SheetMusicTiming.swift
//  Advent Praise
//
//  When each part of a hymn's score sounds in its accompaniment, and where it
//  sits on the page, so the sheet music can follow the MIDI player the way
//  the reader's lyrics do. Built ahead of time (Tools/sheet-music/sync.py):
//  the score's melody, repeats unfolded, is matched note by note to the MIDI
//  file's top line, so every measure and note has a time in seconds into one
//  pass through the file, at its written tempo. That is the clock
//  HymnMIDIEngine keeps (its `elapsed` runs at the written tempo, whatever
//  the tempo setting), and the engine plays the file once per verse, so the
//  timing simply repeats for each verse.
//
//  JSON (one deflated chunk per hymn in sheet-music-sync.pack):
//      len    one pass through the MIDI file, seconds
//      match  share of the melody matched to the MIDI
//      m      [[t, measure], …] measure starts in performance order
//      e      [[t, note], …] note onsets (staff 1, both voices), in time order
//      l, nm  each note's voice (0 is the melody) and measure
//      v      the app's verse number on lyric line 1, 2, …
//      geo    {"phone"|"pad": {"ss": staff space,
//              "sy": [[x, y, w, h], …] systems: bands from halfway to the previous system to halfway to the next,
//              "ms": [system, …] each measure's system,
//              "m": [[x, y, w, h], …] measure boxes (staves and verses),
//              "n": [[x, y, [[line, x, y, w, size], …]], …] noteheads and their syllables}}
//  Coordinates are the page's SVG units. A hymn whose notes couldn't be
//  matched to the drawing one for one has no `e` or `n`: it follows by measure.
//

import Foundation

struct SheetMusicTiming: Sendable, Equatable {
    struct Box: Sendable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    struct Syllable: Sendable, Equatable {
        /// Lyric line, from 1.
        let line: Int
        let x: Double
        /// Baseline.
        let y: Double
        let width: Double
        let size: Double
    }

    struct Note: Sendable, Equatable {
        let x: Double
        let y: Double
        let syllables: [Syllable]
    }

    struct Geometry: Sendable, Equatable {
        /// Distance between staff lines.
        var staffSpace: Double = 9
        let measures: [Box]
        let notes: [Note]
        /// Lines of music, top to bottom: each a band of the page.
        var systems: [Box] = []
        /// Each measure's system.
        var measureSystems: [Int] = []

        /// The system measure `measure` is in (0 when unknown).
        func system(ofMeasure measure: Int) -> Int {
            guard measureSystems.indices.contains(measure) else { return 0 }
            return measureSystems[measure]
        }

        /// The first measure of system `system`, or nil past the end.
        func firstMeasure(ofSystem system: Int) -> Int? {
            measureSystems.firstIndex(of: system)
        }

        /// The widest system's left edge and width, so every system shows at one size.
        var systemExtent: (x: Double, width: Double) {
            guard let left = systems.map(\.x).min(), let right = systems.map({ $0.x + $0.width }).max() else { return (0, 0) }
            return (left, right - left)
        }
    }

    /// What's sounding: the measure, the melody note and the syllable being sung.
    struct Cue: Sendable, Equatable {
        let measure: Int
        let note: Int?
        /// The note carrying the syllable, and its lyric line.
        let syllableNote: Int?
        let syllableLine: Int?
    }

    let passLength: Double
    let match: Double
    let measureTimes: [Double]
    let measureOrder: [Int]
    let noteTimes: [Double]
    let noteOrder: [Int]
    let noteVoices: [Int]
    let noteMeasures: [Int]
    let verseNumbers: [Int]
    let geometry: [SheetMusicLayout: Geometry]

    var followsNotes: Bool { !noteTimes.isEmpty && !noteVoices.isEmpty }

    init(passLength: Double, match: Double = 1, measureTimes: [Double], measureOrder: [Int],
         noteTimes: [Double] = [], noteOrder: [Int] = [], noteVoices: [Int] = [], noteMeasures: [Int] = [],
         verseNumbers: [Int] = [], geometry: [SheetMusicLayout: Geometry]) {
        self.passLength = passLength
        self.match = match
        self.measureTimes = measureTimes
        self.measureOrder = measureOrder
        self.noteTimes = noteTimes
        self.noteOrder = noteOrder
        self.noteVoices = noteVoices
        self.noteMeasures = noteMeasures
        self.verseNumbers = verseNumbers
        self.geometry = geometry
    }

    init?(json data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let length = (root["len"] as? NSNumber)?.doubleValue,
              let measures = root["m"] as? [[NSNumber]], !measures.isEmpty,
              let geo = root["geo"] as? [String: [String: Any]] else { return nil }
        let events = root["e"] as? [[NSNumber]] ?? []
        var geometry: [SheetMusicLayout: Geometry] = [:]
        for layout in SheetMusicLayout.allCases {
            guard let entry = geo[layout.rawValue], let boxes = entry["m"] as? [[NSNumber]] else { continue }
            let measureBoxes = boxes.compactMap { b -> Box? in
                guard b.count == 4 else { return nil }
                return Box(x: b[0].doubleValue, y: b[1].doubleValue, width: b[2].doubleValue, height: b[3].doubleValue)
            }
            let notes = (entry["n"] as? [[Any]] ?? []).compactMap { n -> Note? in
                guard n.count == 3, let x = (n[0] as? NSNumber)?.doubleValue, let y = (n[1] as? NSNumber)?.doubleValue else { return nil }
                let syllables = (n[2] as? [[NSNumber]] ?? []).compactMap { s -> Syllable? in
                    guard s.count == 5 else { return nil }
                    return Syllable(line: s[0].intValue, x: s[1].doubleValue, y: s[2].doubleValue,
                                    width: s[3].doubleValue, size: s[4].doubleValue)
                }
                return Note(x: x, y: y, syllables: syllables)
            }
            let systems = (entry["sy"] as? [[NSNumber]] ?? []).compactMap { b -> Box? in
                guard b.count == 4 else { return nil }
                return Box(x: b[0].doubleValue, y: b[1].doubleValue, width: b[2].doubleValue, height: b[3].doubleValue)
            }
            var measureSystems = (entry["ms"] as? [NSNumber] ?? []).map(\.intValue)
            if measureSystems.count != measureBoxes.count || measureSystems.contains(where: { !systems.indices.contains($0) }) {
                measureSystems = []
            }
            geometry[layout] = Geometry(staffSpace: (entry["ss"] as? NSNumber)?.doubleValue ?? 9,
                                        measures: measureBoxes, notes: notes,
                                        systems: measureSystems.isEmpty ? [] : systems, measureSystems: measureSystems)
        }
        guard !geometry.isEmpty else { return nil }
        self.init(passLength: length,
                  match: (root["match"] as? NSNumber)?.doubleValue ?? 0,
                  measureTimes: measures.map { $0[0].doubleValue },
                  measureOrder: measures.map { $0[1].intValue },
                  noteTimes: events.map { $0[0].doubleValue },
                  noteOrder: events.map { $0[1].intValue },
                  noteVoices: (root["l"] as? [NSNumber] ?? []).map(\.intValue),
                  noteMeasures: (root["nm"] as? [NSNumber] ?? []).map(\.intValue),
                  verseNumbers: (root["v"] as? [NSNumber] ?? []).map(\.intValue),
                  geometry: geometry)
    }

    // MARK: Following the player

    /// Seconds into the current pass, from the engine's elapsed time across
    /// every verse and its length; nil before anything is loaded.
    static func passOffset(elapsed: Double, duration: Double, passes: Int) -> Double? {
        guard passes > 0, duration > 0 else { return nil }
        let pass = duration / Double(passes)
        let index = min(max(Int(elapsed / pass), 0), passes - 1)
        return min(max(elapsed - Double(index) * pass, 0), pass)
    }

    /// The pass (0-based) the engine is in.
    static func passIndex(elapsed: Double, duration: Double, passes: Int) -> Int {
        guard passes > 0, duration > 0 else { return 0 }
        return min(max(Int(elapsed / (duration / Double(passes))), 0), passes - 1)
    }

    /// Lyric line that carries app verse `verse`; line 1 for a chorus or a verse not under the music.
    func lyricLine(forVerse verse: Int?) -> Int {
        guard let verse, let index = verseNumbers.firstIndex(of: verse) else { return 1 }
        return index + 1
    }

    /// Last index with `times[i] <= t`, or nil.
    private static func lastIndex(_ times: [Double], atOrBefore t: Double) -> Int? {
        var low = 0, high = times.count
        while low < high {
            let mid = (low + high) / 2
            if times[mid] <= t { low = mid + 1 } else { high = mid }
        }
        return low > 0 ? low - 1 : nil
    }

    /// What's sounding `offset` seconds into a pass while verse `verse` is sung.
    func cue(at offset: Double, verse: Int?) -> Cue {
        let mIndex = Self.lastIndex(measureTimes, atOrBefore: offset + 0.02) ?? 0
        let measure = measureOrder[mIndex]
        let start = measureTimes[mIndex]
        guard followsNotes, let notes = geometry[.phone]?.notes ?? geometry.values.first?.notes,
              let last = Self.lastIndex(noteTimes, atOrBefore: offset + 0.02) else {
            return Cue(measure: measure, note: nil, syllableNote: nil, syllableLine: nil)
        }
        let line = lyricLine(forVerse: verse)
        var note: Int?
        var syllableNote: Int?
        var syllableLine: Int?
        var index = last
        while index >= 0, noteTimes[index] >= start - 0.001 {
            let n = noteOrder[index]
            if note == nil, noteVoices.indices.contains(n), noteVoices[n] == 0,
               noteMeasures.indices.contains(n), noteMeasures[n] == measure {
                note = n
            }
            if syllableNote == nil, notes.indices.contains(n), let found = Self.syllableLine(of: notes[n], line: line) {
                syllableNote = n
                syllableLine = found
            }
            if note != nil, syllableNote != nil { break }
            index -= 1
        }
        return Cue(measure: measure, note: note, syllableNote: syllableNote, syllableLine: syllableLine)
    }

    /// The note's syllable on `line`, or the one line all verses share (a refrain written once).
    static func syllableLine(of note: Note, line: Int) -> Int? {
        if note.syllables.contains(where: { $0.line == line }) { return line }
        if note.syllables.count == 1, note.syllables[0].line == 1 { return 1 }
        return nil
    }

    /// Where to seek, in seconds into the pass, for a tap on `measure` while
    /// at `offset`: the next time it's played, else the latest (a repeat being played again).
    func seekOffset(toMeasure measure: Int, from offset: Double) -> Double? {
        let times = zip(measureTimes, measureOrder).filter { $0.1 == measure }.map(\.0)
        guard !times.isEmpty else { return nil }
        return times.first(where: { $0 >= offset }) ?? times.last
    }

    /// The measure under a point on the page (SVG units), or nil.
    func measure(atX x: Double, y: Double, layout: SheetMusicLayout) -> Int? {
        guard let boxes = geometry[layout]?.measures else { return nil }
        var best: (Int, Double)?
        for (index, box) in boxes.enumerated() {
            guard x >= box.x, x <= box.x + box.width,
                  y >= box.y - box.height * 0.2, y <= box.y + box.height * 1.2 else { continue }
            let distance = abs(y - (box.y + box.height / 2))
            if best == nil || distance < best!.1 { best = (index, distance) }
        }
        return best?.0
    }
}

// MARK: - System by system

/// Page or one system at a time, in the full-screen viewer. Remembered.
enum SheetMusicViewMode: String, CaseIterable, Sendable {
    case page, system
}

/// Where the page sits so one system (a band of it) fills a rectangle of the
/// view: a scale, a translation and a clip, in CSS pixels (points).
struct SheetMusicSystemFrame: Equatable, Sendable {
    let scale: Double
    let x: Double
    let y: Double
    /// The page's width once scaled.
    let width: Double
    let clipTop: Double
    let clipRight: Double
    let clipBottom: Double
    let clipLeft: Double

    /// `band` fitted into `rect` (centred, as large as fits), every system at
    /// the size that makes `extent` (the widest system) fill the width.
    static func fit(band: SheetMusicTiming.Box, extent: (x: Double, width: Double),
                    pageWidth: Double, pageHeight: Double,
                    in rect: CGRect) -> SheetMusicSystemFrame? {
        guard band.width > 0, band.height > 0, extent.width > 0, rect.width > 0, rect.height > 0 else { return nil }
        let scale = min(Double(rect.width) / extent.width, Double(rect.height) / band.height)
        let x = Double(rect.minX) + (Double(rect.width) - extent.width * scale) / 2 - extent.x * scale
        let y = Double(rect.minY) + (Double(rect.height) - band.height * scale) / 2 - band.y * scale
        return SheetMusicSystemFrame(scale: scale, x: x, y: y, width: pageWidth * scale,
                                     clipTop: band.y * scale,
                                     clipRight: max(0, pageWidth - band.x - band.width) * scale,
                                     clipBottom: max(0, pageHeight - band.y - band.height) * scale,
                                     clipLeft: band.x * scale)
    }

    /// A point in the view, in the page's SVG units.
    func pagePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (Double(point.x) - x) / scale, y: (Double(point.y) - y) / scale)
    }

    /// For the page's script.
    var script: String {
        String(format: "{\"w\":%.2f,\"tx\":%.2f,\"ty\":%.2f,\"ct\":%.2f,\"cr\":%.2f,\"cb\":%.2f,\"cl\":%.2f}",
               width, x, y, clipTop, clipRight, clipBottom, clipLeft)
    }
}
