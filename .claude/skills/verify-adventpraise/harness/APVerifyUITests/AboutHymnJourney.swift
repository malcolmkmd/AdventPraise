//
//  AboutHymnJourney.swift
//  APVerifyUITests
//
//  features/about-this-hymn.md: Reading options (globe) → About this hymn
//  panel → Read the full story opens the About this hymn drawer for 191;
//  its rows push pages inside the drawer, Back pops, only the root has
//  Close, and Memorise a verse opens its own sheet.
//

import XCTest

final class AboutHymnJourney: JourneyCase {
    override var journeyName: String { "about-this-hymn" }

    private var back: XCUIElement { drawer("About this hymn").buttons["Back"] }
    private var close: XCUIElement { drawer("About this hymn").buttons["Close"] }

    private func openFromReaderMenu() {
        tap(app.buttons["Reading options"], "Reading options (the globe)")
        tap(app.buttons["About this hymn"], "the reader menu's About this hymn tab")
        settle()
        shot("menu-about-panel")
        let full = app.buttons["Read the full story"].exists ? app.buttons["Read the full story"] : app.buttons["More about this hymn"]
        tap(full, "the panel's full-details button")
        expect(app.staticTexts["Blessed Assurance"].waitForExistence(timeout: 5), "the drawer opens on 191 Blessed Assurance")
        expect(close.waitForExistence(timeout: 3) && !back.exists, "the root shows Close, not Back")
        settle()
    }

    func testPagesPushAndPopInsideTheDrawer() {
        launch()
        openFromReaderMenu()
        shot("about-root")

        // Each row the root offers for 191 that pushes a page.
        var pushed = 0
        for title in ["Read the full story", "Words and music", "Sources", "Passages"] {
            let rowButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            guard rowButton.waitForExistence(timeout: 2) else { note("no '\(title)' row for 191 (data, not a failure)"); continue }
            if !rowButton.isHittable { app.swipeUp() }
            tap(rowButton, "'\(title)'")
            expect(back.waitForExistence(timeout: 4) && waitGone(close, timeout: 2), "'\(title)' is a page (Back, no Close)")
            settle()
            shot("page-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
            if title == "Passages" {
                // A passage → the other hymns on it: a second level.
                let passage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Also on '")).firstMatch
                if passage.waitForExistence(timeout: 2) {
                    tap(passage, "an 'Also on …' passage row")
                    expect(back.waitForExistence(timeout: 4), "the passage page is pushed (second level)")
                    settle()
                    shot("page-passage")
                    tap(back, "Back (to Scripture)")
                    settle(0.5)
                } else {
                    note("no 'Also on …' row on 191's Scripture page")
                }
            }
            tap(back, "Back")
            expect(close.waitForExistence(timeout: 4), "Back returns to the root (Close again)")
            pushed += 1
        }
        expect(pushed >= 2, "at least two of the root's rows pushed pages (got \(pushed))")

        // Pitch pipe: a page in this drawer too.
        let pitch = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pitch pipe'")).firstMatch
        if !pitch.isHittable { app.swipeUp() }
        tap(pitch, "Pitch pipe")
        expect(back.waitForExistence(timeout: 4), "Pitch pipe is a page in About this hymn")
        settle()
        shot("page-pitch")
        tap(back, "Back")
        expect(close.waitForExistence(timeout: 4), "back at the root")

        // Memorise a verse leaves the drawer for its own sheet.
        let memorise = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Memorise a verse'")).firstMatch
        if !memorise.isHittable { app.swipeUp() }
        tap(memorise, "Memorise a verse")
        expect(app.navigationBars["Memorise"].waitForExistence(timeout: 6), "Memorise opens in its own sheet")
        settle()
        shot("memorise-sheet-from-about")
    }
}
