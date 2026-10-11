//
//  LecternPanels.swift
//  Advent Praise
//
//  The panels that unfold out of the Lectern: hymn tray, word search and
//  library (favourites and playlists). More opens in its own drawer
//  (MoreDrawer.swift). Each is its own view so it
//  only re-renders for the model state it reads. They sit inside the
//  Lectern's glass, so nothing in here draws glass of its own.
//

import SwiftUI

// MARK: - Hymn tray

struct LecternHymnTray: View {
    let model: ReaderModel
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        HStack(spacing: DS.Space.s) {
            TrayTile(label: model.isFavourite ? "Saved" : "Save", isOn: model.isFavourite, onColor: settings.surface.brass) {
                Image(systemName: model.isFavourite ? "star.fill" : "star")
                    .contentTransition(.symbolEffect(.replace))
            } action: { model.toggleFavourite() }
            TrayTile(label: "Church", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "rectangle.on.rectangle")
            } action: { model.closeLectern(); model.showChurchMode = true }
            addToPlaylistTile
            TrayTile(label: "Hymnal", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "globe")
            } action: { model.openLectern(.hymnals) }
            TrayTile(label: "Text", isOn: false, onColor: settings.surface.tint) {
                Text("Aa").font(DS.Typeface.panelTitle)
            } action: { model.closeLectern(); model.showAppearance = true }
            TrayTile(label: "More", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "ellipsis")
            } action: { model.closeLectern(); model.showMore = true }
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.top, DS.Space.panel)
        .padding(.bottom, DS.Space.xs)
    }

    /// Adds the open hymn to a playlist, or starts a new one with it.
    private var addToPlaylistTile: some View {
        let inAny = model.playlists.contains { $0.hymnNumbers.contains(model.hymn.id) }
        return Menu {
            Section("Add hymn \(model.hymn.id) to") {
                ForEach(model.playlists) { list in
                    let isIn = list.hymnNumbers.contains(model.hymn.id)
                    Button(list.name, systemImage: isIn ? "checkmark" : "music.note.list") { model.addCurrentHymn(to: list) }
                        .disabled(isIn)
                }
            }
            Button("New Playlist…", systemImage: "plus") { model.closeLectern(); model.newPlaylist() }
        } label: {
            TrayTileLabel(label: "Playlist", isOn: inAny, onColor: settings.surface.tint) {
                Image(systemName: inAny ? "text.badge.checkmark" : "text.badge.plus")
            }
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(inAny ? settings.surface.tint : .primary)
        .accessibilityLabel("Add to playlist")
        .accessibilityValue(inAny ? "In a playlist" : "")
    }
}

// MARK: - Word search

struct LecternSearchPanel: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(settings.surface.secondary)
                    TextField("Words in a title or lyric", text: $model.query)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit(openFirstHit)
                        .accessibilityLabel("Search words in a title or lyric")
                }
                .padding(.horizontal, DS.Space.m)
                .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
                .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                Button("123") { model.openLectern(.pad) }
                    .font(DS.Typeface.button)
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: DS.Size.hitTarget)
                    .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Enter a number instead")
            }

            HStack {
                HStack(spacing: DS.Space.xs) {
                    ScopeChip(title: "Lyrics", isOn: model.searchLyrics) { model.searchLyrics = true }
                    ScopeChip(title: "Titles", isOn: !model.searchLyrics) { model.searchLyrics = false }
                }
                Spacer()
                Text(model.searchHits.isEmpty ? "" : "\(model.searchHits.count) hymn\(model.searchHits.count == 1 ? "" : "s")")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(settings.surface.secondary)
            }
            .padding(.horizontal, DS.Space.xxs)

            DSFittingScroll(maxHeight: 260) {
                VStack(spacing: DS.Space.xs) {
                    ForEach(model.searchHits.prefix(40)) { hit in
                        HymnRow(hymn: hit.hymn.designSummary, snippet: hit.snippet, highlight: model.query,
                                isFavourite: model.favouriteNumbers.contains(hit.hymn.id),
                                isCurrent: hit.hymn.id == model.hymn.id, style: .inset) {
                            Analytics.track(.searchUsed(lyrics: model.searchLyrics))
                            model.show(hit.hymn)
                        }
                    }
                }
            }
        }
        .padding(DS.Space.panel)
        // The panel exists only while search is open, so focus follows it.
        .onAppear { isFocused = true }
    }

    private func openFirstHit() {
        guard let first = model.searchHits.first else { return }
        Analytics.track(.searchUsed(lyrics: model.searchLyrics))
        model.show(first.hymn)
    }
}

// MARK: - Library

struct LecternLibraryPanel: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                Picker("Library", selection: $model.libraryTab) {
                    ForEach(LibraryTab.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: DS.Size.hitTarget)
                GlassButton(title: "New playlist", systemImage: "plus", kind: .icon) { model.newPlaylist() }
            }

            switch model.libraryTab {
            case .favourites: favourites
            case .playlists: playlists
            }
        }
        .padding(DS.Space.panel)
    }

    private var favourites: some View {
        DSFittingScroll(maxHeight: 300) {
            VStack(spacing: DS.Space.xs) {
                ForEach(model.favouriteNumbers, id: \.self) { number in
                    if let hymn = model.hymnal.hymn(number: number) {
                        HymnRow(hymn: hymn.designSummary, isFavourite: true,
                                isCurrent: hymn.id == model.hymn.id, style: .inset) { model.show(hymn) }
                    }
                }
                if model.favouriteNumbers.isEmpty {
                    EmptyNote(text: "Star a hymn while you read to keep it here.")
                }
            }
        }
    }

    /// Hugs a short list; scrolls once it outgrows the panel.
    private var playlists: some View {
        DSFittingScroll(maxHeight: 300) {
            VStack(spacing: DS.Space.xs) {
                ForEach(model.playlists) { list in
                    PlaylistSummaryRow(model: model, list: list, style: .inset)
                }
                if model.playlists.isEmpty {
                    EmptyNote(text: "Build a set for Sabbath, choir practice or vespers. Tap + to start one with the open hymn.")
                }
            }
        }
    }
}

// MARK: - Pieces

private struct EmptyNote: View {
    let text: LocalizedStringKey
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Text(text)
            .font(DS.Typeface.caption)
            .foregroundStyle(surface.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrayTile<Icon: View>: View {
    let label: LocalizedStringKey
    let isOn: Bool
    let onColor: Color
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrayTileLabel(label: label, isOn: isOn, onColor: onColor) { icon }
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(isOn ? onColor : .primary)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A tray tile's face, shared by the button tiles and the Playlist menu tile.
private struct TrayTileLabel<Icon: View>: View {
    let label: LocalizedStringKey
    let isOn: Bool
    let onColor: Color
    @ViewBuilder let icon: Icon
    /// One slot height for every glyph so the labels line up.
    @ScaledMetric(relativeTo: .title3) private var iconSlot: CGFloat = 26

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            icon.font(.title3).frame(height: iconSlot)
            Text(label).font(DS.Typeface.eyebrow).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(RoundedRectangle.ds(DS.Radius.tile)
            .fill(isOn ? onColor.opacity(DS.Fill.tintOn) : Color.primary.opacity(DS.Fill.inset)))
        .contentShape(RoundedRectangle.ds(DS.Radius.tile))
    }
}

/// A 32 pt chip with a 44 pt tall hit area.
private struct ScopeChip: View {
    let title: LocalizedStringKey
    let isOn: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typeface.caption.weight(isOn ? .bold : .semibold))
                .padding(.horizontal, DS.Space.m)
                .frame(minHeight: 32)
                .background(Capsule().fill(isOn ? surface.tint.opacity(DS.Fill.tintSelected) : .clear))
                .overlay(Capsule().strokeBorder(isOn ? .clear : .primary.opacity(DS.Fill.stroke)))
                .frame(minHeight: DS.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? surface.tint : surface.secondary)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
