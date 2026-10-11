//
//  RootView.swift
//  Advent Praise
//
//  iPhone (compact width): the reader alone in a NavigationStack — every
//  control lives in the Lectern. iPad and large windows: a NavigationSplitView
//  with search, favourites, playlists and the hymn list beside the reader.
//

import SwiftUI

struct RootView: View {
    @Bindable var model: ReaderModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(PurchaseStore.self) private var store
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var store = store
        @Bindable var settings = settings
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    HymnSidebar(model: model)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
                } detail: {
                    HymnReaderView(model: model)
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: model.revealSidebar) { _, reveal in
                    if reveal {
                        columnVisibility = .all
                        model.revealSidebar = false
                    }
                }
            } else {
                NavigationStack {
                    HymnReaderView(model: model)
                }
            }
        }
        // Drawers cover the whole window (both columns on iPad) and sit inside
        // dsSurface so they read the current reading surface.
        .appearanceDrawer(isPresented: $model.showAppearance, style: $settings.style, surface: $settings.surface)
        .moreDrawer(model: model)
        .whatsNewDrawer {
            model.showChurchMode = true
        }
        .dsSurface(settings.surface, paintsBackground: false)
        .alert("Purchases", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
        .sheet(item: $model.editingPlaylist) { editing in
            PlaylistEditorView(model: model, playlistID: editing.id)
                .environment(settings)
        }
        .playlistNamePrompt("New Playlist", isPresented: $model.isNamingNewPlaylist, initialName: "",
                            placeholder: model.nextPlaylistName, confirmTitle: "Create") { model.createPlaylist(named: $0) }
        .playlistNamePrompt("Rename Playlist", isPresented: renaming, initialName: model.playlistBeingRenamed?.name ?? "",
                            placeholder: model.playlistBeingRenamed?.name ?? "", confirmTitle: "Save") { name in
            if let list = model.playlistBeingRenamed { model.rename(list, to: name) }
        }
        .alert("Delete “\(model.playlistPendingDeletion?.name ?? "")”?", isPresented: deleting,
               presenting: model.playlistPendingDeletion) { list in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { model.delete(list) }
        } message: { _ in
            Text("The hymns stay in the hymnal; only this playlist is removed.")
        }
        .onChange(of: store.purchasedProductIDs) { _, _ in enforceOwnership() }
        .onChange(of: store.hasLoadedEntitlements) { _, _ in enforceOwnership() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Analytics.track(.appOpened) } }
    }

    private var renaming: Binding<Bool> {
        Binding(get: { model.playlistBeingRenamed != nil }, set: { if !$0 { model.playlistBeingRenamed = nil } })
    }

    private var deleting: Binding<Bool> {
        Binding(get: { model.playlistPendingDeletion != nil }, set: { if !$0 { model.playlistPendingDeletion = nil } })
    }

    /// A refunded or revoked hymnal falls back to the free English hymnal.
    private func enforceOwnership() {
        guard store.isConfigured, store.hasLoadedEntitlements, !store.isOwned(model.hymnalInfo) else { return }
        model.switchHymnal(to: .default)
    }
}

// MARK: - Sidebar (iPad)

struct HymnSidebar: View {
    let model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @State private var query = ""
    @State private var showHymnals = false

    private var hymns: [Hymn] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? model.hymnal.hymns
            : model.hymnal.search(query, inLyrics: true).map(\.hymn)
    }

    var body: some View {
        List {
            // Playlists and favourites sit above the full hymn list so they stay
            // reachable; a search shows only matching hymns.
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                Section("Playlists") {
                    ForEach(model.playlists) { list in
                        PlaylistSummaryRow(model: model, list: list, style: .plain)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { model.playlistPendingDeletion = list }
                                Button("Edit", systemImage: "pencil") { model.edit(list) }
                            }
                    }
                    Button("New Playlist", systemImage: "plus") { model.newPlaylist() }
                        .font(DS.Typeface.label)
                }
                if !model.favouriteNumbers.isEmpty {
                    Section("Favourites") {
                        ForEach(model.favouriteNumbers, id: \.self) { number in
                            if let hymn = model.hymnal.hymn(number: number) {
                                HymnRow(hymn: hymn.designSummary, isFavourite: true,
                                        isCurrent: hymn.id == model.hymn.id, style: .plain, showsChevron: false) {
                                    model.open(number: number)
                                }
                            }
                        }
                    }
                }
            }
            Section("Hymns") {
                ForEach(hymns) { hymn in
                    HymnRow(hymn: hymn.designSummary,
                            isFavourite: model.favouriteNumbers.contains(hymn.id),
                            isCurrent: hymn.id == model.hymn.id,
                            style: .plain,
                            showsChevron: false) {
                        model.open(number: hymn.id)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "Number, title or words")
        .navigationTitle(model.hymnal.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hymnals", systemImage: "globe") { showHymnals = true }
                    .accessibilityLabel("Choose hymnal")
            }
        }
        .sheet(isPresented: $showHymnals) {
            NavigationStack {
                ScrollView {
                    HymnalStorePicker(model: model, onSwitched: { showHymnals = false })
                        .padding(DS.Space.l)
                }
                .navigationTitle("Hymnals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showHymnals = false }
                    }
                }
            }
            .dsSurface(settings.surface)
            .presentationDetents([.large])
        }
    }
}
