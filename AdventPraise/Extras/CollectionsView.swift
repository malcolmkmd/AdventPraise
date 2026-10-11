//
//  CollectionsView.swift
//  Advent Praise
//
//  Curated occasion lists. Each opens to its hymns in the current hymnal,
//  which can be opened one at a time, run in church mode, or copied into a
//  new service plan.
//

import SwiftUI

struct CollectionsView: View {
    let model: ReaderModel

    var body: some View {
        List {
            if HymnCollections.all.isEmpty {
                ExtrasEmptyState(title: "No collections", symbol: "square.stack",
                                 message: "Collections couldn’t be loaded.")
                    .listRowBackground(Color.clear)
            }
            ForEach(HymnCollections.all) { collection in
                let count = collection.numbers(in: model.hymnal.id).count
                NavigationLink {
                    CollectionDetailView(model: model, collection: collection)
                } label: {
                    LabeledContent {
                        Text(count == 0 ? "Coming soon" : count == 1 ? "1 hymn" : "\(count) hymns")
                    } label: {
                        Label(collection.title, systemImage: collection.symbol)
                    }
                }
            }
        }
        .navigationTitle("Collections")
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
                ExtrasEmptyState(title: "Coming soon", symbol: collection.symbol,
                                 message: "Hymns for \(collection.title) haven’t been chosen for \(model.hymnal.name) yet.")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    Button {
                        Extras.shared.startChurchMode(numbers, in: model)
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
                Section(collection.title) {
                    ForEach(numbers, id: \.self) { number in
                        Button { Extras.shared.open(number, in: model) } label: {
                            HymnNumberRow(hymnal: model.hymnal, number: number)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationDestination(item: $createdPlan) { ServicePlanDetailView(model: model, planID: $0) }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
