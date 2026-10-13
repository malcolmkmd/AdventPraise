//
//  FeatureBoardConfig.swift
//  Advent Praise
//
//  Features.Vote settings for More → Help us improve → Vote on features.
//  Kept free of the SDK so it can be checked without the vendor (the SDK
//  side is FeatureBoard.swift). FVOTE_STATUS.md says how to set the board up.
//
//  The board is Advent Praise's own. Its slug comes from the Info.plist key
//  FEATURES_VOTE_API_KEY (the build setting of the same name, empty in the
//  repo). Empty = no row in More and no SDK, so no network calls.
//
//  Anonymous: the SDK gives each install a random "anon_…" id. We never set
//  a name, email, custom id, spend or token, and new requests carry only the
//  app version and platform.
//

import Foundation

enum FeatureBoardConfig {
    static let infoPlistKey = "FEATURES_VOTE_API_KEY"

    /// Another app's board. Refused even if pasted in by mistake.
    static let refusedSlugs: Set<String> = ["myklippa"]

    static let platform = "ios"
    static let allowAnonymousVoting = true
    static let allowAnonymousComments = true
    static let requireEmailForCreate = false
    static let showWatermark = true

    /// The board slug from the app's Info.plist, or nil when there isn't one.
    static let slug: String? = slug(from: Bundle.main.infoDictionary)

    /// The More row and the SDK only exist when there is a board.
    static var isEnabled: Bool { slug != nil }

    /// `FEATURES_VOTE_API_KEY`, trimmed. nil when missing, empty, an
    /// unexpanded `$(…)` build setting, or another app's board.
    static func slug(from info: [String: Any]?) -> String? {
        guard let raw = info?[infoPlistKey] as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$("),
              !refusedSlugs.contains(value.lowercased()) else { return nil }
        return value
    }

    /// `post_metadata` on new requests. Never a name, email, id or token.
    static func metadata(appVersion: String) -> [String: String] {
        ["app_version": appVersion, "platform": platform]
    }

    // MARK: First open

    /// Set once the person has read what the board sends and chosen Continue.
    static let disclosedKey = "featureBoard.disclosedAt"

    static func hasDisclosed(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: disclosedKey) != nil
    }

    static func markDisclosed(defaults: UserDefaults = .standard, at date: Date = .now) {
        defaults.set(date, forKey: disclosedKey)
    }
}
