//
//  Extras.swift
//  Advent Praise
//
//  The tools beside the reader: hymn stories and scripture, collections,
//  the pitch pipe, the memory game and the service planner. They hang off one
//  "Tools" group in the More panel and one sheet on the reader, so the rest of
//  the app only needs `ExtrasMoreGroup` and `.extrasSheets(model:)`.
//

import SwiftUI
import Observation

enum ExtraSheet: String, Identifiable, CaseIterable {
    case about, scripture, collections, pitch, memory, planner
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
    func open(_ number: Int, in model: ReaderModel) {
        model.open(number: number)
        sheet = nil
    }

    /// Runs `numbers` in church mode, in order, stopping after the last.
    func startChurchMode(_ numbers: [Int], in model: ReaderModel) {
        dismiss {
            guard model.play(queue: numbers) else { return }
            model.showChurchMode = true
            Analytics.track(.churchModeStarted(hymnal: model.hymnal.id))
        }
    }
}

// MARK: - Presentation

private struct ExtrasSheets: ViewModifier {
    @Bindable var model: ReaderModel
    @Bindable private var extras = Extras.shared

    func body(content: Content) -> some View {
        content.sheet(item: $extras.sheet, onDismiss: { extras.didDismiss() }) { sheet in
            NavigationStack {
                root(sheet)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { extras.sheet = nil }
                        }
                    }
            }
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
        }
    }
}

extension View {
    /// Presents the Tools sheets. Attach once, to the reader.
    func extrasSheets(model: ReaderModel) -> some View { modifier(ExtrasSheets(model: model)) }
}

// MARK: - More panel group

struct ExtrasMoreGroup: View {
    let model: ReaderModel
    let tint: Color

    var body: some View {
        MoreGroup(title: "Tools") {
            row(.about, "About this hymn", detail: "Hymn \(model.hymn.id)", symbol: "book.closed")
            row(.scripture, "Scripture index", symbol: "text.book.closed")
            row(.collections, "Collections", detail: "Christmas, Easter…", symbol: "square.stack")
            row(.pitch, "Pitch pipe", detail: pitchDetail, symbol: "tuningfork")
            row(.memory, "Memorise a verse", symbol: "brain.head.profile")
            row(.planner, "Service planner", symbol: "list.number", isLast: true)
        }
    }

    private var pitchDetail: String? {
        let custom = PitchNotes.custom(hymnal: model.hymnal.id, number: model.hymn.id)
        let published = PitchNotes.published(hymnal: model.hymnal.id, number: model.hymn.id)?.note.flatMap(Pitch.midi)
        return (custom ?? published).map(Pitch.name)
    }

    private func row(_ sheet: ExtraSheet, _ title: String, detail: String? = nil, symbol: String,
                     isLast: Bool = false) -> some View {
        MoreRow(title: title, detail: detail, tint: tint, isLast: isLast) {
            Image(systemName: symbol)
        } action: {
            model.closeLectern()
            Extras.shared.sheet = sheet
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
                .foregroundStyle(Vesper.brass)
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
