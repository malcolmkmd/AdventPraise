//
//  Analytics.swift
//  Advent Praise
//
//  The one place the app sends product analytics (PostHog, EU). Call sites
//  say what happened (`Analytics.track(.hymnOpened(…))`); the typed events
//  are in AnalyticsEvent.swift.
//
//  Privacy:
//  - Anonymous. Never identified, no person profiles. The distinct ID is a
//    random UUID kept on the device; it is not the IDFV, and there is no IDFA
//    and no App Tracking Transparency prompt (nothing tracks across apps).
//  - The user's "Share anonymous usage" switch (More → About). Off: PostHog
//    is opted out and reset, which deletes the anonymous ID and the super
//    properties; on again starts a new ID that can't be joined to the old one.
//  - No autocapture, session replay, crash capture, surveys, feature flags
//    or GeoIP. Events carry catalogue keys, hymn numbers, counts and enums.
//  - DEBUG builds log every event to the console and send nothing, unless
//    launched with `-analytics.debugSend YES`.
//  - An empty project token turns sending off; the events are still logged.
//
//  Also here: app open / background (with time in the foreground), screen
//  views, super properties (hymnal, surface, large print) and non-fatal
//  errors, which go to os.Logger and to `error_occurred`.
//

import Foundation
import Observation
import os
@preconcurrency import PostHog
import SwiftUI

@Observable
@MainActor
final class Analytics {
    static let shared = Analytics()

    /// PostHog project token ("phc_…"). TODO (Malcolm): paste the real token.
    static let projectToken = ""
    static let host = "https://eu.i.posthog.com"
    /// Whether a new install shares usage until the user says otherwise.
    /// See ANALYTICS_AUDIT.md (P2) before changing it for the EEA.
    static let defaultEnabled = true

    /// The user's "Share anonymous usage" switch.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            applyConsent()
        }
    }

    /// PostHog is set up (a token, and not a debug build that keeps quiet).
    @ObservationIgnored private var isSending = false
    @ObservationIgnored private var hasStarted = false
    /// Super properties, kept so they can be registered again after an opt-in.
    @ObservationIgnored private var context: [String: Any] = [:]
    @ObservationIgnored private var foregroundSince: ContinuousClock.Instant?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    /// Tracked before `start()` (the shared models are built first); sent by it.
    @ObservationIgnored private var early: [AnalyticsEvent] = []

    private static let enabledKey = "analytics.enabled"
    private static let debugSendKey = "analytics.debugSend"
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdventPraise", category: "analytics")

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Self.enabledKey) == nil ? Self.defaultEnabled : defaults.bool(forKey: Self.enabledKey)
    }

    // MARK: Starting

    /// Once, at launch. Sends the cold `app_opened`.
    static func start() { shared.start() }

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true
        var sends = !Self.projectToken.isEmpty
        #if DEBUG
        sends = sends && UserDefaults.standard.bool(forKey: Self.debugSendKey)
        #endif
        if sends {
            let config = PostHogConfig(projectToken: Self.projectToken, host: Self.host)
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
            config.optOut = !isEnabled
            PostHogSDK.shared.setup(config)
            isSending = true
            // PostHog keeps its own copy of the opt-out; ours is the truth.
            if isEnabled { PostHogSDK.shared.optIn() } else { PostHogSDK.shared.optOut() }
            if isEnabled, !context.isEmpty { PostHogSDK.shared.register(context) }
        }
        observeLifecycle()
        foregroundSince = .now
        track(.appOpened(launch: .cold))
        early.forEach(track)
        early = []
    }

    private func applyConsent() {
        Self.log.info("Usage sharing \(self.isEnabled ? "on" : "off", privacy: .public)")
        guard isSending else { return }
        if isEnabled {
            PostHogSDK.shared.optIn()
            if !context.isEmpty { PostHogSDK.shared.register(context) }
            foregroundSince = .now
        } else {
            PostHogSDK.shared.optOut()
            PostHogSDK.shared.reset()
        }
    }

    // MARK: Sending

    static func track(_ event: AnalyticsEvent) { shared.track(event) }

    private func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        guard hasStarted else { early.append(event); return }
        let properties = event.properties
        Self.log.debug("\(event.name, privacy: .public) \(properties.description, privacy: .public)")
        guard isSending else { return }
        PostHogSDK.shared.capture(event.name, properties: properties)
    }

    static func screen(_ screen: AnalyticsScreen) {
        guard shared.isEnabled else { return }
        log.debug("screen \(screen.rawValue, privacy: .public)")
        guard shared.isSending else { return }
        PostHogSDK.shared.screen(screen.rawValue)
    }

    /// A non-fatal failure: logged in full on the device, counted by code in PostHog.
    static func error(_ domain: ErrorDomain, code: String, _ error: (any Error)? = nil) {
        if let error {
            log.error("\(domain.rawValue, privacy: .public) \(code, privacy: .public): \(String(describing: error))")
        } else {
            log.error("\(domain.rawValue, privacy: .public) \(code, privacy: .public)")
        }
        track(.errorOccurred(domain: domain, code: code))
    }

    /// The code is the error's domain and number ("RevenueCat.ErrorCode.10"), never its message.
    static func error(_ domain: ErrorDomain, _ error: any Error) {
        let ns = error as NSError
        self.error(domain, code: "\(ns.domain).\(ns.code)", error)
    }

    // MARK: Super properties

    /// The open hymnal, sent with every later event as `hymnal`.
    static func setHymnal(_ id: String) { shared.register(["hymnal": id]) }

    /// The reading surface and large print, sent with every later event.
    static func setAppearance(surface: DSSurface, largePrint: Bool) {
        shared.register(["surface": surface.rawValue, "large_print": largePrint])
    }

    private func register(_ properties: [String: Any]) {
        context.merge(properties) { _, new in new }
        guard isSending, isEnabled else { return }
        PostHogSDK.shared.register(properties)
    }

    // MARK: App lifecycle

    /// `app_opened` (warm) only when coming back from the background, not for
    /// every return from Control Centre or a system alert, and once per app
    /// rather than once per window.
    private func observeLifecycle() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Analytics.shared.didEnterBackground() }
        })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Analytics.shared.willEnterForeground() }
        })
    }

    private func didEnterBackground() {
        if let since = foregroundSince {
            let seconds = Int((ContinuousClock.now - since).components.seconds)
            track(.appBackgrounded(foregroundSeconds: seconds))
        }
        foregroundSince = nil
        if isSending, isEnabled { PostHogSDK.shared.flush() }
    }

    private func willEnterForeground() {
        foregroundSince = .now
        track(.appOpened(launch: .warm))
    }
}

// MARK: - SwiftUI

extension View {
    /// Sends a screen view each time this view appears.
    func analyticsScreen(_ screen: AnalyticsScreen) -> some View {
        onAppear { Analytics.screen(screen) }
    }
}
