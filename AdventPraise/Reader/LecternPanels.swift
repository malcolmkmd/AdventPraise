//
//  LecternPanels.swift
//  Advent Praise
//
//  The panels that unfold out of the Lectern: hymn tray, word search and
//  library (favourites and playlists). More opens in its own sheet
//  (MoreSheet.swift). Each is its own view so it
//  only re-renders for the model state it reads. They sit inside the
//  Lectern's glass, so nothing in here draws glass of its own.
//

import SwiftUI

// MARK: - Hymn tray

/// What you do with the hymn on screen, one tap from the open tray: church
/// mode, Memorise, sheet music (when the hymn has it), add to a playlist, save. Play is in the row below, and
/// translation, theme and text are in the reader menu at the top.
struct LecternHymnTray: View {
    let model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @State private var choosingPlaylist = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            TrayTile(label: "Church", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "rectangle.on.rectangle")
            } action: { model.closeLectern(); model.enterChurchMode(from: .tray) }
                .accessibilityHint("Shows one verse at a time, large, for singing together")
                .tourAnchor(.churchTile)
            TrayTile(label: "Memorise", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "brain.head.profile")
            } action: {
                model.closeLectern()
                Analytics.track(.toolOpened(.memory, source: .tray))
                Extras.shared.sheet = .memory
            }
                .accessibilityHint("Learn a verse of this hymn by filling in its words")
                .tourAnchor(.memoriseTile)
            if SheetMusicCatalog.has(hymnal: model.hymnal.id, number: model.hymn.id) {
                TrayTile(label: "Music", isOn: false, onColor: settings.surface.tint) {
                    Image(systemName: "music.note.list")
                } action: {
                    model.closeLectern()
                    Extras.shared.sheet = .sheetMusic
                }
                    .accessibilityLabel("Sheet music")
                    .accessibilityHint("Shows this hymn’s sheet music")
                    .accessibilityIdentifier("lectern.sheetMusic")
            }
            addToPlaylistTile
            TrayTile(label: model.isFavourite ? "Saved" : "Save", isOn: model.isFavourite, onColor: settings.surface.brass) {
                Image(systemName: model.isFavourite ? "star.fill" : "star")
                    .contentTransition(.symbolEffect(.replace))
            } action: { model.toggleFavourite() }
            TrayTile(label: "More", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "ellipsis")
            } action: { model.closeLectern(); model.showMore = true }
                .tourAnchor(.moreTile)
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.top, DS.Space.panel)
        .padding(.bottom, DS.Space.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lectern.hymnTray")
    }

    /// Adds the open hymn to a playlist, or starts a new one with it. A plain
    /// Button like its neighbours, not a Menu: a Menu is UIKit-backed and its
    /// tap had to win against the Lectern's swipe and glass, so it often took
    /// several taps. The choice is a SwiftUI dialog anchored to the tile.
    private var addToPlaylistTile: some View {
        let lists = model.playlists
        let inAny = lists.contains { $0.hymnNumbers.contains(model.hymn.id) }
        return TrayTile(label: "Playlist", isOn: inAny, onColor: settings.surface.tint) {
            Image(systemName: inAny ? "text.badge.checkmark" : "text.badge.plus")
        } action: {
            if lists.isEmpty { model.closeLectern(); model.newPlaylist() } else { choosingPlaylist = true }
        }
        .accessibilityLabel("Add to playlist")
        .accessibilityValue(inAny ? "In a playlist" : "")
        .confirmationDialog("Add hymn \(model.hymn.id, format: .hymnNumber) to", isPresented: $choosingPlaylist, titleVisibility: .visible) {
            ForEach(lists.filter { !$0.hymnNumbers.contains(model.hymn.id) }) { list in
                Button(list.name) { model.addCurrentHymn(to: list) }
            }
            Button("New Playlist…") { model.closeLectern(); model.newPlaylist() }
        } message: {
            let names = lists.filter { $0.hymnNumbers.contains(model.hymn.id) }.map(\.name)
            if !names.isEmpty { Text("Already in \(names.formatted(.list(type: .and))).") }
        }
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
                // The padding and fill are in the label, so the whole key takes the tap.
                Button { model.openLectern(.pad) } label: {
                    Text("123")
                        .font(DS.Typeface.button)
                        .padding(.horizontal, DS.Space.m)
                        .frame(minHeight: DS.Size.hitTarget)
                        .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                        .contentShape(RoundedRectangle.ds(DS.Radius.tile))
                }
                .buttonStyle(DSPressStyle())
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
                    ForEach(Array(model.searchHits.prefix(40).enumerated()), id: \.element.id) { rank, hit in
                        HymnRow(hymn: hit.hymn.designSummary, snippet: hit.snippet, highlight: model.query,
                                isFavourite: model.favouriteNumbers.contains(hit.hymn.id),
                                isCurrent: hit.hymn.id == model.hymn.id, style: .inset) {
                            open(hit, rank: rank)
                        }
                    }
                }
            }
        }
        .padding(DS.Space.panel)
        // The panel exists only while search is open, so focus follows it.
        .onAppear { isFocused = true }
        .analyticsScreen(.search)
        // Once typing pauses: how long the query was and what it found, never the words.
        .task(id: "\(model.searchLyrics)|\(model.query)") {
            let trimmed = model.query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            Analytics.track(.searchPerformed(surface: .lectern, scope: scope, queryLength: trimmed.count,
                                             resultCount: model.searchHits.count, isNumber: Int(trimmed) != nil))
        }
    }

    private var scope: SearchScope { model.searchLyrics ? .lyrics : .titles }

    private func openFirstHit() {
        guard let first = model.searchHits.first else { return }
        open(first, rank: 0)
    }

    private func open(_ hit: SearchHit, rank: Int) {
        Analytics.track(.searchResultOpened(surface: .lectern, scope: scope, rank: rank + 1))
        model.show(hit.hymn, source: .search)
    }
}

// MARK: - Library

struct LecternLibraryPanel: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @State private var isAddingHymn = false
    @State private var hymnNumberDraft = ""
    /// The number typed into Add hymn that the hymnal doesn't have.
    @State private var missingNumber: Int?

    var body: some View {
        VStack(spacing: DS.Space.m) {
            // The panel resizes for the other list in the Lectern's animation.
            Picker("Library", selection: $model.libraryTab.animation(DS.Motion.lecternTransition)) {
                ForEach(LibraryTab.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)

            switch model.libraryTab {
            case .favourites: favourites
            case .playlists: playlists
            }

            // Below the list, which scrolls on its own, so it stays put at the panel's foot.
            primaryAction
        }
        .padding(DS.Space.panel)
        .analyticsScreen(.library)
        .alert("Add Hymn", isPresented: $isAddingHymn) {
            TextField("Hymn number", text: $hymnNumberDraft)
                .keyboardType(.numberPad)
                .accessibilityLabel("Hymn number")
            Button("Cancel", role: .cancel) {}
            Button("Add", action: addTypedHymn)
        } message: {
            Text("Type a number from \(model.hymnalInfo.name) to keep it in Favourites.")
        }
        .background {
            // A second alert needs its own anchor to follow the first.
            Color.clear.alert("No Hymn \(missingNumber ?? 0, format: .hymnNumber)", isPresented: missingBinding) {
                Button("Cancel", role: .cancel) {}
                Button("Try Again") { promptForHymn() }
            } message: {
                Text("\(model.hymnalInfo.name) has hymns 1 to \(max(model.hymnalInfo.maxNumber, 1)). Check the number and try again.")
            }
        }
    }

    /// The panel's one button: what you'd want to add on the tab you're on.
    @ViewBuilder private var primaryAction: some View {
        switch model.libraryTab {
        case .favourites:
            GlassButton(title: "Add hymn", systemImage: "plus", fullWidth: true, action: promptForHymn)
                .accessibilityHint("Adds a hymn to Favourites by its number")
        case .playlists:
            GlassButton(title: "New Playlist", systemImage: "plus", fullWidth: true) { model.newPlaylist() }
                .accessibilityHint("Starts a playlist with the open hymn")
        }
    }

    private var missingBinding: Binding<Bool> {
        Binding(get: { missingNumber != nil }, set: { if !$0 { missingNumber = nil } })
    }

    private func promptForHymn() {
        hymnNumberDraft = ""
        isAddingHymn = true
    }

    private func addTypedHymn() {
        let typed = hymnNumberDraft.filter(\.isNumber)
        guard let number = Int(typed) else { return }
        if !model.addFavourite(number: number) {
            Haptics.play(.limit)
            missingNumber = number
        }
    }

    private var favourites: some View {
        DSFittingScroll(maxHeight: 300) {
            VStack(spacing: DS.Space.xs) {
                ForEach(model.favouriteNumbers, id: \.self) { number in
                    if let hymn = model.hymnal.hymn(number: number) {
                        HymnRow(hymn: hymn.designSummary, isFavourite: true,
                                isCurrent: hymn.id == model.hymn.id, style: .inset) { model.show(hymn, source: .favourites) }
                    }
                }
                if model.favouriteNumbers.isEmpty {
                    EmptyNote(text: "Star a hymn while you read, or add one by number, to keep it here.")
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
                    EmptyNote(text: "Build a set for Sabbath, choir practice or vespers. Tap New Playlist to start one with the open hymn.")
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
        .accessibilityShowsLargeContentViewer { icon; Text(label) }
    }
}

/// A tray tile's face. The content shape fills the tile, so the whole
/// 72 pt tile takes the tap, not just the glyph and caption.
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
            // Five or six tiles share the row: past xxxLarge the captions would
            // truncate, so they stop there (the glyphs keep growing) and a
            // long press shows them large.
            Text(label).font(DS.Typeface.eyebrow).lineLimit(1).minimumScaleFactor(0.7)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
