//
//  Support.swift
//  APVerifyUITests
//
//  Drives the installed Advent Praise DEBUG build by bundle id (this bundle
//  has no host app and links nothing from the app). Every journey launches
//  with `baseArguments`, taps by accessibility label/identifier, and records
//  evidence: a PNG per step plus a journal line saying what was done and
//  what was seen, under ../verify-evidence/<stamp>/<journey>/ next to the
//  repo (override with TEST_RUNNER_AP_EVIDENCE_DIR).
//

import XCTest

let appBundleID = "com.mDev.Advent-Praise"

/// Pro (no paywall or free-play prompts), no splash, no What's New, Christ In
/// Song (English) open at 191 "Blessed Assurance". Plain argument-domain
/// defaults: they win over saved values without overwriting them.
let baseArguments = [
    "-uiDebugPro", "YES",
    "-uiDebugNoSplash", "YES",
    "-whatsNew.lastSeenVersion", "7.0",
    "-reader.hymnal", "english",
    "-reader.lastHymn", "191",
    "-AppleLanguages", "(en)",
    "-AppleLocale", "en_US",
]

enum Evidence {
    /// One folder per test run, shared by every journey in it.
    static let runDirectory: URL = {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let root = evidenceRoot
        let dir = root.appendingPathComponent(stamp.string(from: Date()))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // So the agent can find this run without parsing the log.
        try? dir.path.write(to: root.appendingPathComponent("LATEST"), atomically: true, encoding: .utf8)
        print("AP-EVIDENCE-DIR \(dir.path)")
        return dir
    }()

    /// ../verify-evidence beside the checkout that holds this file.
    private static var evidenceRoot: URL {
        if let dir = ProcessInfo.processInfo.environment["AP_EVIDENCE_DIR"], !dir.isEmpty {
            return URL(fileURLWithPath: dir)
        }
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("AdventPraise.xcodeproj").path) {
                return url.deletingLastPathComponent().appendingPathComponent("verify-evidence")
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("verify-evidence")
    }
}

class JourneyCase: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0

    /// The folder for this journey's evidence, e.g. <run>/library-panel.
    var journeyName: String { "journey" }

    private var directory: URL {
        let dir = Evidence.runDirectory.appendingPathComponent(journeyName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Checks that failed without stopping the journey (see `check`).
    private var findings: [String] = []

    override func tearDown() {
        if let run = testRun, run.failureCount > 0, let app {
            shot("FAILED")
            // What XCUITest saw, for telling a harness bug from an app bug.
            try? app.debugDescription.write(to: directory.appendingPathComponent("FAILED-hierarchy.txt"),
                                            atomically: true, encoding: .utf8)
        }
        app?.terminate()
        // Still a failed test: the run isn't green while a finding stands.
        if !findings.isEmpty { XCTFail("Findings: " + findings.joined(separator: "; ")) }
        super.tearDown()
    }

    /// A check whose failure is a finding to report but shouldn't hide the
    /// rest of the journey (copy, formatting). Journal line: `FINDING …`.
    func check(_ condition: @autoclosure () -> Bool, _ what: String) {
        let ok = condition()
        note("\(ok ? "PASS" : "FINDING") \(what)")
        if !ok { findings.append(what) }
    }

    /// An AdventDrawer's card, by its title ("More", "About this hymn"). Its
    /// Back/Close live inside it; the reader menu has a Close of its own.
    /// The card is modal, so XCUITest reports it as an Alert.
    func drawer(_ title: String) -> XCUIElement {
        let alert = app.alerts[title]
        if alert.exists { return alert }
        let card = app.otherElements[title]
        return card.exists ? card : app
    }

    /// Launches the app fresh with the base arguments plus `extra`, and waits
    /// until the reader's Lectern is on screen (usable, not just running).
    @discardableResult
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: appBundleID)
        app.terminate()
        app.launchArguments = baseArguments + extra
        app.launch()
        self.app = app
        XCTAssertTrue(app.buttons["lectern.handle"].waitForExistence(timeout: 20),
                      "The reader never showed its Lectern (is the DEBUG build installed?)")
        note("launched with \(extra.isEmpty ? "base arguments" : extra.joined(separator: " "))")
        return app
    }

    /// A screenshot of the whole simulator screen, saved and attached.
    func shot(_ name: String) {
        shotIndex += 1
        let file = String(format: "%02d-%@.png", shotIndex, name)
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(file))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = file
        attachment.lifetime = .keepAlways
        add(attachment)
        note("shot \(file)")
    }

    /// A line in the journey's journal.txt and the test log.
    func note(_ line: String) {
        print("AP-JOURNAL [\(journeyName)] \(line)")
        let url = directory.appendingPathComponent("journal.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    /// Records a check in the journal and fails the journey when it doesn't hold.
    func expect(_ condition: @autoclosure () -> Bool, _ what: String,
                file: StaticString = #filePath, line: UInt = #line) {
        let ok = condition()
        note("\(ok ? "PASS" : "FAIL") \(what)")
        XCTAssertTrue(ok, what, file: file, line: line)
    }

    /// Waits for `element`, then taps it; fails with `what` if it never shows.
    func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 8,
             file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: timeout) else {
            note("FAIL could not find \(what)")
            XCTFail("Could not find \(what)", file: file, line: line)
            return
        }
        element.tap()
        note("tap \(what)")
    }

    /// Lets springs and drawer transitions settle before a screenshot.
    func settle(_ seconds: TimeInterval = 0.8) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Opens the Lectern's hymn tray (Church, Memorise, Playlist, Save, More).
    func openHymnTray() {
        tap(app.buttons["lectern.handle"], "the Lectern handle (Hymn actions)")
        expect(app.otherElements["lectern.hymnTray"].waitForExistence(timeout: 5)
               || app.buttons["Memorise"].waitForExistence(timeout: 2), "the hymn tray opened")
    }

    func waitGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: element)], timeout: timeout) == .completed
    }
}
