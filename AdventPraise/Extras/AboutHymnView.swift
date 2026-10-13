//
//  AboutHymnView.swift
//  Advent Praise
//
//  "About this hymn": its story, the passages it draws on (each linking to
//  the other hymns that cite it), the collections it belongs to, where its
//  accompaniment comes from, and quick links to the pitch pipe and memory
//  game. The reader menu's About panel is its summary. Also the Scripture index, which
//  lists every cited passage in canonical order.
//

import SwiftUI

struct AboutHymnView: View {
    let model: ReaderModel
    @Environment(\.openURL) private var openURL

    private var hymnal: Hymnal { model.hymnal }
    private var hymn: Hymn { model.hymn }
    private var story: HymnStory? { HymnStories.story(hymnal: hymnal.id, number: hymn.id) }
    private var links: [ScriptureLink] { ScriptureLinks.links(hymnal: hymnal.id, number: hymn.id) }
    private var collections: [HymnCollection] { HymnCollections.containing(hymn.id, hymnal: hymnal.id) }

    private var scriptureFooter: String {
        let sources = Set(links.map(\.source))
        let labels = [ScriptureSource.lyric, .hymnal, .hymnary].filter(sources.contains).map(\.label)
        var text = "Opens the King James Version in the YouVersion Bible app, or on bible.com."
        if links.contains(where: { $0.confidence == .medium }) {
            text += " ≈ marks a passage the hymn echoes rather than quotes."
        }
        return text + " Source: " + labels.joined(separator: "; ") + "."
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(hymnal.name) \(hymn.id)")
                        .scaledFont(size: 11, weight: .bold).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(hymn.title)
                        .scaledFont(size: 24, weight: .semibold, design: .serif)
                        .accessibilityAddTraits(.isHeader)
                }
                .listRowBackground(Color.clear)
            }

            Section("Story") {
                if let story {
                    StoryContent(story: story)
                } else {
                    Text("No story has been added for this hymn yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if links.isEmpty {
                    Text("No scripture passages have been linked to this hymn yet.")
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.xs) {
                        ForEach(links) { link in
                            ScriptureChip(passage: link.passage, isEcho: link.confidence == .medium) {
                                Analytics.track(.scriptureOpened(
                                    hymnal: hymnal.id, number: hymn.id,
                                    book: BibleBook.usfm(for: link.passage.book) ?? "",
                                    confidence: link.confidence, surface: .aboutHymn))
                            }
                        }
                    }
                    .padding(.vertical, DS.Space.xs)
                    ForEach(links) { link in
                        let others = ScriptureLinks.hymns(citing: link.passage, hymnal: hymnal.id, excluding: hymn.id)
                        if !others.isEmpty {
                            NavigationLink {
                                PassageHymnsView(model: model, passage: link.passage, excluding: hymn.id)
                            } label: {
                                LabeledContent("Also on \(link.passage.reference)",
                                               value: others.count == 1 ? "1 hymn" : "\(others.count) hymns")
                            }
                        }
                    }
                }
            } header: {
                Text("Scripture")
            } footer: {
                if !links.isEmpty { Text(scriptureFooter) }
            }

            if !collections.isEmpty {
                Section("In collections") {
                    ForEach(collections) { collection in
                        NavigationLink {
                            CollectionDetailView(model: model, collection: collection)
                        } label: {
                            Label(collection.title, systemImage: collection.symbol)
                        }
                    }
                }
            }

            if hymn.hasAccompaniment {
                Section("Accompaniment") {
                    Button {
                        Analytics.track(.externalLinkOpened(.cyberHymnal))
                        openURL(AppInfo.cyberHymnalURL)
                    } label: {
                        Label("MIDI from The Cyber Hymnal (hymntime.com)", systemImage: "music.note")
                    }
                    .accessibilityHint("Opens hymntime.com")
                }
            }

            Section {
                NavigationLink {
                    PitchPipeView(hymnal: hymnal, hymn: hymn)
                } label: {
                    Label("Pitch pipe", systemImage: "tuningfork")
                }
                NavigationLink {
                    MemoryGameView(hymnal: hymnal, hymn: hymn)
                } label: {
                    Label("Memorise a verse", systemImage: "brain.head.profile")
                }
            }
        }
        .navigationTitle("About this hymn")
        .analyticsScreen(.aboutHymn)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StoryContent: View {
    let story: HymnStory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credit("Words", story.words)
            credit("Music", story.music)
            credit("Year", story.year)
            if let text = story.story, !text.isEmpty {
                Text(text).scaledFont(size: 17, design: .serif)
            }
            if let sources = story.sources, !sources.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sources").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(sources, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func credit(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

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
