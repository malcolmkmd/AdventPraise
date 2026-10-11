//
//  ComponentGallery.swift
//  Advent Praise 7 — Vesper design system
//
//  Every component on every surface, for design review in Xcode Previews.
//  Not shipped: exclude from the app target or wrap in #if DEBUG.
//

#if DEBUG
import SwiftUI

struct ComponentGallery: View {
    @State private var surface: DSSurface = .paper
    @State private var style = DSReadingStyle()
    @State private var digits = "30"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    Picker("Surface", selection: $surface) {
                        ForEach(DSSurface.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    section("Reading") {
                        ChapterVerseBlock(number: 1, lines: ["Blessed assurance, Jesus is mine!",
                                                              "Oh, what a foretaste of glory divine!"],
                                          style: style, state: .current)
                        ChorusBlock(lines: ["This is my story, this is my song,"], style: style)
                        ChapterVerseBlock(number: 2, lines: ["Perfect submission, perfect delight,"],
                                          style: style, state: .dimmed)
                    }
                    section("Buttons") {
                        GlassButton(title: "Primary", fullWidth: true) {}
                        GlassButton(title: "Secondary", kind: .secondary, fullWidth: true) {}
                        GlassButton(title: "Close", systemImage: "xmark", kind: .icon) {}
                    }
                    section("Rows") {
                        HymnRow(hymn: DSPreview.hymns[2], isFavourite: true, isCurrent: true) {}
                        HymnRow(hymn: DSPreview.hymns[3], snippet: "Rock of Ages, cleft for me", highlight: "cleft") {}
                        PaywallLanguageRow(hymnal: DSPreview.hymnals[1], access: .locked(price: "$1.99")) {}
                    }
                    section("Number pad") {
                        HymnNumberPad(digits: $digits, title: DSPreview.title(for:)) { _ in }
                    }
                    section("Lectern") {
                        ReaderToolbar(number: 30, title: "Blessed Assurance", status: "Christ In Song · piano ready",
                                      hasAccompaniment: true)
                    }
                }
                .padding(DS.Space.l)
            }
            .navigationTitle("Vesper")
        }
        .dsSurface(surface)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title).dsEyebrow().foregroundStyle(surface.secondary)
            content()
        }
    }
}

#Preview("Gallery") {
    ComponentGallery()
}
#endif
