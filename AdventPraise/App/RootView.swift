//
//  RootView.swift
//  Advent Praise
//
//  iPhone (compact width): the reader alone in a NavigationStack — every
//  control lives in the Lectern. iPad and large windows: a NavigationSplitView
//  with the hymn list (search + hymnal picker) beside the reader.
//

import SwiftUI

struct RootView: View {
    @Bindable var model: ReaderModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(PurchaseStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var showWhatsNew = false

    var body: some View {
        @Bindable var store = store
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    HymnSidebar(model: model)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
                } detail: {
                    HymnReaderView(model: model)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    HymnReaderView(model: model)
                }
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet { model.showChurchMode = true }
        }
        .alert("Purchases", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
        .onAppear {
            if WhatsNew.shouldShow { showWhatsNew = true }
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
    @Bindable var model: ReaderModel
    @Environment(PurchaseStore.self) private var store
    @State private var query = ""

    private var hymns: [Hymn] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? model.hymnal.hymns
            : model.hymnal.search(query, inLyrics: true).map(\.hymn)
    }

    var body: some View {
        List(selection: Binding(get: { model.hymn.id }, set: { number in
            if let number { model.open(number: number) }
        })) {
            ForEach(hymns) { hymn in
                HStack(spacing: 12) {
                    Text(String(hymn.id))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Vesper.brass)
                        .frame(minWidth: 36, alignment: .trailing)
                    Text(hymn.title).lineLimit(2)
                }
                .tag(hymn.id)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hymn \(hymn.id), \(hymn.title)")
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "Number, title or words")
        .navigationTitle(model.hymnal.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Your hymnals") {
                        ForEach(HymnalInfo.catalogue.filter(store.isOwned)) { info in
                            Button {
                                model.switchHymnal(to: info)
                            } label: {
                                if info.id == model.hymnal.id {
                                    Label("\(info.name) · \(info.language)", systemImage: "checkmark")
                                } else {
                                    Text("\(info.name) · \(info.language)")
                                }
                            }
                        }
                    }
                    Button("More hymnals…", systemImage: "globe") { model.openLectern(.hymnals) }
                } label: {
                    Label("Hymnal", systemImage: "globe")
                }
                .accessibilityLabel("Choose hymnal")
            }
        }
    }
}
