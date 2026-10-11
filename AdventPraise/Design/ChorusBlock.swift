//
//  ChorusBlock.swift
//  Advent Praise 7 — Vesper design system
//
//  The refrain. Stored once per hymn, rendered after every verse (the reader
//  decides how often). Set bold italic in a contrasting family
//  (`DS.ReadingFont.chorusFace`), with a brass eyebrow label and a thin brass
//  rule down its leading edge. The rule sits where the verse text starts, and
//  the chorus is indented past it. Centred, the rule becomes a short dash
//  above the label.
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
    @ScaledMetric(relativeTo: .body) private var dynamicUnit: CGFloat = 1

    var body: some View {
        content
            .opacity(state == .dimmed ? (worship ? 0.38 : DS.Fill.dimmed) : 1)
            .animation(DS.Motion.adaptive(DS.Motion.verse, reduceMotion: reduceMotion), value: state)
            // VoiceOver says "Chorus" in the reader's own language, whatever the hymnal calls it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Chorus") + ". " + displayed)
            .accessibilityValue(state == .current ? Text("Now singing") : Text(""))
    }

    @ViewBuilder private var content: some View {
        let lyric = DSLyricText(displayed, style: style, face: style.font.chorusFace,
                                sizeRatio: style.font.chorusSizeRatio)
        if style.centered {
            VStack(spacing: DS.Space.xs) {
                ChorusRule(color: surface.brass).frame(width: 24, height: 2)
                    .padding(.bottom, DS.Space.xxs)
                ChorusLabel(text: label, isCurrent: state == .current)
                lyric
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ChorusLabel(text: label, isCurrent: state == .current)
                lyric
            }
            .padding(.leading, DS.Space.panel)
            .background(alignment: .leading) {
                ChorusRule(color: surface.brass).frame(width: 2)
            }
            // Line the rule up with the verse text, past the verse numerals.
            .padding(.leading, VerseBadge.size(for: style, dynamicUnit: dynamicUnit) + DS.Space.panel)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var displayed: String {
        guard isCollapsedRepeat, let first = lines.first else { return lines.joined(separator: "\n") }
        return first + " …"
    }
}

/// The chorus's accent: a thin brass rule, quiet enough to do without a box.
struct ChorusRule: View {
    let color: Color
    var body: some View {
        Capsule().fill(color.opacity(0.7)).accessibilityHidden(true)
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
