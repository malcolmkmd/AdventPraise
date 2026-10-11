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
        .dsSurface(settings.surface, paintsBackground: false)
        .whatsNewSheet {
            model.showChurchMode = true
        }
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
