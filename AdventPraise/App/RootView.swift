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
    @Environment(HymnMIDIEngine.self) private var player
    #if DEBUG
    @Environment(ChurchPresentation.self) private var church
    #endif
    @Environment(ReadingSettings.self) private var settings
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
        // Above the navigation bar (its globe grows into a bar across it),
        // below the drawers, sheets and church mode.
        .readerMenu(model)
        // The Lectern's library button shows whether the sidebar is out.
        .onChange(of: horizontalSizeClass == .regular && !sidebarHidden, initial: true) { _, visible in
            model.isSidebarVisible = visible
        }
        // Model-driven presentations hang off the root, not the reader: the
        // reader is rebuilt when the size class flips (iPad Split View, Stage
        // Manager, rotating a large iPhone), and that would dismiss them.
        .fullScreenCover(isPresented: $model.showChurchMode) {
            ChurchModeView(model: model)
        }
        .extrasSheets(model: model)
        .featureBoardSheet(model: model)
        // Drawers cover the whole window (both columns on iPad) and sit inside
        // dsSurface so they read the current reading surface.
        .moreDrawer(model: model)
        // Church mode covers the root and presents its own.
        .proPaywall(feature: $model.paywall, isEnabled: !model.showChurchMode, context: .reader) { feature in
            if feature == .player { player.start(model.hymn, source: model.hymnal.name) }
        }
        .whatsNewDrawer {
            model.enterChurchMode(from: .whatsNew)
        }
        .dsSurface(settings.surface, paintsBackground: false)
        .alert("Purchases", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
        .sheet(item: $model.editingPlaylist, onDismiss: revealFirstPlaylist) { editing in
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
        #if DEBUG
        .task {
            if let surface = DebugLaunch.surface { settings.surface = surface }
            if DebugLaunch.sheet == .support {
                model.showMore = true
                model.showSupport = true
            } else if let sheet = DebugLaunch.sheet {
                Extras.shared.sheet = sheet
            }
            if DebugLaunch.showsMore { model.showMore = true }
            if DebugLaunch.showsFeatureBoard, FeatureBoard.prepare(for: settings.surface) { model.showFeatureBoard = true }
            if let feature = DebugLaunch.paywall {
                if DebugLaunch.paywallDelay > 0 { try? await Task.sleep(for: .seconds(DebugLaunch.paywallDelay)) }
                model.paywall = feature
            }
            if DebugLaunch.showsTipThanks, let tip = PurchaseConfig.tips.first {
                store.thankYouForTip = tip.option(price: "R19.99")
            }
            if DebugLaunch.centered { settings.style.centered = true }
            if let number = DebugLaunch.hymn { model.open(number: number, source: .numpad) }
            if let numbers = DebugLaunch.queue { model.play(queue: numbers, named: "Sabbath morning", source: .servicePlan) }
            if DebugLaunch.showsChurch { model.showChurchMode = true }
            if let state = DebugLaunch.lectern { model.openLectern(state) }
            if let digits = DebugLaunch.digits { model.openLectern(.pad); model.digits = digits }
            if DebugLaunch.plays { player.start(model.hymn, source: model.hymnal.name) }
            if DebugLaunch.external == "verse" { church.isActive = true; church.index = 1 }
            if DebugLaunch.external == "blank" { church.isBlanked = true }
            if DebugLaunch.externalConnected { church.isExternalScreenConnected = true }
            if let prefix = DebugLaunch.renderExternal {
                WorshipDisplayRenderer.render(model: model, church: church, settings: settings, to: prefix)
            }
        }
        .overlay {
            if DebugLaunch.external != nil { ExternalHymnView(model: model, church: church) }
        }
        #endif
    }

    /// After the first playlist's editor closes, show where playlists live:
    /// the sidebar on iPad, the library panel on its Playlists tab on iPhone.
    private func revealFirstPlaylist() {
        guard model.playlistEditorClosed() else { return }
        if horizontalSizeClass == .regular {
            if sidebarHidden { withAnimation { sidebarHidden = false } }
        } else {
            model.openLectern(.library)
        }
    }

    private var renaming: Binding<Bool> {
        Binding(get: { model.playlistBeingRenamed != nil }, set: { if !$0 { model.playlistBeingRenamed = nil } })
    }

    private var deleting: Binding<Bool> {
        Binding(get: { model.playlistPendingDeletion != nil }, set: { if !$0 { model.playlistPendingDeletion = nil } })
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
                            model.open(number: hymn.id, source: .favourites)
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
                        if isSearching, let rank = hymns.firstIndex(where: { $0.id == hymn.id }) {
                            Analytics.track(.searchResultOpened(surface: .sidebar, scope: .lyrics, rank: rank + 1))
                        }
                        model.open(number: hymn.id, source: isSearching ? .search : .sidebar)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "Number, title or words")
        // Once typing pauses: how long the query was and what it found, never the words.
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            Analytics.track(.searchPerformed(surface: .sidebar, scope: .lyrics, queryLength: trimmed.count,
                                             resultCount: hymns.count, isNumber: Int(trimmed) != nil))
        }
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
                    HymnalStorePicker(model: model, source: .sidebar, onSwitched: { showHymnals = false })
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
