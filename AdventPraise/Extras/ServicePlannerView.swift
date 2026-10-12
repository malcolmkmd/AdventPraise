//
//  ServicePlannerView.swift
//  Advent Praise
//
//  Service plans for the open hymnal, and the editor for one plan: name and
//  date, the hymns in order (drag to reorder, swipe to delete, a role and a
//  pitch pipe for each), and "Start in church mode".
//

import SwiftUI

struct ServicePlansView: View {
    let model: ReaderModel
    @State private var opened: UUID?
    private var planner: ServicePlanner { .shared }

    var body: some View {
        let plans = planner.plans(for: model.hymnal.id)
        List {
            Section {
                Button {
                    opened = planner.newPlan(hymnal: model.hymnal.id, numbers: [model.hymn.id]).id
                    Haptics.play(.selection)
                } label: {
                    Label("New plan with hymn \(model.hymn.id)", systemImage: "plus")
                }
            } footer: {
                Text("Plans list hymns from \(model.hymnal.name) in the order they’ll be sung.")
            }

            if plans.isEmpty {
                ExtrasEmptyState(title: "No service plans", symbol: "list.number",
                                 message: "Make a plan for this week’s service, then sing it in church mode.")
                    .listRowBackground(Color.clear)
            } else {
                Section("Plans") {
                    ForEach(plans) { plan in
                        NavigationLink(value: plan.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name).font(.body.weight(.semibold))
                                Text(summary(plan)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { planner.delete(plan) }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in ServicePlanDetailView(model: model, planID: id) }
        .navigationDestination(item: $opened) { id in ServicePlanDetailView(model: model, planID: id) }
        .navigationTitle("Service planner")
        .analyticsScreen(.servicePlanner)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ plan: ServicePlan) -> String {
        guard !plan.items.isEmpty else { return "No hymns" }
        return plan.numbers.map(String.init).joined(separator: " · ")
    }
}

struct ServicePlanDetailView: View {
    let model: ReaderModel
    let planID: UUID
    @State private var numberText = ""
    @State private var pitchFor: Int?
    @FocusState private var numberFocused: Bool
    private var planner: ServicePlanner { .shared }

    var body: some View {
        if let plan = planner.plan(id: planID) {
            editor(plan)
        } else {
            ExtrasEmptyState(title: "Plan deleted", symbol: "list.number", message: "This plan no longer exists.")
        }
    }

    private func editor(_ plan: ServicePlan) -> some View {
        let binding = Binding(get: { planner.plan(id: planID) ?? plan }, set: { planner.update($0) })
        let playable = plan.numbers.filter { model.hymnal.hymn(number: $0) != nil }
        return List {
            Section {
                TextField("Name", text: binding.name)
                    .font(.body.weight(.semibold))
                DatePicker("Date", selection: Binding(get: { plan.date ?? .now }, set: { binding.wrappedValue.date = $0 }),
                           displayedComponents: .date)
            }

            Section {
                Button {
                    Extras.shared.startChurchMode(playable, in: model, from: .servicePlan)
                } label: {
                    Label("Start in church mode", systemImage: "rectangle.on.rectangle")
                        .font(.body.weight(.semibold))
                }
                .disabled(playable.isEmpty)
            }

            Section {
                ForEach(binding.items) { $item in
                    HStack {
                        HymnNumberRow(hymnal: model.hymnal, number: item.number, caption: item.role)
                        Spacer(minLength: 8)
                        Menu {
                            Picker("Role", selection: $item.role) {
                                Text("None").tag(String?.none)
                                ForEach(ServicePlanner.roles, id: \.self) { Text($0).tag(Optional($0)) }
                            }
                            Button("Open in reader", systemImage: "book") { Extras.shared.open(item.number, in: model, source: .servicePlan) }
                            Button("Pitch pipe", systemImage: "tuningfork") { pitchFor = item.number }
                        } label: {
                            Image(systemName: "ellipsis.circle").imageScale(.large)
                        }
                        .accessibilityLabel("Options for hymn \(item.number)")
                    }
                }
                .onMove { binding.wrappedValue.items.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { binding.wrappedValue.items.remove(atOffsets: $0) }

                if !plan.numbers.contains(model.hymn.id) {
                    Button {
                        planner.add(model.hymn.id, to: planID)
                        Haptics.play(.selection)
                    } label: {
                        Label("Add hymn \(model.hymn.id), \(model.hymn.title)", systemImage: "plus.circle")
                    }
                }
                HStack {
                    Image(systemName: "number").foregroundStyle(.secondary)
                    TextField("Add by number", text: $numberText)
                        .keyboardType(.numberPad)
                        .focused($numberFocused)
                        .onSubmit(addTypedNumber)
                    if let number = Int(numberText) {
                        Button("Add") { addTypedNumber() }
                            .disabled(model.hymnal.hymn(number: number) == nil)
                    }
                }
                if let number = Int(numberText) {
                    Text(model.hymnal.hymn(number: number)?.title ?? "No hymn \(number) in \(model.hymnal.name)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Hymns")
            } footer: {
                if plan.items.count > 1 { Text("Touch and hold a hymn to move it. Swipe left to remove it.") }
            }
        }
        .navigationTitle(plan.name)
        .analyticsScreen(.servicePlan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Add") { addTypedNumber() }.disabled(Int(numberText).flatMap(model.hymnal.hymn(number:)) == nil)
            }
        }
        .sheet(item: Binding(get: { pitchFor.map(PitchTarget.init) }, set: { pitchFor = $0?.id })) { target in
            if let hymn = model.hymnal.hymn(number: target.id) {
                NavigationStack {
                    PitchPipeView(hymnal: model.hymnal, hymn: hymn)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { pitchFor = nil } } }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func addTypedNumber() {
        guard let number = Int(numberText), model.hymnal.hymn(number: number) != nil else { return }
        planner.add(number, to: planID)
        numberText = ""
        Haptics.play(.selection)
    }

    private struct PitchTarget: Identifiable { let id: Int }
}
