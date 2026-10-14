//
//  ReaderMenuPanels.swift
//  Advent Praise
//
//  The panels that unfold under the reader menu's bar (ReaderMenu.swift):
//  Translation, Theme, Text and About. They sit inside the menu's glass, so
//  nothing in here draws glass of its own. Each scrolls once it would pass
//  `maxHeight`, which leaves the Lectern and some lyrics in view.
//

import SwiftUI

struct ReaderMenuPanelContent: View {
    let model: ReaderModel
    let panel: ReaderMenuPanel
    let maxHeight: CGFloat

    var body: some View {
        switch panel {
        case .translation:
            // "Hymn N in…" heads the list, inside the same height.
            TranslationSwitcher(model: model, source: .translation, width: nil, maxHeight: maxHeight - 44,
                                onSwitched: { model.closeMenu() })
        case .theme: ThemePanel()
        case .text: TextPanel(maxHeight: maxHeight)
        case .about: AboutHymnPanel(model: model, maxHeight: maxHeight)
        }
    }
}

// MARK: - Theme

private struct ThemePanel: View {
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        ReadingSurfacePicker(surface: $settings.surface)
            .padding(DS.Space.panel)
            .haptic(.selection, trigger: settings.surface)
            .analyticsScreen(.appearance)
    }
}

// MARK: - Text

private struct TextPanel: View {
    let maxHeight: CGFloat
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        DSFittingScroll(maxHeight: maxHeight) {
            VStack(spacing: DS.Space.panel) {
                ReadingSizeControl(style: $settings.style)
                ReadingFontPicker(style: $settings.style)
                ReadingLayoutControls(style: $settings.style)
            }
            .padding(DS.Space.panel)
        }
        .haptic(.selection, trigger: settings.style)
        .analyticsScreen(.appearance)
    }
}

// MARK: - About

/// A summary of About this hymn: who wrote it and when, the start of its
/// story, the passages it draws on and the collections it's in. The full
/// story and the links between hymns are one tap away, in the About this
/// hymn sheet.
private struct AboutHymnPanel: View {
    let model: ReaderModel
    let maxHeight: CGFloat
    @Environment(\.dsSurface) private var surface

    private var hymnal: Hymnal { model.hymnal }
    private var hymn: Hymn { model.hymn }
    private var story: HymnStory? { HymnStories.story(hymnal: hymnal.id, number: hymn.id) }
    private var links: [ScriptureLink] { ScriptureLinks.links(hymnal: hymnal.id, number: hymn.id) }
    private var collections: [HymnCollection] { HymnCollections.containing(hymn.id, hymnal: hymnal.id) }

    /// "Words Fanny Crosby · Music Phoebe Knapp · 1873"
    private var credits: String? {
        guard let story else { return nil }
        let parts = [story.words.map { String(localized: "Words \($0)") },
                     story.music.map { String(localized: "Music \($0)") },
                     story.year]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        DSFittingScroll(maxHeight: maxHeight) {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                storySection
                if !links.isEmpty { scriptureSection }
                if !collections.isEmpty { collectionsSection }
                fullDetailsButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Space.panel)
        }
        .analyticsScreen(.aboutHymnPanel)
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(verbatim: "\(hymnal.name) \(hymn.id)")
                .dsEyebrow(tracking: 1.1)
                .foregroundStyle(surface.brass)
            Text(hymn.title)
                .font(DS.Typeface.panelTitle)
                .accessibilityAddTraits(.isHeader)
            if let credits {
                Text(credits).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
            }
            if let text = story?.story, !text.isEmpty {
                Text(text)
                    .font(.system(.callout, design: .serif))
                    .lineLimit(5)
                    .padding(.top, DS.Space.xxs)
            } else {
                Text("No story has been added for this hymn yet.")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
            }
        }
    }

    private var scriptureSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            PanelLabel("Scripture")
            FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.xs) {
                ForEach(links) { link in
                    ScriptureChip(passage: link.passage, isEcho: link.confidence == .medium) {
                        Analytics.track(.scriptureOpened(
                            hymnal: hymnal.id, number: hymn.id,
                            book: BibleBook.usfm(for: link.passage.book) ?? "",
                            confidence: link.confidence, surface: .readerMenu))
                    }
                }
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            PanelLabel("In collections")
            FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.xs) {
                ForEach(collections) { collection in
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: collection.symbol).imageScale(.small)
                        Text(collection.title)
                    }
                    .font(DS.Typeface.caption.weight(.semibold))
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(Color.primary.opacity(DS.Fill.inset)))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var fullDetailsButton: some View {
        Button {
            model.closeMenu()
            Analytics.track(.toolOpened(.about, source: .readerMenu))
            Extras.shared.sheet = .about
        } label: {
            HStack {
                Text(story?.story?.isEmpty == false ? "Read the full story" : "More about this hymn")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            }
            .font(DS.Typeface.label)
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(Color.primary.opacity(DS.Fill.inset)))
            .contentShape(RoundedRectangle.ds(DS.Radius.tile))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(surface.tint)
        .accessibilityHint("Opens About this hymn, with the full story and other hymns on each passage")
    }
}

private struct PanelLabel: View {
    let text: LocalizedStringKey
    @Environment(\.dsSurface) private var surface
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).dsEyebrow().foregroundStyle(surface.secondary).accessibilityAddTraits(.isHeader)
    }
}
