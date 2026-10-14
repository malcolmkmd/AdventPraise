//
//  AboutHymnView.swift
//  Advent Praise
//
//  The scripture chip, a passage's hymns and the Scripture index, which
//  lists every cited passage in canonical order. About this hymn itself is
//  a drawer: AboutHymnDrawer.swift.
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

// MARK: - Passage → hymns

struct PassageHymnsView: View {
    let model: ReaderModel
    let passage: Passage
    var excluding: Int? = nil

    private var numbers: [Int] {
        ScriptureLinks.hymns(citing: passage, hymnal: model.hymnal.id, excluding: excluding)
    }

    var body: some View {
        List {
            if passage.bibleURL != nil {
                Section {
                    ScriptureChip(passage: passage, title: "Read \(passage.reference)") {
                        Analytics.track(.scriptureOpened(
                            hymnal: model.hymnal.id, number: nil, book: BibleBook.usfm(for: passage.book) ?? "",
                            confidence: nil, surface: .passage))
                    }
                    .padding(.vertical, DS.Space.xs)
                }
            }
            if numbers.isEmpty {
                ExtrasEmptyState(title: "No other hymns", symbol: "text.book.closed",
                                 message: "No other hymn in \(model.hymnal.name) is linked to \(passage.reference).")
                    .listRowBackground(Color.clear)
            } else {
                Section("Hymns on \(passage.reference)") {
                    ForEach(numbers, id: \.self) { number in
                        Button { Extras.shared.open(number, in: model, source: .scripture) } label: {
                            HymnNumberRow(hymnal: model.hymnal, number: number)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(passage.reference)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Scripture index

struct ScriptureIndexView: View {
    let model: ReaderModel
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
        List {
            if books.isEmpty {
                ExtrasEmptyState(title: "No scripture links yet", symbol: "text.book.closed",
                                 message: query.isEmpty
                                    ? "Passages haven’t been linked to hymns in \(model.hymnal.name) yet."
                                    : "No linked passage matches “\(query)”.")
                    .listRowBackground(Color.clear)
            }
            ForEach(books, id: \.book) { group in
                Section(group.book) {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            PassageHymnsView(model: model, passage: entry.passage)
                        } label: {
                            LabeledContent(entry.passage.reference,
                                           value: entry.numbers.count == 1 ? "1 hymn" : "\(entry.numbers.count) hymns")
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Book or reference")
        .navigationTitle("Scripture index")
        .analyticsScreen(.scriptureIndex)
        .navigationBarTitleDisplayMode(.inline)
    }
}
