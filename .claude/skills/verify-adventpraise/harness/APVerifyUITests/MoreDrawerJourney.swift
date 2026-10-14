//
//  MoreDrawerJourney.swift
//  APVerifyUITests
//
//  features/more-drawer.md: More opens from the hymn tray; Support, About
//  Advent Praise (→ Privacy Policy), Privacy, Terms and the pitch pipe push
//  as pages inside the drawer; Back pops; only the root shows Close; a
//  drag-down closes from a page and the next open starts at the root.
//

import XCTest

final class MoreDrawerJourney: JourneyCase {
    override var journeyName: String { "more-drawer" }

    private var back: XCUIElement { drawer("More").buttons["Back"] }
    private var close: XCUIElement { drawer("More").buttons["Close"] }

    private func openMore() {
        openHymnTray()
        tap(app.otherElements["lectern.hymnTray"].buttons["More"], "the tray's More tile")
        expect(app.staticTexts["Support Advent Praise"].waitForExistence(timeout: 5)
               || app.buttons["Support Advent Praise"].waitForExistence(timeout: 1), "the More drawer is open at its root")
        settle()
    }

    private func row(_ title: String) -> XCUIElement {
        let button = app.buttons[title]
        return button.exists ? button : app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// Taps Back/Close the way a finger would (its centre). When the card is at
    /// full height that has been a dead zone (2026-10-14): the miss is recorded as
    /// a FINDING, then the button's lower edge, which does respond, is tapped so
    /// the rest of the journey can still be proved.
    private func tapTopControl(_ button: XCUIElement, _ what: String, worked: () -> Bool) {
        let fullHeight = drawer("More").frame.minY < 80
        tap(button, what)
        settle(1.0)
        if worked() { return }
        check(false, "\(what) responds to a tap at its centre (card at \(fullHeight ? "full" : "partial") height, button \(button.frame))")
        shot("\(what.lowercased().replacingOccurrences(of: " ", with: "-"))-centre-tap-ignored")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.95)).tap()
        note("tap \(what) at its lower edge")
        settle(1.0)
    }

    func testPagesPushAndPopInsideTheDrawer() {
        launch()
        openMore()
        expect(close.exists && !back.exists, "the root shows Close, not Back")
        shot("more-root")

        // Support: a page pushed over More (a shorter card).
        tap(row("Support Advent Praise"), "Support Advent Praise")
        expect(back.waitForExistence(timeout: 4), "a page shows Back")
        expect(waitGone(close, timeout: 2), "a page hides Close")
        expect(!app.buttons["Rate on the App Store"].exists, "More's rows are hidden under the page")
        settle()
        shot("support-page")
        tapTopControl(back, "Back") { close.exists }
        expect(close.waitForExistence(timeout: 4), "Back returns to More's root (Close again)")

        // About Advent Praise, then its Privacy Policy row: two levels deep, full height.
        let about = row("About Advent Praise")
        if !about.isHittable { app.swipeUp() }
        tap(about, "About Advent Praise")
        expect(back.waitForExistence(timeout: 4), "About Advent Praise is a page (Back)")
        settle()
        shot("about-app-page")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Privacy'")).firstMatch, "About's Privacy Policy row")
        settle()
        expect(back.exists && waitGone(close, timeout: 2), "Privacy Policy is pushed a second level (still Back)")
        shot("privacy-from-about")
        let aboutsPrivacyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Privacy'")).firstMatch
        tapTopControl(back, "Back from Privacy") { aboutsPrivacyRow.exists }
        expect(aboutsPrivacyRow.waitForExistence(timeout: 4) && back.exists, "Back pops one level, to About Advent Praise")
        tapTopControl(back, "Back from About") { close.exists }
        expect(close.waitForExistence(timeout: 4), "and again to More's root")
        settle()
        shot("back-at-root")

        // Pitch pipe is a page too.
        tap(row("Pitch pipe"), "Pitch pipe")
        expect(back.waitForExistence(timeout: 4), "Pitch pipe is a page inside More")
        settle()
        shot("pitch-page")

        // Drag down from a page closes the drawer, and the path resets.
        let card = drawer("More")
        let start = card != app ? card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                                : app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        note("drag down from the pitch pipe page")
        expect(waitGone(back, timeout: 5), "drag-down closes the drawer from a page")
        settle()
        shot("closed-by-drag")
        openMore()
        expect(close.exists && !back.exists, "reopened More starts at its root, not the pitch pipe")
        shot("reopened-at-root")
        tapTopControl(close, "Close") { !app.alerts["More"].exists }
        expect(waitGone(app.alerts["More"], timeout: 5), "Close dismisses More")
        settle()
        shot("closed")
    }
}
