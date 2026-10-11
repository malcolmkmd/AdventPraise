//
//  PlaylistSummaryRow.swift
//  Advent Praise
//
//  One playlist in the Lectern's library panel (.inset) or the iPad sidebar
//  (.plain, inside a List). Tap plays it; the pencil opens the editor;
//  touch and hold for add / rename / delete. VoiceOver gets the same
//  choices as actions on a single element.
//

import SwiftUI

struct PlaylistSummaryRow: View {
    enum Style { case inset, plain }

    let model: ReaderModel
    let list: Playlist
    var style: Style = .inset
    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    private var isActive: Bool { model.activePlaylistID == list.id }
    private var countText: String { list.hymnNumbers.count == 1 ? "1 hymn" : "\(list.hymnNumbers.count) hymns" }
    private var numbersText: String { list.hymnNumbers.map(String.init).joined(separator: " · ") }

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Button { model.play(list) } label: {
                HStack(spacing: DS.Space.m) {
                    if style == .inset && !typeSize.isAccessibilitySize {
                        Image(systemName: isActive ? "play.fill" : "music.note.list")
                            .foregroundStyle(surface.tint)
                            .frame(width: tileSize, height: tileSize)
                            .background(RoundedRectangle.ds(DS.Radius.badge).fill(surface.tint.opacity(DS.Fill.tintSelected)))
                    }
                    VStack(alignment: .leading, spacing: DS.Space.hair) {
                        Text(list.name)
                            .font(DS.Typeface.rowTitle)
                            .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                        Text(list.hymnNumbers.isEmpty ? "No hymns yet" : numbersText)
                            .font(DS.Typeface.caption)
                            .foregroundStyle(surface.secondary)
                            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { model.edit(list) } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(surface.tint)
                    .frame(minWidth: DS.Size.hitTarget, minHeight: DS.Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .modifier(SummarySurface(style: style, isActive: isActive))
        .contextMenu {
            Button("Play", systemImage: "play") { model.play(list) }
            Button("Edit Playlist", systemImage: "pencil") { model.edit(list) }
            if !list.hymnNumbers.contains(model.hymn.id) {
                Button("Add Hymn \(model.hymn.id)", systemImage: "plus") { model.addCurrentHymn(to: list) }
            }
            Button("Rename", systemImage: "character.cursor.ibeam") { model.playlistBeingRenamed = list }
            Button("Delete Playlist", systemImage: "trash", role: .destructive) { model.playlistPendingDeletion = list }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(list.name), \(countText)"))
        .accessibilityValue(isActive ? Text("Playing") : Text(numbersText))
        .accessibilityHint("Opens the first hymn. Next follows this playlist.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.play(list) }
        .accessibilityAction(named: "Edit playlist") { model.edit(list) }
        .accessibilityAction(named: "Add hymn \(model.hymn.id)") { model.addCurrentHymn(to: list) }
        .accessibilityAction(named: "Rename") { model.playlistBeingRenamed = list }
        .accessibilityAction(named: "Delete playlist") { model.playlistPendingDeletion = list }
    }
}

private struct SummarySurface: ViewModifier {
    let style: PlaylistSummaryRow.Style
    let isActive: Bool
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        switch style {
        case .inset:
            let shape = RoundedRectangle.ds(DS.Radius.tile)
            content
                .padding(.leading, DS.Space.m)
                .padding(.vertical, DS.Space.xxs)
                .frame(maxWidth: .infinity, minHeight: DS.Size.row, alignment: .leading)
                .background(shape.fill(isActive ? surface.tint.opacity(DS.Fill.tintActive) : Color.primary.opacity(DS.Fill.row)))
                .overlay(shape.strokeBorder(isActive ? surface.tint.opacity(0.35) : .clear))
                .contentShape(.contextMenuPreview, shape)
        case .plain:
            content
        }
    }
}
