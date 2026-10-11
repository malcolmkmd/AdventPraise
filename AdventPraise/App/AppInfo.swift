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
    static let shareText = "Advent Praise — Christ In Song and SDA hymnals in 24 languages."
    /// Where corrections and requests go. TODO (Malcolm): confirm the support address.
    static let supportEmail = "support@adventpraise.app"
}
