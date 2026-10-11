//
//  Analytics.swift
//  Advent Praise
//
//  Privacy-first product analytics via PostHog: anonymous only (never
//  identify, no person profiles), no autocapture, no screen views, no
//  session replay, no purchase amounts. Events carry a hymnal key and at
//  most a hymn number. An empty project token turns analytics off.
//

import Foundation
@preconcurrency import PostHog

enum AnalyticsEvent {
    case appOpened
    case hymnOpened(hymnal: String, number: Int)
    case hymnalSwitched(hymnal: String)
    case searchUsed(lyrics: Bool)
    case churchModeStarted(hymnal: String)
    case largePrintChanged(on: Bool)
    case purchaseCompleted(hymnal: String)
    case restoreTapped
    case mailComposed(kind: String)
    case shortcutRun(intent: String)
    case whatsNewContinued(action: String)

    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .hymnOpened: "hymn_opened"
        case .hymnalSwitched: "hymnal_switched"
        case .searchUsed: "search_used"
        case .churchModeStarted: "church_mode_started"
        case .largePrintChanged: "large_print_changed"
        case .purchaseCompleted: "purchase_completed"
        case .restoreTapped: "restore_tapped"
        case .mailComposed: "mail_composed"
        case .shortcutRun: "shortcut_run"
        case .whatsNewContinued: "whats_new_continued"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appOpened, .restoreTapped: [:]
        case let .hymnOpened(hymnal, number): ["hymnal": hymnal, "number": number]
        case let .hymnalSwitched(hymnal), let .churchModeStarted(hymnal), let .purchaseCompleted(hymnal): ["hymnal": hymnal]
        case let .searchUsed(lyrics): ["scope": lyrics ? "lyrics" : "titles"]
        case let .largePrintChanged(on): ["on": on]
        case let .mailComposed(kind): ["kind": kind]
        case let .shortcutRun(intent): ["intent": intent]
        case let .whatsNewContinued(action): ["action": action]
        }
    }
}

@MainActor
enum Analytics {
    /// PostHog project token ("phc_…"). TODO (Malcolm): paste the real token.
    static let projectToken = ""
    static let host = "https://eu.i.posthog.com"

    private static var isEnabled = false

    static func start() {
        guard !projectToken.isEmpty else { return }
        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.personProfiles = .never
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.captureSwiftUIElementInteractions = false
        config.enableSwizzling = false
        config.sessionReplay = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false
        config.errorTrackingConfig.autoCapture = false
        config.surveys = false
        // No IP → location lookup, so the App Privacy label has no Location.
        config.disableGeoIp = true
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }
}
