import Foundation

/// What earned the ask.
enum ReviewTrigger: String, Sendable, Equatable {
    case thirdFavourite = "third_favourite"
    case sheetMusicFinished = "sheet_music_finished"
    case accompanimentFinished = "accompaniment_finished"
    case fifthSession = "fifth_session"
}

/// How the pre-prompt sheet ended.
enum ReviewPromptOutcome: String, Sendable {
    /// "Rate Advent Praise": the system review prompt was requested.
    case rate
    case notNow = "not_now"
    /// Swiped away.
    case dismissed
}

/// The rating-ask rules, kept free of UI and storage so they can be tested.
///
/// - Only after real use: never in the first session.
/// - Never straight after the paywall or a purchase (a cooldown).
/// - At most once per app version, whatever the answer.
struct ReviewEligibility: Equatable, Codable, Sendable {
    static let favouritesNeeded = 3
    static let sessionsNeeded = 5
    /// How long after a paywall or purchase nothing is asked.
    static let paywallCooldown: TimeInterval = 10 * 60

    var sessions = 0
    var favouritesAdded = 0
    /// The version the ask was last shown in.
    var askedVersion: String?
    var lastPaywallOrPurchase: Date?

    // MARK: Recording

    /// A launch or a return from the background. Returns the trigger it earns.
    mutating func recordSession(version: String, now: Date) -> ReviewTrigger? {
        sessions += 1
        return sessions >= Self.sessionsNeeded ? check(.fifthSession, version: version, now: now) : nil
    }

    mutating func recordFavouriteAdded(version: String, now: Date) -> ReviewTrigger? {
        favouritesAdded += 1
        return favouritesAdded >= Self.favouritesNeeded ? check(.thirdFavourite, version: version, now: now) : nil
    }

    mutating func recordPaywallOrPurchase(now: Date) { lastPaywallOrPurchase = now }

    func finishedPlayback(_ trigger: ReviewTrigger, version: String, now: Date) -> ReviewTrigger? {
        check(trigger, version: version, now: now)
    }

    mutating func markAsked(version: String) { askedVersion = version }

    // MARK: Rules

    func canAsk(version: String, now: Date) -> Bool {
        // The first session is never real use yet.
        guard sessions >= 2 else { return false }
        guard askedVersion != version else { return false }
        if let last = lastPaywallOrPurchase, now.timeIntervalSince(last) < Self.paywallCooldown { return false }
        return true
    }

    private func check(_ trigger: ReviewTrigger, version: String, now: Date) -> ReviewTrigger? {
        canAsk(version: version, now: now) ? trigger : nil
    }
}
