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
    /// Whether the sidebar was hidden, restored per window.
    @SceneStorage("root.sidebarHidden") private var sidebarHidden = false

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(get: { sidebarHidden ? .detailOnly : .all },
                set: { sidebarHidden = $0 == .detailOnly })
    }

    var body: some View {
        @Bindable var store = store
        @Bindable var settings = settings
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView(columnVisibility: columnVisibility) {
                    HymnSidebar(model: model)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
                } detail: {
                    HymnReaderView(model: model)
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: model.toggleSidebar) { _, toggle in
                    guard toggle else { return }
                    withAnimation { sidebarHidden.toggle() }
                    model.toggleSidebar = false
                }
            } else {
                NavigationStack {
                    HymnReaderView(model: model)
                }
            }
        }
        // Model-driven presentations hang off the root, not the reader: the
        // reader is rebuilt when the size class flips (iPad Split View, Stage
        // Manager, rotating a large iPhone), and that would dismiss them.
        .sheet(item: $model.mail) { request in
            MailComposeView(draft: .make(request.kind, hymnal: model.hymnal, hymn: model.hymn))
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $model.showChurchMode) {
            ChurchModeView(model: model)
        }
        .extrasSheets(model: model)
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
        #if DEBUG
        .task {
            if let surface = DebugLaunch.surface { settings.surface = surface }
            if let sheet = DebugLaunch.sheet { Extras.shared.sheet = sheet }
            if DebugLaunch.showsMore { model.showMore = true }
        }
        #endif
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
        model.switchHymnal(to: .default, feedback: nil)
    }
}

// MARK: - Sidebar (iPad)

struct HymnSidebar: View {
    let model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @State private var query = ""
    @State private var showHymnals = false

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        let favouriteNumbers = model.favouriteNumbers
        let favourites = Set(favouriteNumbers)
        let hymns = isSearching ? model.hymnal.search(query, inLyrics: true).map(\.hymn) : model.hymnal.hymns
        List {
            // Favourites and playlists first: below the full hymn list they
            // were hundreds of rows down. Hidden while searching.
            if !isSearching, !favouriteNumbers.isEmpty {
                Section("Favourites") {
                    ForEach(favouriteNumbers.compactMap(model.hymnal.hymn(number:))) { hymn in
                        HymnRow(hymn: hymn.designSummary, isFavourite: true,
                                isCurrent: hymn.id == model.hymn.id, style: .plain, showsChevron: false) {
                            model.open(number: hymn.id)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                }
            }
            // Shown even when empty so New Playlist stays reachable. Each row's
            // touch-and-hold menu covers add / rename / delete.
            if !isSearching {
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
            }
            Section("Hymns") {
                ForEach(hymns) { hymn in
                    HymnRow(hymn: hymn.designSummary,
                            isFavourite: favourites.contains(hymn.id),
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
