//
//  SDAHReferenceTests.swift
//  AdventPraiseTests
//
//  The Christ In Song → SDA Hymnal (1985) references that were wrong, checked
//  against hymnary.org by title, first line and tune (Tools/sdah_ref_fixes.py).
//  Each one must show the right "SDAH n" (or none), sit in the matching SDA
//  Hymnal section, and carry the story of its own hymn, not a neighbour's.
//

import Foundation
import Testing
@testable import Advent_Praise

struct SDAHReferenceTests {
    /// CIS number → SDAH 1985 number; nil = not in the SDA Hymnal.
    static let fixes: [Int: Int?] = [
        23: 260, 59: 489, 71: nil, 79: 358, 106: 531, 115: 254, 119: 332, 120: 486,
        121: 183, 151: nil, 173: 440, 174: 533, 241: nil, 269: 520, 284: nil,
    ]

    private static let english = Hymnal.load(HymnalInfo.default)

    @Test func eyebrowShowsTheCorrectedReference() throws {
        let english = try #require(Self.english)
        for (cis, sdah) in Self.fixes {
            let hymn = try #require(english.hymn(number: cis), "CIS \(cis)")
            let shown = hymn.references.filter { $0.hasPrefix("SDAH ") }
            #expect(shown == (sdah.map { ["SDAH \($0)"] } ?? []), "CIS \(cis) shows \(shown)")
        }
    }

    @Test func storiesBelongToTheirOwnHymn() {
        for (cis, sdah) in Self.fixes {
            let story = HymnStories.story(hymnal: "english", number: cis)
            if let sdah {
                let sources = story?.sources ?? []
                #expect(sources.contains("https://hymnary.org/hymn/SDAH1985/\(sdah)"), "CIS \(cis): \(sources)")
                #expect(!sources.contains { $0.contains("/SDAH1985/") && !$0.hasSuffix("/SDAH1985/\(sdah)") },
                        "CIS \(cis) still cites another SDAH hymn")
            } else {
                #expect(story == nil, "CIS \(cis) has no SDAH equivalent, so no borrowed story")
            }
        }
    }

    @Test func collectionsFollowTheCorrectedReference() {
        for (cis, sdah) in Self.fixes {
            let sections = HymnCollections.containing(cis, hymnal: "english")
            if let sdah {
                #expect(sections.count == 1, "CIS \(cis) in \(sections.map(\.id))")
                if let section = sections.first {
                    #expect(section.sdah[0] <= sdah && sdah <= section.sdah[1], "CIS \(cis) in \(section.id)")
                }
            } else {
                #expect(sections.isEmpty, "CIS \(cis) in \(sections.map(\.id))")
            }
        }
    }

    @Test func noTwoHymnsClaimTheSameSDAHNumberByMistake() throws {
        let english = try #require(Self.english)
        var owners: [String: [Int]] = [:]
        for hymn in english.hymns {
            for ref in hymn.references where ref.hasPrefix("SDAH ") { owners[ref, default: []].append(hymn.id) }
        }
        // 368 was claimed by 1, 71 and 241; only "Watchman, Blow the Gospel Trumpet" (CIS 1) is SDAH 368.
        #expect(owners["SDAH 368"] == [1])
    }
}
