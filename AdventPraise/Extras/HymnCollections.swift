//
//  HymnCollections.swift
//  Advent Praise
//
//  The topical sections of the Seventh-day Adventist Hymnal (1985): Worship,
//  Jesus Christ, Gospel, Christian Life… Data: Resources/Extras/
//  hymn_collections.json, written by Tools/build_collections.py. The SDA
//  Hymnal uses its own numbers; Christ In Song and the hymnals numbered like
//  it are placed by each hymn's SDA Hymnal cross-reference, so hymns with none
//  aren't in any collection.
//

import Foundation

struct HymnCollection: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// SF Symbol name.
    let symbol: String
    /// Position in the SDA Hymnal.
    let order: Int
    /// First and last SDA Hymnal number in the section.
    let sdah: [Int]
    /// Hymn numbers by hymnal key, ascending.
    let hymns: [String: [Int]]

    func numbers(in hymnal: String) -> [Int] { hymns[hymnal] ?? [] }

    /// "1–69"
    var sdahRange: String { sdah.count == 2 ? "\(sdah[0])–\(sdah[1])" : "" }
}

enum HymnCollections {
    private struct File: Decodable { let version: Int; let collections: [HymnCollection] }

    static let all: [HymnCollection] = (ExtrasBundle.decode("hymn_collections", as: File.self)?.collections ?? [])
        .sorted { $0.order < $1.order }

    /// The collections with hymns in `hymnal`, in hymnal order.
    static func available(in hymnal: String) -> [HymnCollection] {
        all.filter { !$0.numbers(in: hymnal).isEmpty }
    }

    /// Collections that include hymn `number` in `hymnal`.
    static func containing(_ number: Int, hymnal: String) -> [HymnCollection] {
        all.filter { $0.numbers(in: hymnal).contains(number) }
    }
}
