//
//  Extras.swift
//  Advent Praise
//
//  The tools beside the reader: hymn stories and scripture, collections,
//  the pitch pipe, the memory game and the service planner. They hang off one
//  "Tools" group in the More drawer and one sheet on the reader, so the rest
//  of the app only needs `ExtraSheet.toolsOrder` and `.extrasSheets(model:)`.
//  Support Advent Praise (the tips), About Advent Praise and Privacy &
//  credits ride the same sheet from More.
//

import SwiftUI
import Observation

enum ExtraSheet: String, Identifiable, CaseIterable {
    case about, scripture, collections, pitch, memory, planner
    /// The tips, from More → Support. Not a tool, but the same kind of screen.
    case support
    /// About Advent Praise and Privacy & credits, from More → About.
    case aboutApp, privacy
    var id: String { rawValue }
}

@Observable
@MainActor
final class Extras {
    static let shared = Extras()

    var sheet: ExtraSheet?
    private var afterDismiss: (() -> Void)?

    private init() {}

    /// Closes the sheet, then runs `action` once it has gone — needed before
    /// presenting church mode, which is a separate full-screen cover.
    func dismiss(then action: @escaping () -> Void) {
        afterDismiss = action
        sheet = nil
    }

    fileprivate func didDismiss() {
        let action = afterDismiss
        afterDismiss = nil
        action?()
    }

    /// Opens hymn `number` in the reader and closes the sheet.
    func open(_ number: Int, in model: ReaderModel, source: HymnSource) {
        model.open(number: number, source: source)
        sheet = nil
    }

    enum Queue { case servicePlan, collection }

    /// Runs `numbers` in church mode, in order, stopping after the last.
    /// `name` heads the list in church mode's number pad.
    func startChurchMode(_ numbers: [Int], named name: String, in model: ReaderModel, from queue: Queue) {
        dismiss {
            guard model.play(queue: numbers, named: name,
                             source: queue == .servicePlan ? .servicePlan : .collection) else { return }
            switch queue {
            case .servicePlan:
                Analytics.track(.servicePlanStarted(hymnCount: numbers.count))
                model.enterChurchMode(from: .servicePlan)
            case .collection:
                Analytics.track(.collectionStarted(hymnCount: numbers.count))
                model.enterChurchMode(from: .collection)
            }
        }
    }
}

// MARK: - Presentation

private struct ExtrasSheets: ViewModifier {
    @Bindable var model: ReaderModel
    @Bindable private var extras = Extras.shared
    @Environment(ReadingSettings.self) private var settings

    func body(content: Content) -> some View {
        // Opened from More, Done (or a swipe) goes back to More. A hymn or
        // church mode opened from the sheet moves on instead (see ReaderModel.show).
        content.sheet(item: $extras.sheet, onDismiss: { extras.didDismiss(); model.returnToMore() }) { sheet in
            NavigationStack {
                root(sheet)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { extras.sheet = nil }
                                .fontWeight(.semibold)
                        }
                    }
            }
            // The sheet is on the reading surface, not the system appearance:
            // otherwise a light sheet inherits a dark surface's light text.
            .modifier(ToolSheetChrome(surface: settings.surface))
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func root(_ sheet: ExtraSheet) -> some View {
        switch sheet {
        case .about: AboutHymnView(model: model)
        case .scripture: ScriptureIndexView(model: model)
        case .collections: CollectionsView(model: model)
        case .pitch: PitchPipeView(hymnal: model.hymnal, hymn: model.hymn)
        case .memory: MemoryGameView(hymnal: model.hymnal, hymn: model.hymn)
        case .planner: ServicePlansView(model: model)
        case .support: SupportView()
        case .aboutApp: AboutAppView()
        case .privacy: PrivacyPolicyView()
        }
    }
}

extension View {
    /// Presents the Tools sheets. Attach once, to the reader.
    func extrasSheets(model: ReaderModel) -> some View { modifier(ExtrasSheets(model: model)) }
}

// MARK: - Tools group (rows live in MoreDrawer)

extension ExtraSheet {
    /// The Tools rows in the More drawer, in order. About this hymn is in the
    /// reader menu and Memorise in the Lectern's tray, closer to the hymn.
    static let toolsOrder: [ExtraSheet] = [.scripture, .collections, .pitch, .planner]

    var title: LocalizedStringKey {
        switch self {
        case .about: "About this hymn"
        case .scripture: "Scripture index"
        case .collections: "Collections"
        case .pitch: "Pitch pipe"
        case .memory: "Memorise a verse"
        case .planner: "Service planner"
        case .support: "Support Advent Praise"
        case .aboutApp: "About Advent Praise"
        case .privacy: "Privacy Policy"
        }
    }

    var systemImage: String {
        switch self {
        case .about: "book.closed"
        case .scripture: "text.book.closed"
        case .collections: "square.stack"
        case .pitch: "tuningfork"
        case .memory: "brain.head.profile"
        case .planner: "list.number"
        case .support: "heart"
        case .aboutApp: "info.circle"
        case .privacy: "hand.raised"
        }
    }

    @MainActor func detail(for model: ReaderModel) -> String? {
        switch self {
        case .about: return "Hymn \(model.hymn.id)"
        case .collections: return String(localized: "Worship, Gospel…")
        case .pitch:
            let custom = PitchNotes.custom(hymnal: model.hymnal.id, number: model.hymn.id)
            let published = PitchNotes.published(hymnal: model.hymnal.id, number: model.hymn.id)?.note.flatMap(Pitch.midi)
            return (custom ?? published).map(Pitch.name)
        case .support: return String(localized: "Leave a tip")
        case .aboutApp: return AppInfo.version
        case .scripture, .memory, .planner, .privacy: return nil
        }
    }
}

// MARK: - Shared rows

/// "12  Watchman Blow The Gospel Trumpet", or a muted row if the number is
/// missing from this hymnal.
struct HymnNumberRow: View {
    let hymnal: Hymnal
    let number: Int
    var caption: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(String(number))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(DS.Palette.brass)
                .frame(minWidth: 36, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(hymnal.hymn(number: number)?.title ?? "Not in \(hymnal.name)")
                    .foregroundStyle(hymnal.hymn(number: number) == nil ? .secondary : .primary)
                    .lineLimit(2)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Centered message for lists that have no data yet.
struct ExtrasEmptyState: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}
