//
//  ChapterVerseBlock.swift
//  Advent Praise 7 — Vesper design system
//
//  A numbered verse of a hymn. The numeral is brass serif in a 26 pt circle
//  that scales with the lyric size. During playback or worship mode one verse
//  is *current* (brass badge, full opacity) and the others are dimmed.
//
//  No glass: lyrics are content, so the current-verse badge is a 14 % brass
//  wash on every OS version.
//

import SwiftUI

enum DSBlockState: Equatable, Sendable {
    case normal, current, dimmed
}

struct ChapterVerseBlock: View {
    let number: Int
    let lines: [String]
    var style = DSReadingStyle()
    var state: DSBlockState = .normal
    /// While accompaniment plays: the line being sung, picked out in brass.
    var currentLine: Int? = nil

    @Environment(\.dsSurface) private var surface
    @Environment(\.dsWorshipMode) private var worship
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var dynamicUnit: CGFloat = 1

    private var litLine: Int? { state == .current ? currentLine : nil }
    private var badge: CGFloat { VerseBadge.size(for: style, dynamicUnit: dynamicUnit) }

    var body: some View {
        Group {
            if style.centered {
                VStack(spacing: DS.Space.xs) {
                    VerseBadge(number: number, isCurrent: state == .current, size: badge)
                    DSLyricText(lines.joined(separator: "\n"), style: style, highlightedLine: litLine)
                }
            } else {
                HStack(alignment: .top, spacing: DS.Space.panel) {
                    VerseBadge(number: number, isCurrent: state == .current, size: badge)
                        .padding(.top, DS.Space.hair)
                    DSLyricText(lines.joined(separator: "\n"), style: style, highlightedLine: litLine)
                }
            }
        }
        .opacity(state == .dimmed ? (worship ? 0.38 : DS.Fill.dimmed) : 1)
        .animation(DS.Motion.adaptive(DS.Motion.verse, reduceMotion: reduceMotion), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .current ? Text("Now singing") : Text(""))
    }
}

struct VerseBadge: View {
    let number: Int
    var isCurrent = false
    var size: CGFloat = DS.Size.verseBadge
    @Environment(\.dsSurface) private var surface

    /// Badge grows with the lyric size: 26 pt at 19 pt text.
    static func size(for style: DSReadingStyle, dynamicUnit: CGFloat) -> CGFloat {
        let lyric = style.basePointSize * min(dynamicUnit, style.scale.dynamicTypeCap)
        return max(DS.Size.verseBadge, lyric * 1.35)
    }

    var body: some View {
        Text(String(number))
            .font(.system(size: size * 0.58, weight: isCurrent ? .semibold : .medium, design: .serif))
            .monospacedDigit()
            .foregroundStyle(isCurrent ? surface.brass : surface.secondary)
            .frame(width: size, height: size)
            .background(Circle().fill(surface.brass.opacity(isCurrent ? DS.Fill.tintOn : 0)))
            .accessibilityLabel("Verse \(number)")
    }
}

#Preview("ChapterVerseBlock") {
    ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.block) {
            ChapterVerseBlock(number: 1, lines: ["Blessed assurance, Jesus is mine!",
                                                  "Oh, what a foretaste of glory divine!"], state: .dimmed)
            ChapterVerseBlock(number: 2, lines: ["Perfect submission, perfect delight,",
                                                  "Visions of rapture now burst on my sight;"], state: .current)
            ChapterVerseBlock(number: 3, lines: ["Perfect submission, all is at rest,",
                                                  "I in my Saviour am happy and blest,"],
                              style: DSReadingStyle(font: .sans, lineSpacing: .relaxed))
            ChapterVerseBlock(number: 4, lines: ["Centered alignment puts the numeral above."],
                              style: DSReadingStyle(centered: true))
        }
        .padding(.horizontal, DS.Space.gutter)
        .padding(.top, DS.Space.top)
    }
    .dsSurface(.paper)
}

#Preview("ChapterVerseBlock · Worship") {
    ChapterVerseBlock(number: 2, lines: ["Perfect submission,", "perfect delight,"],
                      style: .worship, state: .current)
        .padding(DS.Space.gutter)
        .frame(maxHeight: .infinity)
        .dsSurface(.black)
        .environment(\.dsWorshipMode, true)
}
