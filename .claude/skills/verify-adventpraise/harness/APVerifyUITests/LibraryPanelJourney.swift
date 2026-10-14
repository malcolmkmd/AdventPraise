//
//  LibraryPanelJourney.swift
//  APVerifyUITests
//
//  features/library-panel.md. Needs a fresh install (no favourites, no
//  playlists, the first-playlist reveal not yet spent).
//

import XCTest

final class LibraryPanelJourney: JourneyCase {
    override var journeyName: String { "library-panel" }

    func testAddHymnAndNewPlaylist() {
        launch()
        tap(app.buttons["Favourites and playlists"], "the Lectern's library button")
        let addHymn = app.buttons["Add hymn"]
        expect(addHymn.waitForExistence(timeout: 5), "Favourites tab shows the Add hymn button")
        let tabs = app.segmentedControls.firstMatch
        expect(tabs.exists, "the Favourites/Playlists segmented control is there")
        let window = app.windows.firstMatch.frame
        note("segmented control width \(Int(tabs.frame.width)) of window \(Int(window.width)); Add hymn width \(Int(addHymn.frame.width))")
        expect(tabs.frame.width > window.width * 0.7, "the tabs span the panel (no round + beside them)")
        expect(addHymn.frame.maxY > tabs.frame.maxY, "Add hymn sits below the list, at the panel's foot")
        settle()
        shot("favourites-empty")

        // Add hymn by number: 100 is "What A Friend We Have In Jesus".
        addHymn.tap(); note("tap Add hymn")
        let prompt = app.alerts["Add Hymn"]
        expect(prompt.waitForExistence(timeout: 5), "the Add Hymn alert asks for a number")
        prompt.textFields.firstMatch.tap()
        prompt.textFields.firstMatch.typeText("100"); note("type 100")
        shot("add-hymn-alert")
        tap(prompt.buttons["Add"], "Add")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '100, '")).firstMatch
        expect(row.waitForExistence(timeout: 5), "hymn 100 is listed in Favourites")
        note("row label: \(row.label)")
        expect(row.label.contains("favourite"), "the row reads as a favourite")
        settle()
        shot("favourite-added")

        // A number the hymnal doesn't have.
        addHymn.tap(); note("tap Add hymn")
        expect(prompt.waitForExistence(timeout: 5), "the Add Hymn alert again")
        prompt.textFields.firstMatch.tap()
        prompt.textFields.firstMatch.typeText("9999"); note("type 9999")
        tap(prompt.buttons["Add"], "Add")
        let missing = app.alerts.matching(NSPredicate(format: "label BEGINSWITH 'No Hymn '")).firstMatch
        expect(missing.waitForExistence(timeout: 5), "a gentle 'No Hymn …' alert")
        note("alert title: \(missing.label)")
        check(missing.label == "No Hymn 9999", "the alert names the number as typed, 'No Hymn 9999' (got '\(missing.label)')")
        expect(missing.buttons["Try Again"].exists, "it offers Try Again")
        shot("no-such-hymn")
        tap(missing.buttons["Cancel"], "Cancel")

        // Playlists tab: the foot button follows the tab.
        tap(tabs.buttons["Playlists"], "the Playlists tab")
        let newPlaylist = app.buttons["New Playlist"]
        expect(newPlaylist.waitForExistence(timeout: 5), "Playlists tab shows the New Playlist button")
        expect(!addHymn.exists, "Add hymn is gone on Playlists")
        settle()
        shot("playlists-empty")
        newPlaylist.tap(); note("tap New Playlist")
        let name = app.alerts["New Playlist"]
        expect(name.waitForExistence(timeout: 5), "the New Playlist name prompt")
        name.textFields.firstMatch.tap()
        name.textFields.firstMatch.typeText("Verify set"); note("type Verify set")
        tap(name.buttons["Create"], "Create")
        expect(app.navigationBars["Verify set"].waitForExistence(timeout: 5), "the playlist editor opens on 'Verify set'")
        expect(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hymn 191'")).firstMatch.exists
               || app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Hymn 191'")).firstMatch.exists
               || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hymn 191'")).firstMatch.exists,
               "the new playlist holds the open hymn, 191")
        settle()
        shot("playlist-editor")
        tap(app.navigationBars["Verify set"].buttons["Done"], "Done")

        // First playlist only: the library comes back on Playlists, showing it.
        let listRow = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Verify set, '")).firstMatch
        expect(listRow.waitForExistence(timeout: 6), "after the first playlist, the library reveals it on Playlists")
        expect(app.buttons["New Playlist"].exists, "…with the Playlists tab selected")
        settle()
        shot("first-playlist-revealed")
    }
}
