//
//  AboutHymnView.swift
//  Advent Praise
//
//  The scripture chip and the Scripture index, a page in the More drawer
//  that lists every cited passage in canonical order (a passage's hymns are
//  in DrawerPages.swift). About this hymn itself is a drawer:
//  AboutHymnDrawer.swift.
//

import SwiftUI

// MARK: - Scripture chip

/// A passage as a capsule. Tapping opens it on bible.com, a universal link
/// that YouVersion claims when it's installed (Safari opens it otherwise).
struct ScriptureChip: View {
    let passage: Passage
    var isEcho = false
    var title: String? = nil
    var onOpen: () -> Void = {}
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let url = passage.bibleURL else { return }
            onOpen()
            openURL(url)
        } label: {
            // Not a Label: inside a List row it would collapse to its icon.
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "book").imageScale(.small)
                Text((isEcho ? "≈ " : "") + (title ?? passage.reference))
            }
        }
        .buttonStyle(ToolChipStyle(isSelected: false))
        .accessibilityLabel(title ?? passage.reference)
        .accessibilityValue(isEcho ? "Echoed, not quoted" : "")
        .accessibilityHint("Opens in the Bible app")
    }
}

// MARK: - Scripture index

/// Every linked passage, by book, as a page in the More drawer. A passage
/// pushes its hymns (`openPassage`).
struct ScriptureIndexPage: View {
    let model: ReaderModel
    let openPassage: (Passage) -> Void
    @State private var query = ""

    private var index: [PassageHymns] {
        let all = ScriptureLinks.index(hymnal: model.hymnal.id)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.passage.reference.localizedCaseInsensitiveContains(q) }
    }

    /// Passages grouped by book, books in canonical order.
    private var books: [(book: String, entries: [PassageHymns])] {
        var groups: [(book: String, entries: [PassageHymns])] = []
        for entry in index {
            if groups.last?.book == entry.passage.book { groups[groups.count - 1].entries.append(entry) }
            else { groups.append((entry.passage.book, [entry])) }
        }
        return groups
    }

    var body: some View {
        let books = books
        DrawerPageLayout {
            DrawerSearchField(prompt: "Book or reference", text: $query)
            if books.isEmpty {
                DrawerNote(query.isEmpty
                           ? "Passages haven’t been linked to hymns in \(model.hymnal.name) yet."
                           : "No linked passage matches “\(query)”.")
            }
            // Hundreds of passages: groups are built as they scroll in.
            LazyVStack(alignment: .leading, spacing: DS.Space.m) {
                ForEach(books, id: \.book) { group in
                    DSInsetGroup(title: "\(group.book)") {
                        ForEach(group.entries) { entry in
                            MoreRow(title: "\(entry.passage.reference)",
                                    detail: entry.numbers.count == 1 ? String(localized: "1 hymn")
                                                                     : String(localized: "\(entry.numbers.count) hymns"),
                                    isLast: entry.id == group.entries.last?.id) {
                                Image(systemName: "book")
                            } action: { openPassage(entry.passage) }
                        }
                    }
                }
            }
        }
        .analyticsScreen(.scriptureIndex)
    }
}
