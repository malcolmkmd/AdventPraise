//
//  AboutHymnDrawer.swift
//  Advent Praise
//
//  "About this hymn", in AdventDrawer: the start of its story, then rows to
//  the full story, the words and music, the sources, the passages it draws
//  on (each linking to the other hymns that cite it), the collections it
//  belongs to and the pitch pipe. Each is a page pushed inside the drawer;
//  back returns here, where the user left off. Memorise a verse wants the
//  whole screen, so it opens in its sheet. Opened from the reader menu's
//  About panel, which is its summary.
//

import SwiftUI

/// The pages About this hymn pushes inside its drawer.
enum AboutHymnPage: AdventDrawerPage {
    case story, credits, sources, scripture, pitch
    case passage(Passage)
    case collection(HymnCollection)

    var drawerTitle: Text {
        switch self {
        case .story: Text("Story")
        case .credits: Text("Words and music")
        case .sources: Text("Sources")
        case .scripture: Text("Scripture")
        case .pitch: Text(ExtraSheet.pitch.title)
        case .passage(let passage): Text(verbatim: passage.reference)
        case .collection(let collection): Text(verbatim: collection.title)
        }
    }
}

extension View {
    /// Presents About this hymn in a drawer. Attached by `extrasSheets`.
    func aboutHymnDrawer(model: ReaderModel, isPresented: Binding<Bool>,
                         onDismiss: @escaping () -> Void) -> some View {
        modifier(AboutHymnDrawerPresenter(model: model, isPresented: isPresented, onDismiss: onDismiss))
    }
}

private struct AboutHymnDrawerPresenter: ViewModifier {
    let model: ReaderModel
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    /// Pages pushed inside the drawer. Empty: About this hymn itself.
    @State private var path: [AboutHymnPage] = []

    func body(content: Content) -> some View {
        content.adventDrawer("About this hymn", isPresented: $isPresented, path: $path, onDismiss: onDismiss) {
            AboutHymnView(model: model, path: $path)
        } destination: { page in
            switch page {
            case .story: AboutHymnStoryPage(model: model)
            case .credits: AboutHymnCreditsPage(model: model)
            case .sources: AboutHymnSourcesPage(model: model)
            case .scripture: AboutHymnScripturePage(model: model) { path.append(.passage($0)) }
            case .pitch: PitchPipeView(hymnal: model.hymnal, hymn: model.hymn)
            case .passage(let passage): PassageHymnsPage(model: model, passage: passage, excluding: model.hymn.id)
            case .collection(let collection): CollectionHymnsPage(model: model, collection: collection)
            }
        }
        // The root stays mounted under its pages, so coming back counts as a visit here.
        .onChange(of: path.isEmpty) { _, isRoot in
            if isRoot, isPresented { Analytics.screen(.aboutHymn) }
        }
    }
}

/// What the app knows about the hymn on the reader, for the root and its pages.
@MainActor
private struct HymnFacts {
    let hymnal: Hymnal
    let hymn: Hymn
    let story: HymnStory?
    let links: [ScriptureLink]
    let collections: [HymnCollection]

    init(_ model: ReaderModel) {
        hymnal = model.hymnal
        hymn = model.hymn
        story = HymnStories.story(hymnal: hymnal.id, number: hymn.id)
        links = ScriptureLinks.links(hymnal: hymnal.id, number: hymn.id)
        collections = HymnCollections.containing(hymn.id, hymnal: hymnal.id)
    }

    var storyText: String? {
        guard let text = story?.story, !text.isEmpty else { return nil }
        return text
    }

    var sources: [String] { story?.sources ?? [] }

    /// Words, Music and Year, those that are known.
    var credits: [Credit] {
        [Credit(label: "Words", value: story?.words),
         Credit(label: "Music", value: story?.music),
         Credit(label: "Year", value: story?.year)]
            .filter { !($0.value ?? "").isEmpty }
    }

    struct Credit {
        let label: LocalizedStringKey
        let value: String?
    }

    var scriptureFooter: String {
        let kinds = Set(links.map(\.source))
        let labels = [ScriptureSource.lyric, .hymnal, .hymnary].filter(kinds.contains).map(\.label)
        var text = "Opens in the Bible app."
        if links.contains(where: { $0.confidence == .medium }) {
            text += " ≈ marks a passage the hymn echoes rather than quotes."
        }
        return text + " Source: " + labels.joined(separator: "; ") + "."
    }
}

// MARK: - Root

struct AboutHymnView: View {
    let model: ReaderModel
    @Binding var path: [AboutHymnPage]
    @Environment(\.dsSurface) private var surface

    var body: some View {
        let facts = HymnFacts(model)
        VStack(alignment: .leading, spacing: DS.Space.m) {
            header(facts)
            if let text = facts.storyText {
                Text(text)
                    .scaledFont(size: 17, design: .serif)
                    .lineLimit(4)
                    .padding(.horizontal, DS.Space.xxs)
            }
            storyGroup(facts)
            scriptureGroup(facts)
            if !facts.collections.isEmpty {
                DSInsetGroup(title: "In collections") {
                    ForEach(facts.collections) { collection in
                        MoreRow(title: "\(collection.title)", isLast: collection == facts.collections.last) {
                            Image(systemName: collection.symbol)
                        } action: { path.append(.collection(collection)) }
                    }
                }
            }
            DSInsetGroup(title: "Tools") {
                MoreRow(title: ExtraSheet.pitch.title, detail: ExtraSheet.pitch.detail(for: model)) {
                    Image(systemName: ExtraSheet.pitch.systemImage)
                } action: { path.append(.pitch) }
                // The game wants the whole screen: it opens in its sheet.
                MoreRow(title: ExtraSheet.memory.title, isLast: true) {
                    Image(systemName: ExtraSheet.memory.systemImage)
                } action: { Extras.shared.sheet = .memory }
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.m)
        .analyticsScreen(.aboutHymn)
    }

    private func header(_ facts: HymnFacts) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.hair) {
            Text(verbatim: "\(facts.hymnal.name) \(facts.hymn.id)")
                .dsEyebrow(tracking: 1.1)
                .foregroundStyle(surface.brass)
            Text(facts.hymn.title)
                .font(DS.Typeface.sheetTitle)
                .accessibilityAddTraits(.isHeader)
        }
        // Clear of the close button.
        .padding(.trailing, DS.Size.hitTarget + DS.Space.m)
        .frame(minHeight: DS.Size.hitTarget, alignment: .leading)
    }

    @ViewBuilder
    private func storyGroup(_ facts: HymnFacts) -> some View {
        let hasStory = facts.storyText != nil
        let hasCredits = !facts.credits.isEmpty
        let hasSources = !facts.sources.isEmpty
        if hasStory || hasCredits || hasSources {
            DSInsetGroup(title: "Story") {
                if hasStory {
                    MoreRow(title: "Read the full story", isLast: !hasCredits && !hasSources) {
                        Image(systemName: "book.closed")
                    } action: { path.append(.story) }
                }
                if hasCredits {
                    MoreRow(title: "Words and music", detail: facts.credits.first?.value, isLast: !hasSources) {
                        Image(systemName: "music.quarternote.3")
                    } action: { path.append(.credits) }
                }
                if hasSources {
                    MoreRow(title: "Sources", detail: String(facts.sources.count), isLast: true) {
                        Image(systemName: "text.quote")
                    } action: { path.append(.sources) }
                }
            }
        }
    }

    /// Nothing at all when no passage is linked.
    @ViewBuilder
    private func scriptureGroup(_ facts: HymnFacts) -> some View {
        if !facts.links.isEmpty {
            DSInsetGroup(title: "Scripture") {
                MoreRow(title: "Passages",
                        detail: facts.links.map(\.passage.reference).formatted(.list(type: .and)),
                        isLast: true) {
                    Image(systemName: "text.book.closed")
                } action: { path.append(.scripture) }
            }
        }
    }
}

// MARK: - Pages (titled by the drawer's bar)

private struct AboutHymnStoryPage: View {
    let model: ReaderModel
    @Environment(\.dsSurface) private var surface

    var body: some View {
        let facts = HymnFacts(model)
        DrawerPageLayout {
            let credits = facts.credits.compactMap(\.value)
            if !credits.isEmpty {
                Text(verbatim: credits.joined(separator: " · "))
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
            }
            Text(verbatim: facts.storyText ?? "")
                .scaledFont(size: 17, design: .serif)
                .textSelection(.enabled)
        }
    }
}

private struct AboutHymnCreditsPage: View {
    let model: ReaderModel

    var body: some View {
        let credits = HymnFacts(model).credits
        DrawerPageLayout {
            DSInsetGroup {
                ForEach(credits.indices, id: \.self) { index in
                    FactRow(title: credits[index].label, value: credits[index].value ?? "",
                            isLast: index == credits.count - 1)
                }
            }
        }
    }
}

private struct AboutHymnSourcesPage: View {
    let model: ReaderModel

    var body: some View {
        let sources = HymnFacts(model).sources
        DrawerPageLayout {
            DSInsetGroup {
                ForEach(sources.indices, id: \.self) { index in
                    Text(verbatim: sources[index])
                        .font(DS.Typeface.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(.horizontal, DS.Space.m)
                        .padding(.vertical, DS.Space.xs)
                        .overlay(alignment: .bottom) {
                            if index < sources.count - 1 { Divider().padding(.leading, DS.Space.m) }
                        }
                }
            }
            DrawerNote("Where the story, the names and the year come from.")
        }
    }
}

private struct AboutHymnScripturePage: View {
    let model: ReaderModel
    let openPassage: (Passage) -> Void

    private struct Others: Identifiable {
        let passage: Passage
        let count: Int
        var id: Passage { passage }
    }

    var body: some View {
        let facts = HymnFacts(model)
        let others = facts.links.compactMap { link -> Others? in
            let numbers = ScriptureLinks.hymns(citing: link.passage, hymnal: facts.hymnal.id, excluding: facts.hymn.id)
            return numbers.isEmpty ? nil : Others(passage: link.passage, count: numbers.count)
        }
        DrawerPageLayout {
            FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.xs) {
                ForEach(facts.links) { link in
                    ScriptureChip(passage: link.passage, isEcho: link.confidence == .medium) {
                        Analytics.track(.scriptureOpened(
                            hymnal: facts.hymnal.id, number: facts.hymn.id,
                            book: BibleBook.usfm(for: link.passage.book) ?? "",
                            confidence: link.confidence, surface: .aboutHymn))
                    }
                }
            }
            DrawerNote(facts.scriptureFooter)
            if !others.isEmpty {
                DSInsetGroup(title: "Other hymns") {
                    ForEach(others) { other in
                        MoreRow(title: "Also on \(other.passage.reference)",
                                detail: other.count == 1 ? String(localized: "1 hymn")
                                                         : String(localized: "\(other.count) hymns"),
                                isLast: other.passage == others.last?.passage) {
                            Image(systemName: "book")
                        } action: { openPassage(other.passage) }
                    }
                }
            }
        }
    }
}

// MARK: - Rows

private struct FactRow: View {
    let title: LocalizedStringKey
    let value: String
    var isLast = false
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(DS.Typeface.label)
            Spacer(minLength: DS.Space.s)
            Text(verbatim: value)
                .font(DS.Typeface.label)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, DS.Space.m) } }
        .accessibilityElement(children: .combine)
    }
}
