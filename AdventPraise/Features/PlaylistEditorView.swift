//
//  PlaylistEditorView.swift
//  Advent Praise
//
//  One playlist in a system List: hymn numbers and titles in order, drag to
//  reorder, swipe to remove, rename and delete from the title menu. Add
//  Hymns pushes a picker that finds hymns by number, title or words. Play
//  and Add Hymns float in glass at the bottom; the list itself has none.
//

import SwiftUI

struct PlaylistEditorView: View {
    @Bindable var model: ReaderModel
    let playlistID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @State private var isPicking = false

    var body: some View {
        NavigationStack {
            if let list = model.playlist(id: playlistID) {
                editor(list)
            } else {
                ContentUnavailableView("Playlist deleted", systemImage: "music.note.list")
                    .toolbar { doneButton }
            }
        }
        .dsSurface(settings.surface)
    }

    private func editor(_ list: Playlist) -> some View {
        List {
            Section {
                ForEach(Array(list.hymnNumbers.enumerated()), id: \.element) { index, number in
                    PlaylistHymnRow(number: number, title: model.hymnal.hymn(number: number)?.title,
                                    isOpen: model.activePlaylistID == list.id && model.hymn.id == number) {
                        model.play(list, from: index)
                        dismiss()
                    }
                    .accessibilityAction(named: "Move up") { model.moveHymn(number, by: -1, in: list) }
                    .accessibilityAction(named: "Move down") { model.moveHymn(number, by: 1, in: list) }
                    .accessibilityAction(named: "Remove from playlist") { model.remove(number, from: list) }
                }
                .onMove { model.moveHymns(from: $0, to: $1, in: list) }
                .onDelete { model.removeHymns(at: $0, from: list) }
            } header: {
                Text(list.hymnNumbers.count == 1 ? "1 hymn" : "\(list.hymnNumbers.count) hymns")
            } footer: {
                if list.hymnNumbers.isEmpty {
                    Text("Add hymns by number, title or words. You can also add the hymn you're reading from the Playlist tile in the hymn tray.")
                } else {
                    Text("Drag to reorder. Swipe left to remove a hymn.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { floatingControls(list) }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            doneButton
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Playlist options", systemImage: "ellipsis.circle") {
                    Button("Rename", systemImage: "pencil") { isRenaming = true }
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .navigationDestination(isPresented: $isPicking) {
            PlaylistHymnPicker(model: model, playlistID: list.id)
                .dsSurface(settings.surface)
        }
        .playlistNamePrompt("Rename Playlist", isPresented: $isRenaming, initialName: list.name,
                            placeholder: list.name, confirmTitle: "Save") { model.rename(list, to: $0) }
        .alert("Delete “\(list.name)”?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                model.delete(list)
                dismiss()
            }
        } message: {
            Text("The hymns stay in the hymnal; only this playlist is removed.")
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }
    }

    private func floatingControls(_ list: Playlist) -> some View {
        // Side by side, or stacked at accessibility sizes so neither label truncates.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Space.s))
            : AnyLayout(HStackLayout(spacing: DS.Space.s))
        return layout {
            GlassButton(title: "Play", systemImage: "play.fill", kind: .primary, fullWidth: true) {
                model.play(list)
                dismiss()
            }
            .disabled(list.hymnNumbers.isEmpty)
            .accessibilityHint("Opens the first hymn. Next follows this playlist.")
            GlassButton(title: "Add Hymns", systemImage: "plus", kind: .secondary, fullWidth: true) {
                isPicking = true
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.s)
        .frame(maxWidth: DS.Space.lecternMaxWidth)
    }
}

// MARK: - Rows

private struct PlaylistHymnRow: View {
    let number: Int
    let title: String?
    let isOpen: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.editMode) private var editMode
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    var body: some View {
        Button {
            if editMode?.wrappedValue.isEditing != true { action() }
        } label: {
            HStack(spacing: DS.Space.m) {
                Text(String(number))
                    .font(DS.Typeface.numeral).monospacedDigit()
                    .foregroundStyle(isOpen ? surface.tint : surface.brass)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(minWidth: tileSize, minHeight: tileSize)
                    .background(RoundedRectangle.ds(DS.Radius.badge)
                        .fill((isOpen ? surface.tint : surface.brass).opacity(DS.Fill.tintSelected)))
                Text(title ?? String(localized: "Not in this hymnal"))
                    .font(DS.Typeface.rowTitle)
                    .foregroundStyle(title == nil ? surface.secondary : .primary)
                    .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                Spacer(minLength: 0)
                if isOpen {
                    Image(systemName: "checkmark")
                        .font(.footnote)
                        .foregroundStyle(surface.tint)
                }
            }
            .frame(minHeight: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(title == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Hymn \(number), \(title ?? String(localized: "not in this hymnal"))"))
        .accessibilityValue(isOpen ? Text("Now open") : Text(""))
        .accessibilityHint("Opens this hymn and follows the playlist from here.")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Picker

/// Find hymns by number, title or words and add or remove them. A bare
/// number puts that hymn first.
struct PlaylistHymnPicker: View {
    @Bindable var model: ReaderModel
    let playlistID: UUID
    @State private var query = ""

    private var results: [Hymn] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return model.hymnal.hymns }
        var hits = model.hymnal.search(trimmed, inLyrics: true).map(\.hymn)
        if let number = Int(trimmed), let exact = model.hymnal.hymn(number: number) {
            hits.removeAll { $0.id == number }
            hits.insert(exact, at: 0)
        }
        return hits
    }

    var body: some View {
        let list = model.playlist(id: playlistID)
        List {
            ForEach(results) { hymn in
                let isIn = list?.hymnNumbers.contains(hymn.id) ?? false
                Button {
                    guard let list else { return }
                    isIn ? model.remove(hymn.id, from: list) : model.add(hymn.id, to: list)
                } label: {
                    PickerRow(hymn: hymn, isIn: isIn)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Hymn \(hymn.id), \(hymn.title)"))
                .accessibilityValue(isIn ? Text("In playlist") : Text(""))
                .accessibilityHint(isIn ? Text("Removes it from the playlist.") : Text("Adds it to the end of the playlist."))
                .accessibilityAddTraits(isIn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Number, title or words")
        .navigationTitle("Add Hymns")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PickerRow: View {
    let hymn: Hymn
    let isIn: Bool
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Text(String(hymn.id))
                .font(DS.Typeface.numeral).monospacedDigit()
                .foregroundStyle(surface.brass)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(minWidth: tileSize, minHeight: tileSize)
                .background(RoundedRectangle.ds(DS.Radius.badge).fill(surface.brass.opacity(DS.Fill.tintSelected)))
            Text(hymn.title)
                .font(DS.Typeface.rowTitle)
                .lineLimit(2)
            Spacer(minLength: 0)
            Image(systemName: isIn ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(isIn ? surface.tint : surface.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(minHeight: DS.Size.hitTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Name prompt

extension View {
    /// An alert with a text field for naming a playlist. An empty field
    /// commits an empty string; callers fall back to the placeholder.
    func playlistNamePrompt(_ title: LocalizedStringKey, isPresented: Binding<Bool>, initialName: String,
                            placeholder: String, confirmTitle: LocalizedStringKey,
                            onCommit: @escaping (String) -> Void) -> some View {
        modifier(PlaylistNamePrompt(title: title, isPresented: isPresented, initialName: initialName,
                                    placeholder: placeholder, confirmTitle: confirmTitle, onCommit: onCommit))
    }
}

private struct PlaylistNamePrompt: ViewModifier {
    let title: LocalizedStringKey
    @Binding var isPresented: Bool
    let initialName: String
    let placeholder: String
    let confirmTitle: LocalizedStringKey
    let onCommit: (String) -> Void
    @State private var draft = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, presented in if presented { draft = initialName } }
            .alert(title, isPresented: $isPresented) {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                Button("Cancel", role: .cancel) {}
                Button(confirmTitle) { onCommit(draft) }
            } message: {
                Text("Leave it blank to use “\(placeholder)”.")
            }
    }
}
