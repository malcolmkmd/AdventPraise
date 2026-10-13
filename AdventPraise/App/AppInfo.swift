//
//  AppInfo.swift
//  Advent Praise
//

import Foundation

enum AppInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }
    static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }
    static let appStoreID = "1015021132"
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id1015021132")!
    /// Opens the App Store's write-a-review page. `requestReview` is rate-limited
    /// and may show nothing, so a button must not rely on it.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id1015021132?action=write-review")!
    static let shareText = "Advent Praise — Christ In Song in 9 languages."
    /// Credited in Privacy & credits: the source of the MIDI accompaniment.
    static let cyberHymnalURL = URL(string: "http://hymntime.com")!
}
