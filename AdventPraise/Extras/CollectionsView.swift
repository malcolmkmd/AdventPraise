//
//  CollectionsView.swift
//  Advent Praise
//
//  The SDA Hymnal's sections. Each opens to its hymns in the current hymnal,
//  which can be opened one at a time, run in church mode, or copied into a
//  new service plan.
//

import SwiftUI

struct CollectionsView: View {
    let model: ReaderModel

    private var collections: [HymnCollection] { HymnCollections.available(in: model.hymnal.id) }
    #if DEBUG
    @State private var debugCollection = DebugLaunch.collection.flatMap { id in HymnCollections.all.first { $0.id == id } }
    #endif

    var body: some View {
        List {
            if collections.isEmpty {
                ExtrasEmptyState(title: "No collections", symbol: "square.stack",
                                 message: HymnCollections.all.isEmpty
                                     ? "Collections couldn’t be loaded."
                                     : "Collections follow the sections of the SDA Hymnal. They’re available for Christ In Song in its languages, not for \(model.hymnal.name).")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(collections) { collection in
                        let count = collection.numbers(in: model.hymnal.id).count
                        NavigationLink {
                            CollectionDetailView(model: model, collection: collection)
                        } label: {
                            LabeledContent {
                                Text(count == 1 ? "1 hymn" : "\(count) hymns")
                            } label: {
                                Label(collection.title, systemImage: collection.symbol)
                            }
                        }
                    }
                } footer: {
                    Text("The sections of the Seventh-day Adventist Hymnal (1985). Hymns are placed by their SDA Hymnal number; hymns that aren’t in the SDA Hymnal aren’t in a section.")
                }
            }
        }
        #if DEBUG
        .navigationDestination(item: $debugCollection) { CollectionDetailView(model: model, collection: $0) }
        #endif
        .navigationTitle("Collections")
        .analyticsScreen(.collections)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectionDetailView: View {
    let model: ReaderModel
    let collection: HymnCollection
    @State private var createdPlan: UUID?

    private var numbers: [Int] {
        collection.numbers(in: model.hymnal.id).filter { model.hymnal.hymn(number: $0) != nil }
    }

    var body: some View {
        List {
            if numbers.isEmpty {
                ExtrasEmptyState(title: "No hymns", symbol: collection.symbol,
                                 message: "\(model.hymnal.name) has no hymns from the SDA Hymnal’s \(collection.title) section.")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    Button {
                        Extras.shared.startChurchMode(numbers, named: collection.title, in: model, from: .collection)
                    } label: {
                        Label("Sing in church mode", systemImage: "rectangle.on.rectangle")
                    }
                    Button {
                        createdPlan = ServicePlanner.shared.newPlan(hymnal: model.hymnal.id, numbers: numbers).id
                        Haptics.play(.selection)
                    } label: {
                        Label("Copy to a new service plan", systemImage: "list.number")
                    }
                }
                Section {
                    ForEach(numbers, id: \.self) { number in
                        Button { Extras.shared.open(number, in: model, source: .collection) } label: {
                            HymnNumberRow(hymnal: model.hymnal, number: number)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(numbers.count == 1 ? "1 hymn" : "\(numbers.count) hymns")
                } footer: {
                    Text("SDA Hymnal \(collection.sdahRange)")
                }
            }
        }
        .navigationDestination(item: $createdPlan) { ServicePlanDetailView(model: model, planID: $0) }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
