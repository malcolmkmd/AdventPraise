//
//  PreviewFixtures.swift
//  Advent Praise 7 — Vesper design system
//
//  Plain value types the components take, plus sample data for #Previews.
//  The app maps its own models (Hymn, HymnalInfo, HymnalStore) onto these.
//

import SwiftUI

/// One vernacular hymnal as the picker and paywall need it.
struct DSHymnal: Identifiable, Hashable, Sendable {
    let id: String              // product id for purchasable hymnals
    let name: String            // "Christ In Song"
    let language: String        // "English"
    let color: DSLanguageColor
    /// A hymnal of its own (the SDA Hymnal) rather than a translation of
    /// Christ In Song: its own numbers, and a tile across the whole row.
    var isOwnBook = false
}

/// Ownership of a hymnal, from the purchases layer.
enum DSHymnalAccess: Equatable, Sendable {
    case current
    case owned
    case locked(price: String?)
    case purchasing
}

/// A row-sized summary of a hymn.
struct DSHymnSummary: Identifiable, Hashable, Sendable {
    let number: Int
    let title: String
    var firstLine: String? = nil
    var id: Int { number }
}

/// One block of a hymn's text.
enum DSHymnBlock: Hashable, Sendable {
    case verse(number: Int, lines: [String])
    case chorus(lines: [String])
}

enum DSPreview {
    static let hymnals: [DSHymnal] = [
        ("english", "Christ In Song", "English"), ("chichewa", "Khristu Mu Nyimbo", "Chichewa"),
        ("tswana", "Keresete Mo Kopelong", "Tswana"), ("xhosa", "UKristu Engomeni", "Xhosa"),
        ("sotho", "Keresete Pineng", "Sotho"), ("shona", "Kristu MuNzwiyo", "Shona"),
        ("venda", "Ngosha YaDzingosha", "Venda"), ("zulu", "UKrestu Esihlabelelweni", "Zulu"),
        ("ndebele", "UKrestu Esihlabelelweni", "Ndebele"), ("sdah", "SDA Hymnal (1985)", "English"),
    ].map { DSHymnal(id: $0, name: $1, language: $2, color: DS.Language.color(for: $0), isOwnBook: $0 == "sdah") }

    /// Every hymnal is free; the purchasing and locked states stay previewable.
    static func access(for hymnal: DSHymnal) -> DSHymnalAccess {
        switch hymnal.id {
        case "english": .current
        case "sotho": .purchasing
        case "venda": .locked(price: "$1.99")
        default: .owned
        }
    }

    static let hymns: [DSHymnSummary] = [
        .init(number: 1, title: "Holy, Holy, Holy", firstLine: "Holy, holy, holy! Lord God Almighty!"),
        .init(number: 18, title: "Lead, Kindly Light", firstLine: "Lead, kindly Light, amid th'encircling gloom"),
        .init(number: 30, title: "Blessed Assurance", firstLine: "Blessed assurance, Jesus is mine!"),
        .init(number: 254, title: "Rock of Ages", firstLine: "Rock of Ages, cleft for me"),
    ]

    static func title(for number: Int) -> String? {
        hymns.first { $0.number == number }?.title
    }

    static let blocks: [DSHymnBlock] = [
        .verse(number: 1, lines: ["Blessed assurance, Jesus is mine!",
                                  "Oh, what a foretaste of glory divine!",
                                  "Heir of salvation, purchase of God,",
                                  "Born of His Spirit, washed in His blood."]),
        .chorus(lines: ["This is my story, this is my song,",
                        "Praising my Saviour all the day long;",
                        "This is my story, this is my song,",
                        "Praising my Saviour all the day long."]),
        .verse(number: 2, lines: ["Perfect submission, perfect delight,",
                                  "Visions of rapture now burst on my sight;",
                                  "Angels descending bring from above",
                                  "Echoes of mercy, whispers of love."]),
    ]
}

/// A scrollable stand-in for lyrics, so glass previews have something to refract.
struct DSPreviewBackdrop: View {
    @Environment(\.dsSurface) private var surface
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.block) {
                Text("Blessed Assurance").font(DS.Typeface.hymnTitle)
                ForEach(0..<4, id: \.self) { _ in
                    DSLyricText("Blessed assurance, Jesus is mine!\nOh, what a foretaste of glory divine!\nHeir of salvation, purchase of God,\nBorn of His Spirit, washed in His blood.",
                                style: DSReadingStyle())
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.top)
        }
        .scrollIndicators(.hidden)
    }
}
