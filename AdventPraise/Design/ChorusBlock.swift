//
//  ChorusBlock.swift
//  Advent Praise 7 — Vesper design system
//
//  The refrain. Stored once per hymn, rendered after every verse (the reader
//  decides how often). Italic lyric, brass eyebrow label, indented to sit
//  under the verse text rather than under the numerals.
//
//  The label is the hymnal's own word for "Chorus" (cis-v2 `refrain_label`,
//  e.g. Tonga "Ciindululo") — never hard-code the English.
//
//  No glass: when the chorus is current (worship / playback) its label sits in
//  a brass wash capsule. Lyrics are content, never glass.
//

import SwiftUI

struct ChorusBlock: View {
    let lines: [String]
    var label: String = String(localized: "Chorus")
    var style = DSReadingStyle()
    var state: DSBlockState = .normal
    /// Second and later repeats can collapse to the first line + "…" to save space.
    var isCollapsedRepeat = false

    @Environment(\.dsSurface) private var surface
    @Environment(\.dsWorshipMode) private var worship
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: style.horizontalAlignment, spacing: DS.Space.xs) {
            ChorusLabel(text: label, isCurrent: state == .current)
            DSLyricText(displayed, style: style, italic: true)
        }
        .frame(maxWidth: .infinity, alignment: style.frameAlignment)
        .padding(.leading, style.centered ? 0 : DS.Space.chorusIndent)
        .opacity(state == .dimmed ? (worship ? 0.38 : DS.Fill.dimmed) : 1)
        .animation(DS.Motion.adaptive(DS.Motion.verse, reduceMotion: reduceMotion), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .current ? Text("Now singing") : Text(""))
    }

    private var displayed: String {
        guard isCollapsedRepeat, let first = lines.first else { return lines.joined(separator: "\n") }
        return first + " …"
    }
}

private struct ChorusLabel: View {
    let text: String
    let isCurrent: Bool
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Text(text)
            .dsEyebrow(tracking: 1.5)
            .foregroundStyle(surface.brass)
            .padding(.horizontal, isCurrent ? 10 : 0)
            .padding(.vertical, isCurrent ? DS.Space.xxs : 0)
            .background(Capsule().fill(surface.brass.opacity(isCurrent ? DS.Fill.tintOn : 0)))
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("ChorusBlock") {
    ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.block) {
            ChapterVerseBlock(number: 1, lines: ["Blessed assurance, Jesus is mine!",
                                                  "Oh, what a foretaste of glory divine!"])
            ChorusBlock(lines: ["This is my story, this is my song,",
                                "Praising my Saviour all the day long;"])
            ChapterVerseBlock(number: 2, lines: ["Perfect submission, perfect delight,"], state: .dimmed)
            ChorusBlock(lines: ["This is my story, this is my song,",
                                "Praising my Saviour all the day long;"],
                        state: .current, isCollapsedRepeat: true)
            // Label from cis-v2 tonga `refrain_label`; lyric is placeholder English.
            ChorusBlock(lines: ["This is my story, this is my song,"], label: "Ciindululo",
                        style: DSReadingStyle(centered: true))
        }
        .padding(.horizontal, DS.Space.gutter)
        .padding(.top, DS.Space.top)
    }
    .dsSurface(.sepia)
}
