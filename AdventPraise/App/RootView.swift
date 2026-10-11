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
        .onChange(of: store.purchasedProductIDs) { _, _ in enforceOwnership() }
        .onChange(of: store.hasLoadedEntitlements) { _, _ in enforceOwnership() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Analytics.track(.appOpened) } }
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
            if !model.playlists.isEmpty {
                Section("Playlists") {
                    ForEach(model.playlists) { list in
                        Button {
                            model.play(list)
                        } label: {
                            VStack(alignment: .leading, spacing: DS.Space.hair) {
                                Text(list.name).font(DS.Typeface.rowTitle)
                                Text(list.hymnNumbers.map(String.init).joined(separator: " · "))
                                    .font(DS.Typeface.caption)
                                    .foregroundStyle(settings.surface.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .contextMenu {
                            Button("Add hymn \(model.hymn.id)", systemImage: "plus") { model.addCurrentHymn(to: list) }
                            Button("Delete playlist", systemImage: "trash", role: .destructive) { model.delete(list) }
                        }
                    }
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
