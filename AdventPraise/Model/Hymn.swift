//
//  Hymn.swift
//  Advent Praise
//
//  One hymn as the reader shows it. Lyrics come from the bundled per-language
//  JSON (see Hymnal.swift); accompaniment is optional and only present when a
//  matching MIDI file ships in the bundle.
//

import Foundation

struct Hymn: Identifiable, Hashable, Sendable {
    enum Block: Hashable, Sendable {
        case verse(number: Int, lines: [String])
        case chorus(lines: [String])

        var lines: [String] {
            switch self {
            case let .verse(_, lines), let .chorus(lines): lines
            }
        }
    }

    /// The hymn number within its hymnal.
    let id: Int
    let title: String
    /// Cross-references shown in the eyebrow row, e.g. ["AH 350", "SDAH 368"].
    let references: [String]
    /// Verses in order, each distinct chorus stored once where it first appears.
    let blocks: [Block]

    /// Accompaniment: bundle resource name without extension (see MIDICatalog).
    let midiResource: String?

    var number: Int { id }
    var verseCount: Int { blocks.filter { if case .verse = $0 { true } else { false } }.count }
    var hasAccompaniment: Bool { midiResource != nil }

    /// The blocks in the order a congregation sings them: when a hymn has a
    /// single chorus it follows every verse.
    var sungSequence: [Block] {
        let choruses = blocks.filter { if case .chorus = $0 { true } else { false } }
        guard choruses.count == 1, let chorus = choruses.first else { return blocks }
        var result: [Block] = []
        if case .chorus = blocks.first { result.append(chorus) }
        for block in blocks {
            if case .verse = block { result.append(block); result.append(chorus) }
        }
        return result
    }

    /// Plain text for sharing and correction emails.
    func plainText(chorusLabel: String) -> String {
        blocks.map { block in
            switch block {
            case let .verse(number, lines): "\(number).\n" + lines.joined(separator: "\n")
            case let .chorus(lines): "\(chorusLabel):\n" + lines.joined(separator: "\n")
            }
        }
        .joined(separator: "\n\n")
    }
}
