//
//  HymnCollections.swift
//  Advent Praise
//
//  Curated lists for occasions (Christmas, Easter, communion, wedding,
//  funeral, children). Data: Resources/Extras/hymn_collections.json. The
//  collections are defined but ship with no hymns; fill `hymns` per hymnal
//  with numbers chosen by an editor, e.g. "hymns": { "english": [12, 40] }.
//

import Foundation

struct HymnCollection: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// SF Symbol name.
    let symbol: String
    /// Hymn numbers by hymnal key, in the editor's order.
    let hymns: [String: [Int]]

    func numbers(in hymnal: String) -> [Int] { hymns[hymnal] ?? [] }
}

enum HymnCollections {
    private struct File: Decodable { let version: Int; let collections: [HymnCollection] }

    static let all: [HymnCollection] = ExtrasBundle.decode("hymn_collections", as: File.self)?.collections ?? []

    /// Collections that include hymn `number` in `hymnal`.
    static func containing(_ number: Int, hymnal: String) -> [HymnCollection] {
        all.filter { $0.numbers(in: hymnal).contains(number) }
    }
}
