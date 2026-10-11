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
    /// Must match the Privacy Policy URL in App Store Connect (Guideline 5.1.1).
    /// TODO (Malcolm): publish the page and confirm the URL — see docs/appstore/urls-checklist.md.
    static let privacyPolicyURL = URL(string: "https://adventpraise.app/privacy")!
    static let shareText = "Advent Praise — Christ In Song and SDA hymnals in 24 languages."
    /// Credited in More: the source of the MIDI accompaniment.
    static let cyberHymnalURL = URL(string: "http://hymntime.com")!
    /// Where corrections and requests go. TODO (Malcolm): confirm the support address.
    static let supportEmail = "support@adventpraise.app"
}
