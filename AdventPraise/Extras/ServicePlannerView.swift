//
//  ServicePlannerView.swift
//  Advent Praise
//
//  Service plans for the open hymnal, and the editor for one plan, both
//  pages in More. The list leads with the next service; the
//  editor has one header (name and date), "Start in church mode", the hymns
//  in order (each with a role, a pitch pipe, and moves and removal in its
//  ••• menu) and an add-by-number field.
//

import SwiftUI

struct ServicePlansPage: View {
    let model: ReaderModel
    let openPlan: (UUID) -> Void
    @Environment(\.dsSurface) private var surface
    private var planner: ServicePlanner { .shared }

    var body: some View {
        let plans = planner.plans(for: model.hymnal.id)
        let next = plans.filter(\.isUpcoming).min { $0.sortDate < $1.sortDate }
        let comingUp = plans.filter { $0.isUpcoming && $0.id != next?.id }.sorted { $0.sortDate < $1.sortDate }
        let past = plans.filter { !$0.isUpcoming }
        DrawerPageLayout {
            if plans.isEmpty {
                emptyState
            } else {
                if let next {
                    DSInsetGroup(title: "Next service") {
                        Button { openPlan(next.id) } label: {
                            PlanLink { NextServiceCard(plan: next) }
                                .background(surface.tint.opacity(DS.Fill.tintActive))
                        }
                        .buttonStyle(.plain)
                        .modifier(PlanRowActions(model: model, plan: next))
                    }
                }
                DSInsetGroup { createButton }
                DrawerNote("Plans list hymns from \(model.hymnal.name) in the order they’ll be sung.")
                planSection("Coming up", comingUp)
                planSection("Past", past)
            }
        }
        .analyticsScreen(.servicePlanner)
    }

    @ViewBuilder private func planSection(_ title: LocalizedStringKey, _ plans: [ServicePlan]) -> some View {
        if !plans.isEmpty {
            DSInsetGroup(title: title) {
                ForEach(plans) { plan in
                    Button { openPlan(plan.id) } label: {
                        PlanLink(isLast: plan.id == plans.last?.id) { PlanRow(plan: plan) }
                    }
                    .buttonStyle(.plain)
                    .modifier(PlanRowActions(model: model, plan: plan))
                }
            }
        }
    }

    private var createButton: some View {
        Button(action: newPlan) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(surface.onTint)
                    .frame(width: DS.Size.numberTile, height: DS.Size.numberTile)
                    .background(Circle().fill(surface.tint))
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text("New service plan").font(DS.Typeface.label).foregroundStyle(surface.tint)
                    Text("Starts with hymn \(model.hymn.id, format: .hymnNumber), \(model.hymn.title)")
                        .font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.xs)
            .frame(minHeight: DS.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "list.number")
                .font(.system(.largeTitle, weight: .medium))
                .foregroundStyle(surface.tint)
                .frame(width: 76, height: 76)
                .background(Circle().fill(surface.tint.opacity(DS.Fill.tintSelected)))
                .accessibilityHidden(true)
            Text("Plan this week’s service").font(DS.Typeface.sheetTitle).multilineTextAlignment(.center)
            Text("List the hymns in the order they’ll be sung, then sing them in church mode.")
                .font(DS.Typeface.detail).foregroundStyle(surface.secondary).multilineTextAlignment(.center)
            GlassButton(title: "New service plan", systemImage: "plus", fullWidth: true, action: newPlan)
                .padding(.top, DS.Space.s)
            Text("Starts with hymn \(model.hymn.id, format: .hymnNumber), \(model.hymn.title).")
                .font(DS.Typeface.caption).foregroundStyle(surface.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.l)
    }

    /// The drawer plays the push's haptic.
    private func newPlan() {
        openPlan(planner.newPlan(hymnal: model.hymnal.id, numbers: [model.hymn.id]).id)
    }
}

/// A plan in the list as a row that leads on: its content, a chevron, a divider.
private struct PlanLink<Content: View>: View {
    var isLast = true
    @ViewBuilder let content: Content
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.m) {
            content
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(surface.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.xxs)
        .frame(minHeight: DS.Size.row)
        .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, DS.Space.m) } }
        .contentShape(Rectangle())
    }
}

/// Touch-and-hold actions on a plan in the list.
private struct PlanRowActions: ViewModifier {
    let model: ReaderModel
    let plan: ServicePlan

    func body(content: Content) -> some View {
        let playable = plan.numbers.filter { model.hymnal.hymn(number: $0) != nil }
        content
            .contextMenu {
                Button("Start in church mode", systemImage: "rectangle.on.rectangle") {
                    Extras.shared.startChurchMode(playable, named: plan.name, in: model, from: .servicePlan)
                }
                .disabled(playable.isEmpty)
                Button("Delete", systemImage: "trash", role: .destructive) { ServicePlanner.shared.delete(plan) }
            }
            .accessibilityAction(named: "Delete") { ServicePlanner.shared.delete(plan) }
    }
}

// MARK: - List rows

/// The coming service, large: when, what, and the hymn numbers.
private struct NextServiceCard: View {
    let plan: ServicePlan
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(plan.relativeDay ?? plan.dateText ?? String(localized: "No date"))
                .dsEyebrow()
                .foregroundStyle(surface.tint)
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text(plan.name).font(DS.Typeface.sheetTitle)
                if plan.relativeDay != nil, let date = plan.dateText {
                    Text(date).font(DS.Typeface.detail).foregroundStyle(surface.secondary)
                }
            }
            if plan.items.isEmpty {
                Text("No hymns yet").font(DS.Typeface.detail).foregroundStyle(surface.secondary)
            } else {
                HymnNumberChips(numbers: plan.numbers)
            }
        }
        .padding(.vertical, DS.Space.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Next service: \(plan.name), \(plan.dateText ?? "")"))
        .accessibilityValue(Text(plan.hymnSummary))
    }
}

/// Up to five hymn numbers as brass tiles, then "+N".
private struct HymnNumberChips: View {
    let numbers: [Int]
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            ForEach(Array(numbers.prefix(5).enumerated()), id: \.offset) { _, number in
                Text(String(number))
                    .font(DS.Typeface.numeral).monospacedDigit()
                    .foregroundStyle(surface.brass)
                    .lineLimit(1)
                    .padding(.horizontal, DS.Space.xs)
                    .frame(minWidth: tileSize, minHeight: tileSize)
                    .background(RoundedRectangle.ds(DS.Radius.badge).fill(surface.brass.opacity(DS.Fill.tintSelected)))
            }
            if numbers.count > 5 {
                Text("+\(numbers.count - 5)").font(DS.Typeface.label).foregroundStyle(surface.secondary)
            }
        }
    }
}

/// A plan in the list: a calendar tile, the name, and its hymns.
private struct PlanRow: View {
    let plan: ServicePlan
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = 44

    var body: some View {
        HStack(spacing: DS.Space.m) {
            VStack(spacing: 0) {
                if let date = plan.date {
                    Text(date.formatted(.dateTime.month(.abbreviated))).dsEyebrow(tracking: 0.6)
                        .foregroundStyle(surface.tint)
                    Text(date.formatted(.dateTime.day())).font(DS.Typeface.numeral).monospacedDigit()
                } else {
                    Image(systemName: "calendar").foregroundStyle(surface.secondary)
                }
            }
            .frame(width: tileSize, height: tileSize)
            .background(RoundedRectangle.ds(DS.Radius.badge).fill(surface.tint.opacity(DS.Fill.tintActive)))
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text(plan.name).font(DS.Typeface.rowTitle).lineLimit(2)
                Text(plan.hymnSummary).font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, DS.Space.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(plan.name), \(plan.dateText ?? "")"))
        .accessibilityValue(Text(plan.hymnSummary))
    }
}

// MARK: - Plan editor

struct ServicePlanPage: View {
    let model: ReaderModel
    let planID: UUID
    /// Pushes the pitch pipe for a hymn of the plan.
    let openPitch: (Int) -> Void
    @State private var numberText = ""
    @State private var isPickingDate = false
    @FocusState private var numberFocused: Bool
    @FocusState private var nameFocused: Bool
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var planner: ServicePlanner { .shared }

    var body: some View {
        if let plan = planner.plan(id: planID) {
            editor(plan)
        } else {
            DrawerPageLayout { DrawerNote("This plan no longer exists.") }
        }
    }

    private func editor(_ plan: ServicePlan) -> some View {
        let binding = Binding(get: { planner.plan(id: planID) ?? plan }, set: { planner.update($0) })
        let playable = plan.numbers.filter { model.hymnal.hymn(number: $0) != nil }
        return ScrollViewReader { proxy in
            DrawerPageLayout {
                header(plan, binding: binding)
                startButton(plan, playable: playable)
                hymns(plan, binding: binding)
                addHymns(plan)
            }
            // Each hymn added pushes the field down a row: follow it, so the field
            // and its title preview stay just above the keyboard while typing.
            // Focusing waits for the keyboard to lift the drawer and the card to settle.
            .onChange(of: numberFocused) { _, focused in if focused { revealAddField(proxy, after: 450) } }
            .onChange(of: plan.items.count) { _, _ in if numberFocused { revealAddField(proxy) } }
        }
        .analyticsScreen(.servicePlan)
    }

    // MARK: Header

    private func header(_ plan: ServicePlan, binding: Binding<ServicePlan>) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            TextField("Plan name", text: binding.name)
                .font(DS.Typeface.hymnTitle)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .accessibilityLabel("Plan name")

            Button { isPickingDate = true } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "calendar")
                    Text(plan.dateText ?? String(localized: "Add a date"))
                    if let relative = plan.relativeDay {
                        Text("· \(relative)").foregroundStyle(surface.secondary)
                    }
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(surface.secondary)
                }
                .font(DS.Typeface.label)
                .foregroundStyle(surface.tint)
                .padding(.horizontal, DS.Space.m)
                .frame(minHeight: 36)
                .background(Capsule().fill(surface.tint.opacity(DS.Fill.tintActive)))
                .contentShape(Capsule())
            }
            .buttonStyle(DSPressStyle())
            .accessibilityLabel(Text("Date, \(plan.dateText ?? String(localized: "none"))"))
            .accessibilityHint("Changes the date.")
            .popover(isPresented: $isPickingDate) {
                DatePicker("Date", selection: Binding(get: { plan.date ?? .now }, set: {
                    binding.wrappedValue.date = $0
                    isPickingDate = false
                }), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(surface.tint)
                .frame(minWidth: 320)
                .padding(DS.Space.m)
                .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal, DS.Space.xxs)
    }

    private func startButton(_ plan: ServicePlan, playable: [Int]) -> some View {
        VStack(spacing: DS.Space.xs) {
            GlassButton(title: "Start in church mode", systemImage: "rectangle.on.rectangle", fullWidth: true) {
                Extras.shared.startChurchMode(playable, named: plan.name, in: model, from: .servicePlan)
            }
            .disabled(playable.isEmpty)
            .accessibilityHint(playable.isEmpty ? "Add a hymn first." : "Sings these hymns in order, full screen.")
            if playable.isEmpty {
                Text(plan.items.isEmpty ? "Add a hymn to start church mode." : "None of these hymns are in \(model.hymnal.name).")
                    .font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Hymns

    @ViewBuilder
    private func hymns(_ plan: ServicePlan, binding: Binding<ServicePlan>) -> some View {
        if plan.items.isEmpty {
            emptyHymns
        } else {
            DSInsetGroup(title: plan.items.count == 1 ? "1 hymn" : "\(plan.items.count) hymns") {
                ForEach(binding.items) { $item in
                    let index = plan.items.firstIndex { $0.id == item.id } ?? 0
                    PlanHymnRow(hymnal: model.hymnal, item: $item,
                                canMoveUp: index > 0, canMoveDown: index < plan.items.count - 1,
                                open: { Extras.shared.open(item.number, in: model, source: .servicePlan) },
                                pitch: { openPitch(item.number) },
                                move: { move(item.id, by: $0, in: binding) },
                                remove: { remove(item.id, from: binding) })
                        .padding(.horizontal, DS.Space.m)
                        .overlay(alignment: .bottom) {
                            if item.id != plan.items.last?.id { Divider().padding(.leading, 64) }
                        }
                }
            }
            if plan.items.count > 1 {
                DrawerNote("To reorder or remove a hymn, use its ••• menu.")
            }
        }
    }

    private func move(_ id: ServicePlan.Item.ID, by step: Int, in binding: Binding<ServicePlan>) {
        guard let from = binding.wrappedValue.items.firstIndex(where: { $0.id == id }) else { return }
        let to = from + step
        guard binding.wrappedValue.items.indices.contains(to) else { return }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            binding.wrappedValue.items.swapAt(from, to)
        }
        Haptics.play(.selection)
    }

    private func remove(_ id: ServicePlan.Item.ID, from binding: Binding<ServicePlan>) {
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            binding.wrappedValue.items.removeAll { $0.id == id }
        }
        Haptics.play(.selection)
    }

    private var emptyHymns: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: "music.note.list")
                .font(.title2.weight(.medium))
                .foregroundStyle(surface.brass)
                .frame(width: 56, height: 56)
                .background(Circle().fill(surface.brass.opacity(DS.Fill.tintSelected)))
            Text("No hymns yet").font(DS.Typeface.panelTitle)
            Text("Add the hymns in the order they’ll be sung, by number or from the hymn you’re reading.")
                .font(DS.Typeface.detail).foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.m)
        .accessibilityElement(children: .combine)
    }

    // MARK: Add

    private func addHymns(_ plan: ServicePlan) -> some View {
        let addsCurrent = !plan.numbers.contains(model.hymn.id)
        return DSInsetGroup(title: "Add hymns") {
            if addsCurrent {
                Button {
                    planner.add(model.hymn.id, to: planID)
                    Haptics.play(.selection)
                } label: {
                    AddRow(number: String(model.hymn.id), title: model.hymn.title,
                           caption: String(localized: "The hymn you’re reading"))
                        .padding(.horizontal, DS.Space.m)
                        .padding(.vertical, DS.Space.xs)
                        .overlay(alignment: .bottom) { Divider().padding(.leading, 64) }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Add hymn \(model.hymn.id, format: .hymnNumber),\(model.hymn.title)"))
                .accessibilityAddTraits(.isButton)
            }
            numberField
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.xs)
                .id(AddField.id)
        }
    }

    private var numberField: some View {
        let number = Int(numberText)
        let hymn = number.flatMap(model.hymnal.hymn(number:))
        return HStack(spacing: DS.Space.m) {
            NumberTile(text: "#", isPlaceholder: true)
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                TextField("Add by number", text: $numberText)
                    .font(DS.Typeface.rowTitle)
                    .keyboardType(.numberPad)
                    .focused($numberFocused)
                    .onSubmit(addTypedNumber)
                if let number {
                    Text(hymn?.title ?? String(localized: "No hymn \(number, format: .hymnNumber) in \(model.hymnal.name)"))
                        .font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                        .transition(.opacity)
                }
            }
            Button(action: addTypedNumber) {
                Image(systemName: "plus.circle.fill").font(.title2)
                    .foregroundStyle(hymn == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(surface.tint))
            }
            .buttonStyle(.plain)
            .disabled(hymn == nil)
            .accessibilityLabel("Add")
        }
        .frame(minHeight: DS.Size.hitTarget)
        .animation(DS.Motion.quick, value: number != nil)
    }

    private func addTypedNumber() {
        guard let number = Int(numberText), model.hymnal.hymn(number: number) != nil else { return }
        planner.add(number, to: planID)
        numberText = ""
        Haptics.play(.selection)
    }

    private enum AddField: Hashable { case id }

    /// Scrolls the add-by-number field to the bottom of the drawer, just
    /// above the keyboard. Runs on the next turn at the earliest, once rows
    /// just added or removed are laid out.
    private func revealAddField(_ proxy: ScrollViewProxy, after milliseconds: Int = 0) {
        Task {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(AddField.id, anchor: .bottom) }
        }
    }
}

/// One hymn of the plan: number tile, role, title, and its options.
private struct PlanHymnRow: View {
    let hymnal: Hymnal
    @Binding var item: ServicePlan.Item
    let canMoveUp: Bool
    let canMoveDown: Bool
    let open: () -> Void
    let pitch: () -> Void
    /// -1 up, +1 down.
    let move: (Int) -> Void
    let remove: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let title = hymnal.hymn(number: item.number)?.title
        HStack(spacing: DS.Space.m) {
            NumberTile(text: String(item.number))
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                if let role = item.role {
                    Text(role).dsEyebrow(tracking: 0.8).foregroundStyle(surface.tint)
                }
                Text(title ?? String(localized: "Not in \(hymnal.name)"))
                    .font(DS.Typeface.rowTitle)
                    .foregroundStyle(title == nil ? surface.secondary : .primary)
                    .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
            }
            Spacer(minLength: DS.Space.s)
            Menu {
                Picker("Role", selection: $item.role) {
                    Text("None").tag(String?.none)
                    ForEach(ServicePlanner.roles, id: \.self) { Text($0).tag(Optional($0)) }
                }
                if title != nil {
                    Button("Open in reader", systemImage: "book", action: open)
                    Button("Pitch pipe", systemImage: "tuningfork", action: pitch)
                }
                Section {
                    Button("Move up", systemImage: "arrow.up") { move(-1) }.disabled(!canMoveUp)
                    Button("Move down", systemImage: "arrow.down") { move(1) }.disabled(!canMoveDown)
                    Button("Remove", systemImage: "trash", role: .destructive, action: remove)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(surface.secondary)
                    .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for hymn \(item.number, format: .hymnNumber)")
        }
        .frame(minHeight: DS.Size.row)
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if canMoveUp { Button("Move up") { move(-1) } }
            if canMoveDown { Button("Move down") { move(1) } }
            Button("Remove", action: remove)
        }
    }
}

/// "The hymn you're reading" suggestion in the Add hymns section.
private struct AddRow: View {
    let number: String
    let title: String
    let caption: String
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.m) {
            NumberTile(text: number)
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text(caption).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                Text(title).font(DS.Typeface.rowTitle).lineLimit(1)
            }
            Spacer(minLength: DS.Space.s)
            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(surface.tint)
        }
        .frame(minHeight: DS.Size.hitTarget)
        .contentShape(Rectangle())
    }
}

/// A hymn number in a brass tile, as in HymnRow.
private struct NumberTile: View {
    let text: String
    var isPlaceholder = false
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = DS.Size.numberTile

    var body: some View {
        Text(text)
            .font(DS.Typeface.numeral).monospacedDigit()
            .foregroundStyle(isPlaceholder ? surface.secondary : surface.brass)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .frame(minWidth: tileSize, minHeight: tileSize)
            .background(RoundedRectangle.ds(DS.Radius.badge)
                .fill(isPlaceholder ? Color.primary.opacity(DS.Fill.inset) : surface.brass.opacity(DS.Fill.tintSelected)))
            .accessibilityHidden(isPlaceholder)
    }
}

// MARK: - Dates

private extension ServicePlan {
    /// Today or later; a plan without a date counts as coming up.
    var isUpcoming: Bool { date.map { $0 >= Calendar.current.startOfDay(for: .now) } ?? true }
    var sortDate: Date { date ?? .distantFuture }

    var dateText: String? { date?.formatted(.dateTime.weekday(.wide).day().month(.wide)) }

    /// "Today", "Tomorrow", "In 3 days" within the next two weeks.
    var relativeDay: String? {
        guard let date else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case 2...13: return String(localized: "In \(days) days")
        default: return nil
        }
    }

    /// "4 hymns · 1 · 12 · 100 · 412", or "No hymns".
    var hymnSummary: String {
        guard !items.isEmpty else { return String(localized: "No hymns") }
        let count = items.count == 1 ? String(localized: "1 hymn") : String(localized: "\(items.count) hymns")
        return ([count] + numbers.map(String.init)).joined(separator: " · ")
    }
}
