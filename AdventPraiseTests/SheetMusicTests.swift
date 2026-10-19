//
//  SheetMusicTests.swift
//  AdventPraiseTests
//
//  The sheet music that ships: every hymn in the manifest opens in both
//  widths, inked in currentColor; held hymns stay out; and who sees what
//  (Pro, Hymn of the Day free, a preview for everyone else).
//

import Foundation
import Testing
@testable import Advent_Praise

struct SheetMusicTests {
    @Test func everyListedHymnOpensInBothWidths() throws {
        let count = SheetMusicCatalog.count(hymnal: "english")
        #expect(count == 204)
        var opened = 0
        for number in 1...300 where SheetMusicCatalog.has(hymnal: "english", number: number) {
            for layout in SheetMusicLayout.allCases {
                let page = try #require(SheetMusicCatalog.page(hymnal: "english", number: number, layout: layout),
                                        "hymn \(number) \(layout)")
                #expect(page.svg.hasPrefix("<svg"))
                #expect(page.svg.contains("currentColor"))
                #expect(!page.svg.contains("#000"), "hymn \(number) has hard-coded black")
                #expect(page.width > 0 && page.height > 0)
            }
            opened += 1
        }
        #expect(opened == count)
    }

    @Test func heldHymnsDontShip() {
        // Rights unclear; #85 (Forest Green is still under copyright); a different hymn
        // on the Cyber Hymnal (29, 164, 266); and tune-only scores that would show no words.
        let rightsUnclear = [5, 11, 87, 101, 125, 161, 170, 173, 182, 216, 260, 281]
        let noWords = [31, 41, 53, 59, 60, 66, 81, 82, 84, 89, 90, 95, 140, 143, 146, 172, 174, 176,
                       188, 223, 229, 243, 257, 282, 287, 299]
        for number in rightsUnclear + [85, 29, 164, 266] + noWords {
            #expect(!SheetMusicCatalog.has(hymnal: "english", number: number), "hymn \(number)")
        }
    }

    @Test func onlyTheEnglishHymnalHasSheetMusic() {
        #expect(!SheetMusicCatalog.has(hymnal: "ndebele", number: 100))
        #expect(SheetMusicCatalog.page(hymnal: "ndebele", number: 100, layout: .phone) == nil)
    }

    @Test func proSeesEverythingHymnOfTheDayIsFreeOthersPreview() {
        #expect(SheetMusicAccess.resolve(isPro: true, isHymnOfTheDay: false) == .pro)
        #expect(SheetMusicAccess.resolve(isPro: true, isHymnOfTheDay: true) == .pro)
        #expect(SheetMusicAccess.resolve(isPro: false, isHymnOfTheDay: true) == .hymnOfTheDay)
        #expect(SheetMusicAccess.resolve(isPro: false, isHymnOfTheDay: false) == .preview)
        #expect(SheetMusicAccess.hymnOfTheDay.showsWholePage)
        #expect(!SheetMusicAccess.preview.showsWholePage)
    }

    @Test func sheetMusicIsAProFeature() {
        #expect(!Entitlements.none.unlocks(.sheetMusic))
        #expect(Entitlements(active: [PurchaseConfig.proEntitlement]).unlocks(.sheetMusic))
        #expect(ProFeature.sheetMusic.analyticsName == "sheet_music")
    }

    @Test func analyticsEvents() {
        let opened = AnalyticsEvent.sheetMusicOpened(number: 100, access: .hymnOfTheDay)
        #expect(opened.name == "sheet_music_opened")
        #expect(opened.properties["access"] as? String == "hymn_of_the_day")
        #expect(opened.properties["hymn_number"] as? Int == 100)
        #expect(AnalyticsEvent.sheetMusicPaywallOpened(number: 7).name == "sheet_music_paywall_opened")
        #expect(PaywallContext.sheetMusic.rawValue == "sheet_music")
    }
}
