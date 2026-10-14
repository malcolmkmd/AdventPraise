//
//  MoreSheetJourney.swift
//  APVerifyUITests
//
//  features/more-sheet.md: More opens from the hymn tray as a sheet with
//  its own navigation stack. About Advent Praise (→ Privacy Policy), the
//  Scripture index and the pitch pipe push under a standard navigation
//  bar; Back pops one level; Done closes More from any page; a swipe down
//  closes it too; the next open starts at the root. Support opens over
//  More and comes back to it; Church mode opens once More has gone.
//

import XCTest

final class MoreSheetJourney: JourneyCase {
    override var journeyName: String { "more-sheet" }

    /// More's navigation bar on a page, found by the page's title.
    private func bar(_ title: String) -> XCUIElement { app.navigationBars[title] }
    private func done(_ title: String) -> XCUIElement { bar(title).buttons["Done"] }
    /// The system back button: the bar's one button that isn't Done.
    private func back(_ title: String) -> XCUIElement {
        bar(title).buttons.matching(NSPredicate(format: "label != 'Done'")).firstMatch
    }

    private func openMore() {
        openHymnTray()
        tap(app.otherElements["lectern.hymnTray"].buttons["More"], "the tray's More tile")
        expect(bar("More").waitForExistence(timeout: 5), "More opens with its navigation bar titled More")
        settle()
    }

    private func row(_ title: String) -> XCUIElement {
        var button = app.buttons[title]
        if !button.exists { button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch }
        if button.exists && !button.isHittable { app.swipeUp(); settle(0.5) }
        return button
    }

    private func push(_ rowTitle: String, to pageTitle: String) {
        tap(row(rowTitle), rowTitle)
        expect(bar(pageTitle).waitForExistence(timeout: 4), "\(rowTitle) pushes a page titled \(pageTitle)")
        expect(back(pageTitle).exists, "\(pageTitle) shows the system Back button")
        expect(done(pageTitle).exists, "\(pageTitle) shows Done")
        settle()
    }

    private func pop(from pageTitle: String, to parentTitle: String) {
        tap(back(pageTitle), "Back from \(pageTitle)")
        expect(bar(parentTitle).waitForExistence(timeout: 4) && waitGone(bar(pageTitle), timeout: 3),
               "Back pops one level, to \(parentTitle)")
        settle()
    }

    func testPagesPushInMoresNavigationStack() {
        launch()
        openMore()
        expect(done("More").exists, "the root shows Done")
        check(bar("More").buttons.count == 1, "the root has no Back button (bar buttons: \(bar("More").buttons.count))")
        shot("more-root")

        // Support opens over More, like the paywall, and closes back to it.
        tap(row("Support Advent Praise"), "Support Advent Praise")
        expect(app.staticTexts["A Note from Malcolm"].waitForExistence(timeout: 5), "Support opens (paywall-style header)")
        settle()
        shot("support-over-more")
        let closes = app.buttons.matching(NSPredicate(format: "label == 'Close'")).allElementsBoundByIndex
        let close = closes.last { $0.isHittable } ?? app.buttons["Close"]
        tap(close, "Support's Close")
        expect(waitGone(app.staticTexts["A Note from Malcolm"], timeout: 5), "Support closes")
        expect(bar("More").exists && done("More").isHittable, "More is still open under it, at its root")
        settle()
        shot("back-from-support")

        // About Advent Praise, then its Privacy Policy row: two levels deep.
        push("About Advent Praise", to: "About")
        shot("about-app-page")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Privacy'")).firstMatch, "About's Privacy Policy row")
        expect(bar("Privacy").waitForExistence(timeout: 4), "Privacy Policy pushes a second level")
        expect(done("Privacy").exists, "Done shows two levels deep")
        settle()
        shot("privacy-from-about")
        pop(from: "Privacy", to: "About")
        pop(from: "About", to: "More")
        shot("back-at-root")

        // Done on a page closes all of More; the next open starts at the root.
        push("Scripture index", to: "Scripture index")
        shot("scripture-page")
        tap(done("Scripture index"), "Done on the Scripture index")
        expect(waitGone(bar("Scripture index"), timeout: 5), "Done closes More from a page")
        settle()
        shot("closed-by-done")
        openMore()
        expect(bar("More").exists && !bar("Scripture index").exists, "reopened More starts at its root")

        // A swipe down from a page closes More too, and resets it.
        push("Pitch pipe", to: "Pitch pipe")
        shot("pitch-page")
        bar("Pitch pipe").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        note("swipe down from the pitch pipe page")
        expect(waitGone(bar("Pitch pipe"), timeout: 5), "a swipe down closes More from a page")
        settle()
        shot("closed-by-swipe")
        openMore()
        expect(bar("More").exists && !bar("Pitch pipe").exists, "reopened More starts at its root, not the pitch pipe")
        shot("reopened-at-root")

        // Church mode: More goes, then church mode covers the reader.
        tap(row("Church mode"), "Church mode")
        expect(app.buttons["Leave worship mode"].waitForExistence(timeout: 6), "church mode opens after More has gone")
        expect(!bar("More").exists, "More is closed under church mode")
        settle()
        shot("church-mode")
        tap(app.buttons["Leave worship mode"], "Leave worship mode")
        expect(waitGone(app.buttons["Leave worship mode"], timeout: 5), "church mode closes back to the reader")

        // Done on the root.
        openMore()
        tap(done("More"), "Done on More's root")
        expect(waitGone(bar("More"), timeout: 5), "Done dismisses More")
        settle()
        shot("closed")
    }
}
