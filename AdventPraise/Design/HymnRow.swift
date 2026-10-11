//
//  HymnRow.swift
//  Advent Praise 7 — Vesper design system
//
//  One hymn in a list: favourites, playlists, search results, the iPad
//  sidebar. Number in brass serif, title in serif, optional lyric snippet
//  with the search match highlighted.
//
//  • .inset    — inside glass (Lectern panels, sheets): a 5 % fill, no glass.
//  • .plain    — inside a system List; the List owns the background.
//
//  Rows are content, so they are never glass themselves.
//

import SwiftUI

struct HymnRow: View {
    enum Style { case inset, plain }

    let hymn: DSHymnSummary
    var snippet: String? = nil
    /// Words to highlight in the snippet (the search query).
    var highlight: String? = nil
    var isFavourite = false
    var isCurrent = false
    var style: Style = .inset
    var showsChevron = true
    let action: () -> Void

    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.s)
                .frame(maxWidth: .infinity, minHeight: DS.Size.row, alignment: .leading)
                .modifier(RowSurface(style: style, isCurrent: isCurrent))
                .contentShape(RoundedRectangle.ds(DS.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var content: some View {
        // At accessibility sizes the tile stacks above the text instead of squeezing it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Space.m))
        layout {
            Text(String(hymn.number))
                .font(DS.Typeface.numeral).monospacedDigit()
                .foregroundStyle(isCurrent ? surface.tint : surface.brass)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(minWidth: tileSize, minHeight: tileSize)
                .background(RoundedRectangle.ds(DS.Radius.badge)
                    .fill((isCurrent ? surface.tint : surface.brass).opacity(DS.Fill.tintSelected)))

            VStack(alignment: .leading, spacing: DS.Space.hair) {
                HStack(spacing: DS.Space.xs) {
                    Text(hymn.title).font(DS.Typeface.rowTitle).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    if isFavourite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(surface.brass)
                    }
                }
                if let line = snippet ?? hymn.firstLine {
                    Text(highlighted(line))
                        .font(DS.Typeface.caption)
                        .foregroundStyle(surface.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if showsChevron && !typeSize.isAccessibilitySize {
                Image(systemName: isCurrent ? "checkmark" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isCurrent ? surface.tint : surface.secondary)
            }
        }
    }

    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        if let highlight, !highlight.isEmpty,
           let range = result.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]) {
            result[range].backgroundColor = surface.brass.opacity(DS.Fill.highlight)
            result[range].foregroundColor = surface.foreground
            result[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }

    private var accessibilityText: Text {
        var parts = ["\(hymn.number)", hymn.title]
        if isFavourite { parts.append(String(localized: "favourite")) }
        if isCurrent { parts.append(String(localized: "now open")) }
        if let line = snippet ?? hymn.firstLine { parts.append(line) }
        return Text(parts.joined(separator: ", "))
    }
}

/// Row background per style.
private struct RowSurface: ViewModifier {
    let style: HymnRow.Style
    let isCurrent: Bool
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle.ds(DS.Radius.tile)
        switch style {
        case .inset:
            content
                .background(shape.fill(isCurrent ? surface.tint.opacity(DS.Fill.tintActive) : Color.primary.opacity(DS.Fill.row)))
                .overlay(shape.strokeBorder(isCurrent ? surface.tint.opacity(0.35) : .clear))
        case .plain:
            content
        }
    }
}

#Preview("HymnRow · inset & search") {
    VStack(spacing: DS.Space.xs) {
        HymnRow(hymn: DSPreview.hymns[2], isFavourite: true, isCurrent: true) {}
        HymnRow(hymn: DSPreview.hymns[0], isFavourite: true) {}
        HymnRow(hymn: DSPreview.hymns[3], snippet: "Rock of Ages, cleft for me", highlight: "cleft") {}
        HymnRow(hymn: DSPreview.hymns[1], showsChevron: false) {}
    }
    .padding(DS.Space.panel)
    .dsGlass(RoundedRectangle.ds(DS.Radius.panel))
    .padding(DS.Space.l)
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(DSPreviewBackdrop())
    .dsSurface(.paper)
}

#Preview("HymnRow · Muted") {
    VStack(spacing: DS.Space.xs) {
        ForEach(DSPreview.hymns) { hymn in
            HymnRow(hymn: hymn, isCurrent: hymn.number == 30) {}
        }
    }
    .padding(DS.Space.l)
    .dsSurface(.muted)
}

#Preview("HymnRow · AX5") {
    VStack(spacing: DS.Space.xs) {
        HymnRow(hymn: DSPreview.hymns[2], isFavourite: true) {}
        HymnRow(hymn: DSPreview.hymns[3]) {}
    }
    .padding(DS.Space.l)
    .dsSurface(.sepia)
    .environment(\.dynamicTypeSize, .accessibility5)
}
