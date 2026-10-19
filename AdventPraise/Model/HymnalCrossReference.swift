//
//  HymnalCrossReference.swift
//  Advent Praise
//
//  The same hymn in Christ In Song (and the hymnals numbered like it) and in
//  the SDA Hymnal (1985). The match is the English hymns' checked "SDAH n"
//  reference (refs.sdah in english.json, corrected by Tools/sdah_ref_fixes.py);
//  Tools/convert_hymnals.py writes the same pairs back into sdah.json as
//  "CIS n". Numbers alone never match across the two numberings.
//
//  `SDAHTunes` (Resources/Extras/sdah_tunes.json) narrows those pairs to the
//  ones sung to the same tune, so an SDA Hymnal hymn can use its Christ In
//  Song version's accompaniment, and, where tune and setting are public
//  domain, its sheet music.
//

import Foundation

enum HymnalCrossReference {
    /// Christ In Song number → SDA Hymnal number. The first English hymn
    /// naming an SDA Hymnal number is the one that number goes back to.
    static let sdahForCIS: [Int: Int] = {
        guard let english = Hymnal.load(.default) else { return [:] }
        var map: [Int: Int] = [:]
        for hymn in english.hymns {
            if let n = hymn.references.lazy.compactMap({ number(in: $0, prefix: "SDAH ") }).first { map[hymn.id] = n }
        }
        return map
    }()

    /// SDA Hymnal number → Christ In Song number.
    static let cisForSDAH: [Int: Int] = {
        var map: [Int: Int] = [:]
        for (cis, sdah) in sdahForCIS.sorted(by: { $0.key < $1.key }) where map[sdah] == nil { map[sdah] = cis }
        return map
    }()

    /// Hymn `number` of `from` as numbered in `to`; nil when that hymnal
    /// doesn't have it. Within one numbering it's the same number.
    static func number(_ number: Int, from: HymnalInfo, to: HymnalInfo) -> Int? {
        let mapped: Int? = switch (from.numbering, to.numbering) {
        case (.christInSong, .christInSong), (.sdah, .sdah): number
        case (.christInSong, .sdah): sdahForCIS[number]
        case (.sdah, .christInSong): cisForSDAH[number]
        }
        return mapped.flatMap { $0 <= to.maxNumber ? $0 : nil }
    }

    private static func number(in reference: String, prefix: String) -> Int? {
        reference.hasPrefix(prefix) ? Int(reference.dropFirst(prefix.count)) : nil
    }
}

enum SDAHTunes {
    private struct File: Decodable {
        let tune: [String: Int]
        let sheet: [Int]
        /// SDA Hymnal hymns that aren't a Christ In Song version but are sung
        /// to the same public-domain tune as a Christ In Song hymn: that
        /// hymn's accompaniment only.
        let shared: [String: Int]?
    }

    private static let file: File? = ExtrasBundle.decode("sdah_tunes")

    /// The Christ In Song hymn sung to the same tune as SDA Hymnal `number`.
    static func cisTune(for number: Int) -> Int? { cisVersion(for: number) ?? file?.shared?[String(number)] }

    /// The Christ In Song version of SDA Hymnal `number` (the same hymn), when
    /// it's sung to the same tune.
    static func cisVersion(for number: Int) -> Int? { file?.tune[String(number)] }

    /// The Christ In Song score to show for SDA Hymnal `number`: same tune,
    /// and public domain in this setting. Nil for every other hymn.
    static func cisScore(for number: Int) -> Int? {
        guard let file, file.sheet.contains(number) else { return nil }
        return cisVersion(for: number)
    }
}
