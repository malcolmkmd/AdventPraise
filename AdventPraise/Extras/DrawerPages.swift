//
//  DrawerPages.swift
//  Advent Praise
//
//  What the pages of About this hymn's drawer and More's navigation stack
//  are built from: the page inset, a note, a group of hymns that open in
//  the reader, a search field, and the two pages both push: a passage's
//  hymns and a collection's. The drawer's bar or More's navigation bar
//  shows each page's title.
//

import SwiftUI

/// A page's body, inset like the drawer's root.
struct DrawerPageLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Space.l)
    }
}

/// A secondary note under a group.
struct DrawerNote: View {
    let text: Text
    @Environment(\.dsSurface) private var surface

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(_ string: String) { text = Text(verbatim: string) }

    var body: some View {
        text
            .font(DS.Typeface.caption)
            .foregroundStyle(surface.secondary)
            .padding(.horizontal, DS.Space.xxs)
    }
}

/// Hymns that open in the reader, which closes the drawer or More.
struct HymnNumberGroup: View {
    let title: LocalizedStringKey
    let model: ReaderModel
    let numbers: [Int]
    let source: HymnSource

    var body: some View {
        DSInsetGroup(title: title) {
            ForEach(numbers, id: \.self) { number in
                Button { Extras.shared.open(number, in: model, source: source) } label: {
                    HymnNumberRow(hymnal: model.hymnal, number: number)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(.horizontal, DS.Space.m)
                        .padding(.vertical, DS.Space.xxs)
                        .overlay(alignment: .bottom) {
                            if number != numbers.last { Divider().padding(.leading, DS.Space.m) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A search field for a page: the page filters as the user types.
struct DrawerSearchField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(surface.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .font(DS.Typeface.label)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(surface.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, DS.Space.m)
        .frame(minHeight: DS.Size.hitTarget)
        .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.row)))
    }
}

// MARK: - Shared pages

/// A passage, then the hymns that cite it, `excluding` one (the hymn being read).
struct PassageHymnsPage: View {
    let model: ReaderModel
    let passage: Passage
    var excluding: Int? = nil

    var body: some View {
        let numbers = ScriptureLinks.hymns(citing: passage, hymnal: model.hymnal.id, excluding: excluding)
        DrawerPageLayout {
            if passage.bibleURL != nil {
                ScriptureChip(passage: passage, title: "Read \(passage.reference)") {
                    Analytics.track(.scriptureOpened(
                        hymnal: model.hymnal.id, number: nil, book: BibleBook.usfm(for: passage.book) ?? "",
                        confidence: nil, surface: .passage))
                }
            }
            if numbers.isEmpty {
                DrawerNote(excluding == nil
                           ? "No hymn in \(model.hymnal.name) is linked to \(passage.reference)."
                           : "No other hymn in \(model.hymnal.name) is linked to \(passage.reference).")
            } else {
                HymnNumberGroup(title: "Hymns on \(passage.reference)", model: model,
                                numbers: numbers, source: .scripture)
            }
        }
    }
}

/// A collection's hymns in the open hymnal, to sing in church mode or copy
/// into a service plan. `openPlan` pushes the new plan; without it, the row
/// says the copy was made.
struct CollectionHymnsPage: View {
    let model: ReaderModel
    let collection: HymnCollection
    var openPlan: ((UUID) -> Void)? = nil
    @State private var copied = false

    var body: some View {
        let numbers = collection.numbers(in: model.hymnal.id).filter { model.hymnal.hymn(number: $0) != nil }
        DrawerPageLayout {
            if numbers.isEmpty {
                DrawerNote("\(model.hymnal.name) has no hymns from the SDA Hymnal’s \(collection.title) section.")
            } else {
                DSInsetGroup {
                    MoreRow(title: "Sing in church mode") {
                        Image(systemName: "rectangle.on.rectangle")
                    } action: {
                        Extras.shared.startChurchMode(numbers, named: collection.title, in: model, from: .collection)
                    }
                    MoreRow(title: copied ? "Copied to a new service plan" : "Copy to a new service plan",
                            isLast: true) {
                        Image(systemName: copied ? "checkmark" : "list.number")
                    } action: {
                        copy(numbers)
                    }
                }
                HymnNumberGroup(title: numbers.count == 1 ? "1 hymn" : "\(numbers.count) hymns",
                                model: model, numbers: numbers, source: .collection)
            }
            DrawerNote("SDA Hymnal \(collection.sdahRange)")
        }
    }

    private func copy(_ numbers: [Int]) {
        guard !copied else { return }
        let plan = ServicePlanner.shared.newPlan(hymnal: model.hymnal.id, numbers: numbers)
        Haptics.play(.selection)
        if let openPlan {
            openPlan(plan.id)
            return
        }
        copied = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Copied to a new service plan"))
    }
}
