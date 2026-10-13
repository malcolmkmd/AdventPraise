//
//  ServicePlanner.swift
//  Advent Praise
//
//  Ordered hymn lists for a service ("Sabbath 14 June": opening, before the
//  sermon, closing). A plan belongs to one hymnal and runs in church mode
//  like a playlist, stopping after its last hymn. Saved in UserDefaults.
//

import Foundation
import Observation

struct ServicePlan: Identifiable, Hashable, Codable, Sendable {
    struct Item: Identifiable, Hashable, Codable, Sendable {
        var id = UUID()
        var number: Int
        /// Where it falls in the service, e.g. "Opening hymn". Optional.
        var role: String?
    }

    var id = UUID()
    var name: String
    var hymnal: String
    var date: Date?
    var items: [Item] = []

    var numbers: [Int] { items.map(\.number) }
}

@Observable
@MainActor
final class ServicePlanner {
    static let shared = ServicePlanner()

    /// Suggested roles; any text is allowed.
    static let roles = ["Opening hymn", "Hymn of praise", "Before the sermon", "Response", "Closing hymn"]

    private(set) var plans: [ServicePlan] { didSet { save() } }
    private static let key = "service.plans.v1"
    /// Set once plans of removed hymnals have been copied to English.
    private static let removedHymnalsMovedKey = "service.removedHymnalsMoved.v1"

    private init() {
        plans = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([ServicePlan].self, from: $0) } ?? []
        copyPlansOffRemovedHymnals()
    }

    /// Once: each plan for a hymnal 7.0 no longer ships (`RemovedHymnals`)
    /// gets an English copy holding the hymns that have an English match.
    /// The original stays, hidden, in case its hymnal comes back.
    private func copyPlansOffRemovedHymnals() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.removedHymnalsMovedKey) else { return }
        defaults.set(true, forKey: Self.removedHymnalsMovedKey)
        let stranded = plans.filter { RemovedHymnals.contains($0.hymnal) }
        guard !stranded.isEmpty, let english = Hymnal.load(.default) else { return }
        let map = RemovedHymnals(english: english)
        plans += stranded.map { plan in
            ServicePlan(name: RemovedHymnals.copyName(plan.name, from: plan.hymnal), hymnal: english.id, date: plan.date,
                        items: plan.items.compactMap { item in
                            map.englishNumber(item.number, in: plan.hymnal).map { ServicePlan.Item(number: $0, role: item.role) }
                        })
        }
    }

    func plans(for hymnal: String) -> [ServicePlan] {
        plans.filter { $0.hymnal == hymnal }
            .sorted { ($0.date ?? .distantPast, $0.name) > ($1.date ?? .distantPast, $1.name) }
    }

    func plan(id: UUID) -> ServicePlan? { plans.first { $0.id == id } }

    @discardableResult
    func newPlan(hymnal: String, numbers: [Int] = []) -> ServicePlan {
        let date = Self.nextSabbath()
        let plan = ServicePlan(name: date.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                               hymnal: hymnal, date: date,
                               items: numbers.map { ServicePlan.Item(number: $0) })
        plans.append(plan)
        Analytics.track(.servicePlanCreated(hymnCount: plan.items.count))
        return plan
    }

    /// Every edit from the plan editor. Name and date changes aren't tracked
    /// (they arrive a keystroke at a time); hymn changes are.
    func update(_ plan: ServicePlan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let old = plans[i]
        plans[i] = plan
        if let edit = Self.edit(from: old, to: plan) {
            Analytics.track(.servicePlanEdited(action: edit, hymnCount: plan.items.count))
        }
    }

    private static func edit(from old: ServicePlan, to new: ServicePlan) -> ServicePlanEdit? {
        if new.items.count > old.items.count { return .hymnAdded }
        if new.items.count < old.items.count { return .hymnRemoved }
        if new.items.map(\.id) != old.items.map(\.id) { return .reordered }
        if new.items.map(\.role) != old.items.map(\.role) { return .roleSet }
        return nil
    }

    func delete(_ plan: ServicePlan) {
        plans.removeAll { $0.id == plan.id }
        Analytics.track(.servicePlanDeleted(hymnCount: plan.items.count))
    }

    func add(_ number: Int, to planID: UUID) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].items.append(.init(number: number))
        Analytics.track(.servicePlanEdited(action: .hymnAdded, hymnCount: plans[i].items.count))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plans) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// Today if it is Saturday, otherwise the coming Saturday.
    private static func nextSabbath(from now: Date = .now) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if calendar.component(.weekday, from: today) == 7 { return today }
        return calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? today
    }
}
