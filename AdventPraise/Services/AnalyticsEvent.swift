//
//  AnalyticsEvent.swift
//  Advent Praise
//
//  Every product event the app can send, and every screen it names. Names
//  are snake_case `object_action`, past tense. Property values are typed
//  enums, numbers and booleans; the only strings are catalogue keys (hymnal,
//  Pro package or product ID), the app version and iOS's share activity
//  type. So nothing the user typed (search words, playlist names), no hymn
//  text and no price can reach PostHog. ANALYTICS_PLAN.md lists each event
//  and what it answers.
//

import Foundation

// MARK: - Property values

/// How a hymn came to be on screen.
enum HymnSource: String, Sendable {
    case numpad, search, favourites, playlist
    /// The accompaniment finished and the playlist (or service plan) moved on.
    case playlistAdvance = "playlist_advance"
    /// Page swipe in the reader, or the VoiceOver next / previous actions.
    case swipe
    /// Next / previous in church mode, past the last verse.
    case churchMode = "church_mode"
    case keyboard, siri
    case lockScreen = "lock_screen"
    /// The iPad sidebar's hymn list (searching there counts as `search`).
    case sidebar
    case collection
    /// A hymn citing the same passage (Scripture index, About this hymn).
    case scripture
    case servicePlan = "service_plan"
}

/// Where a hymnal was chosen.
enum HymnalSource: String, Sendable {
    /// The Lectern's Hymnals panel.
    case lectern
    /// The iPad sidebar's Hymnals sheet.
    case sidebar
    /// The reader's globe ("Hymn N in…").
    case translation
    /// The globe in church mode.
    case churchMode = "church_mode"
}

/// Which screen the Pro paywall covered.
enum PaywallContext: String, Sendable {
    case reader
    case churchMode = "church_mode"
}

enum RestoreSource: String, Sendable {
    case more
    case paywall
}

enum ChurchModeSource: String, Sendable {
    case tray, more
    case whatsNew = "whats_new"
    case siri, keyboard, voiceover
    case servicePlan = "service_plan"
    case collection
}

/// How a free user's screen reached another: an external display iOS
/// mirrors (AirPlay or a cable), or a capture (recording, a Mac, a
/// broadcast, or mirroring before the display's scene connects).
enum MirroringRoute: String, Sendable {
    case externalDisplay = "external_display"
    case capture
}

enum SearchScope: String, Sendable { case lyrics, titles }
enum SearchSurface: String, Sendable { case lectern, sidebar }

enum PlaylistEdit: String, Sendable {
    case hymnAdded = "hymn_added"
    case hymnRemoved = "hymn_removed"
    case reordered, renamed
}

enum ServicePlanEdit: String, Sendable {
    case hymnAdded = "hymn_added"
    case hymnRemoved = "hymn_removed"
    case reordered
    case roleSet = "role_set"
}

enum TextSizeContext: String, Sendable {
    case reader
    case churchMode = "church_mode"
}

enum TextSizeMethod: String, Sendable {
    case pinch
    /// The Appearance size slider or its − / + buttons.
    case slider
    /// Church mode's A− / A+ buttons.
    case buttons
    /// Double-tap back to the default size.
    case reset
}

/// One Appearance setting and its new value.
enum AppearanceChange: Sendable {
    case surface(DSSurface)
    case font(DS.ReadingFont)
    case lineSpacing(DS.LineSpacing)
    case centered(Bool)
    case largePrint(Bool)

    var setting: String {
        switch self {
        case .surface: "surface"
        case .font: "font"
        case .lineSpacing: "line_spacing"
        case .centered: "alignment"
        case .largePrint: "large_print"
        }
    }

    var value: String {
        switch self {
        case let .surface(surface): surface.rawValue
        case let .font(font): font.rawValue
        case let .lineSpacing(spacing): spacing.rawValue
        case let .centered(on): on ? "centered" : "leading"
        case let .largePrint(on): on ? "on" : "off"
        }
    }
}

enum ToggleSetting: String, Sendable {
    case haptics
    case repeatChorus = "repeat_chorus"
}

enum PurchaseFailure: String, Sendable {
    /// The product hadn't loaded from the App Store (offline, or not set up).
    case unavailable
    case storeError = "store_error"
    /// The App Store took the purchase but Pro isn't among the entitlements.
    case notActivated = "not_activated"
    /// Ask to Buy, or a payment check: it may still go through later.
    case pending
    /// StoreKit couldn't verify the transaction's signature.
    case unverified
    /// Purchases are turned off on the device (Screen Time).
    case notAllowed = "not_allowed"
}

enum PaywallOutcome: String, Sendable {
    /// Pro became active while it was open (bought or restored).
    case unlocked
    case closed
}

enum WhatsNewAction: String, Sendable {
    /// "Try Worship Mode".
    case primary
    case `continue`
    /// Swiped or tapped away.
    case dismissed
}

enum ExternalLink: String, Sendable {
    case rateApp = "rate_app"
}

enum IntentKind: String, Sendable {
    case openHymn = "open_hymn"
    case playHymn = "play_hymn"
    case nextHymn = "next_hymn"
    case churchMode = "church_mode"
}

enum PitchPipeAction: String, Sendable {
    /// The big button, sounding the hymnal's published note.
    case publishedNote = "published_note"
    /// The big button, sounding the singer's own note.
    case customNote = "custom_note"
    /// A key on the chromatic keyboard (chooses and sounds it).
    case keyChosen = "key_chosen"
}

enum MemoryPart: String, Sendable { case verse, chorus }

/// Which button on Memorise's completion card started the next round.
enum MemoryReplay: String, Sendable {
    /// The same stanza and level, with fresh blanks.
    case again
    /// The next level of the same stanza.
    case nextLevel = "next_level"
    /// The next verse or chorus.
    case nextBlock = "next_block"
    /// A learned stanza, from "A few" again.
    case startOver = "start_over"
}

/// Where a scripture chip was tapped.
enum ScriptureSurface: String, Sendable {
    /// About this hymn's Scripture section.
    case aboutHymn = "about_hymn"
    /// A passage's page (from About this hymn or the Scripture index).
    case passage
    /// The About panel in the reader menu.
    case readerMenu = "reader_menu"
}

/// Where a Tools sheet was opened from.
enum ToolSource: String, Sendable {
    case more
    /// The Lectern's hymn tray (Memorise).
    case tray
    /// The reader menu's About panel (the full About this hymn).
    case readerMenu = "reader_menu"
}

/// A non-fatal failure. The code is ours or a framework error code, never a message.
enum ErrorDomain: String, Sendable {
    case audio, purchase, restore, products
    case hymnalLoad = "hymnal_load"
}

enum LaunchKind: String, Sendable {
    case cold
    /// Back from the background.
    case warm
}

// MARK: - Events

enum AnalyticsEvent: Sendable {
    // App
    case appOpened(launch: LaunchKind)
    case appBackgrounded(foregroundSeconds: Int)

    // Reading
    case hymnOpened(hymnal: String, number: Int, source: HymnSource)
    case hymnalSwitched(from: String, to: String, source: HymnalSource)
    case searchPerformed(surface: SearchSurface, scope: SearchScope, queryLength: Int, resultCount: Int, isNumber: Bool)
    case searchResultOpened(surface: SearchSurface, scope: SearchScope, rank: Int)
    case favouriteToggled(number: Int, isFavourite: Bool)
    /// The globe grew into the reader menu; `panel` is the one open under it.
    case readerMenuOpened(panel: ReaderMenuPanel?)
    /// A tab in the open reader menu showed its panel.
    case readerMenuPanelOpened(panel: ReaderMenuPanel)
    case toolOpened(ExtraSheet, source: ToolSource)

    // Playlists
    case playlistCreated(hymnCount: Int)
    case playlistEdited(action: PlaylistEdit, hymnCount: Int)
    case playlistDeleted(hymnCount: Int)
    case playlistPlayed(hymnCount: Int, startIndex: Int)

    // Service planner
    case servicePlanCreated(hymnCount: Int)
    case servicePlanEdited(action: ServicePlanEdit, hymnCount: Int)
    case servicePlanDeleted(hymnCount: Int)
    case servicePlanStarted(hymnCount: Int)
    case collectionStarted(hymnCount: Int)

    // Church mode
    case churchModeEntered(source: ChurchModeSource)
    case churchModeExited(seconds: Int, versesShown: Int, hymnsShown: Int)
    case churchModeCastChanged(isConnected: Bool, showsHymn: Bool)
    /// A free user's screen is being mirrored or captured, so the Go Pro
    /// banner shows. Once per session.
    case mirroringDetected(via: MirroringRoute, inChurchMode: Bool)

    // Appearance
    case appearanceChanged(AppearanceChange)
    case textSizeChanged(context: TextSizeContext, method: TextSizeMethod, pointSize: Int)
    case settingChanged(ToggleSetting, isOn: Bool)

    // Accompaniment
    case accompanimentPlayed(number: Int, tempo: PlaybackTempo, resumed: Bool)
    case accompanimentPaused(number: Int, progressPercent: Int)
    case accompanimentCompleted(number: Int, tempo: PlaybackTempo, verses: Int)
    case accompanimentTempoChanged(tempo: PlaybackTempo)
    /// A free user started a new play; `remaining` is what's left after it.
    case freePlayUsed(number: Int, remaining: Int)
    /// A new play was refused because the free plays are used up; the paywall opens.
    case playLimitPaywallShown(number: Int)

    // Pro paywall and purchases
    case paywallViewed(feature: ProFeature, context: PaywallContext)
    case paywallDismissed(feature: ProFeature, context: PaywallContext, outcome: PaywallOutcome)
    case purchaseStarted(product: String, feature: ProFeature)
    case purchaseCompleted(product: String, feature: ProFeature)
    case purchaseCancelled(product: String, feature: ProFeature)
    case purchaseFailed(product: String, feature: ProFeature, reason: PurchaseFailure)
    case restoreStarted(source: RestoreSource)
    case restoreCompleted(foundPurchases: Bool, proActive: Bool)
    case restoreFailed
    // Tips (one-off, unlock nothing); the product ID, never the amount
    case tipStarted(product: String)
    case tipCompleted(product: String)
    case tipCancelled(product: String)
    case tipFailed(product: String, reason: PurchaseFailure)

    // Tools
    case memoryGameStarted(part: MemoryPart, level: MemoryRound.Level, wordCount: Int)
    case memoryGameCompleted(part: MemoryPart, level: MemoryRound.Level, score: Int, bestStreak: Int,
                             firstTryPercent: Int, hintsUsed: Int, stars: Int)
    /// A hint spent (a letter shown, chips that can't fit ruled out).
    case memoryHintUsed(part: MemoryPart, level: MemoryRound.Level, hintsLeft: Int)
    /// A streak reached a hint-earning length (3, 6, 9…).
    case memoryStreakReached(part: MemoryPart, level: MemoryRound.Level, streak: Int)
    /// A stanza finished with every word hidden.
    case memoryVerseLearned(part: MemoryPart, stars: Int)
    /// A new round chosen from the completion card.
    case memoryRoundReplayed(part: MemoryPart, level: MemoryRound.Level, reason: MemoryReplay)
    case pitchPipeUsed(PitchPipeAction)
    /// A passage opened on bible.com / in YouVersion. `book` is the USFM code;
    /// `number` and `confidence` are nil from a passage page.
    case scriptureOpened(hymnal: String, number: Int?, book: String, confidence: ScriptureConfidence?,
                         surface: ScriptureSurface)

    // Feedback, sharing, system
    /// Vote on features opened. `disclosed`: straight to the board (the
    /// first-open notice was accepted before).
    case featureBoardOpened(disclosed: Bool)
    /// Continue on the first-open notice.
    case featureBoardDisclosureAccepted
    /// `showedBoard`: the board loaded (false: closed at the notice).
    case featureBoardClosed(seconds: Int, showedBoard: Bool)
    case whatsNewViewed(version: String)
    case whatsNewDismissed(version: String, action: WhatsNewAction)
    // The onboarding tour (TourModel.swift)
    case tourStarted(source: TourSource)
    /// A step's control was used (or Next taken) and the next step opened.
    case tourStepCompleted(step: Int)
    /// `completed`: Done on the last card; false for Skip tour. `lastStep`: the step reached.
    case tourFinished(completed: Bool, lastStep: Int)
    case shareOpened
    case shareFinished(completed: Bool, activity: String?)
    case externalLinkOpened(ExternalLink)
    case intentRun(IntentKind, succeeded: Bool)
    case errorOccurred(domain: ErrorDomain, code: String)

    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .appBackgrounded: "app_backgrounded"
        case .hymnOpened: "hymn_opened"
        case .hymnalSwitched: "hymnal_switched"
        case .searchPerformed: "search_performed"
        case .searchResultOpened: "search_result_opened"
        case .favouriteToggled: "favourite_toggled"
        case .readerMenuOpened: "reader_menu_opened"
        case .readerMenuPanelOpened: "reader_menu_panel_opened"
        case .toolOpened: "tool_opened"
        case .playlistCreated: "playlist_created"
        case .playlistEdited: "playlist_edited"
        case .playlistDeleted: "playlist_deleted"
        case .playlistPlayed: "playlist_played"
        case .servicePlanCreated: "service_plan_created"
        case .servicePlanEdited: "service_plan_edited"
        case .servicePlanDeleted: "service_plan_deleted"
        case .servicePlanStarted: "service_plan_started"
        case .collectionStarted: "collection_started"
        case .churchModeEntered: "church_mode_entered"
        case .churchModeExited: "church_mode_exited"
        case .churchModeCastChanged: "church_mode_cast_changed"
        case .mirroringDetected: "mirroring_detected"
        case .appearanceChanged: "appearance_changed"
        case .textSizeChanged: "text_size_changed"
        case .settingChanged: "setting_changed"
        case .accompanimentPlayed: "accompaniment_played"
        case .accompanimentPaused: "accompaniment_paused"
        case .accompanimentCompleted: "accompaniment_completed"
        case .accompanimentTempoChanged: "accompaniment_tempo_changed"
        case .freePlayUsed: "free_play_used"
        case .playLimitPaywallShown: "play_limit_paywall_shown"
        case .paywallViewed: "paywall_viewed"
        case .paywallDismissed: "paywall_dismissed"
        case .purchaseStarted: "purchase_started"
        case .purchaseCompleted: "purchase_completed"
        case .purchaseCancelled: "purchase_cancelled"
        case .purchaseFailed: "purchase_failed"
        case .restoreStarted: "restore_started"
        case .restoreCompleted: "restore_completed"
        case .restoreFailed: "restore_failed"
        case .tipStarted: "tip_started"
        case .tipCompleted: "tip_completed"
        case .tipCancelled: "tip_cancelled"
        case .tipFailed: "tip_failed"
        case .memoryGameStarted: "memory_game_started"
        case .memoryGameCompleted: "memory_game_completed"
        case .memoryHintUsed: "memory_hint_used"
        case .memoryStreakReached: "memory_streak_reached"
        case .memoryVerseLearned: "memory_verse_learned"
        case .memoryRoundReplayed: "memory_round_replayed"
        case .pitchPipeUsed: "pitch_pipe_used"
        case .scriptureOpened: "scripture_opened"
        case .featureBoardOpened: "feature_board_opened"
        case .featureBoardDisclosureAccepted: "feature_board_disclosure_accepted"
        case .featureBoardClosed: "feature_board_closed"
        case .whatsNewViewed: "whats_new_viewed"
        case .whatsNewDismissed: "whats_new_dismissed"
        case .tourStarted: "tour_started"
        case .tourStepCompleted: "tour_step_completed"
        case .tourFinished: "tour_finished"
        case .shareOpened: "share_opened"
        case .shareFinished: "share_finished"
        case .externalLinkOpened: "external_link_opened"
        case .intentRun: "intent_run"
        case .errorOccurred: "error_occurred"
        }
    }

    var properties: [String: Any] {
        switch self {
        case let .appOpened(launch): ["launch": launch.rawValue]
        case let .appBackgrounded(seconds): ["foreground_seconds": seconds]
        case let .hymnOpened(hymnal, number, source):
            ["hymnal": hymnal, "hymn_number": number, "source": source.rawValue]
        case let .hymnalSwitched(from, to, source):
            ["from_hymnal": from, "to_hymnal": to, "source": source.rawValue]
        case let .searchPerformed(surface, scope, length, results, isNumber):
            ["surface": surface.rawValue, "scope": scope.rawValue, "query_length": length,
             "result_count": results, "is_number": isNumber]
        case let .searchResultOpened(surface, scope, rank):
            ["surface": surface.rawValue, "scope": scope.rawValue, "rank": rank]
        case let .favouriteToggled(number, isFavourite):
            ["hymn_number": number, "is_favourite": isFavourite]
        case let .readerMenuOpened(panel): ["panel": panel?.rawValue ?? "none"]
        case let .readerMenuPanelOpened(panel): ["panel": panel.rawValue]
        case let .toolOpened(tool, source): ["tool": tool.rawValue, "source": source.rawValue]
        case let .playlistCreated(count), let .playlistDeleted(count),
             let .servicePlanCreated(count), let .servicePlanDeleted(count),
             let .servicePlanStarted(count), let .collectionStarted(count):
            ["hymn_count": count]
        case let .playlistEdited(action, count): ["action": action.rawValue, "hymn_count": count]
        case let .playlistPlayed(count, start): ["hymn_count": count, "start_index": start]
        case let .servicePlanEdited(action, count): ["action": action.rawValue, "hymn_count": count]
        case let .churchModeEntered(source): ["source": source.rawValue]
        case let .churchModeExited(seconds, verses, hymns):
            ["duration_seconds": seconds, "verses_shown": verses, "hymns_shown": hymns]
        case let .churchModeCastChanged(isConnected, showsHymn):
            ["is_connected": isConnected, "shows_hymn": showsHymn]
        case let .mirroringDetected(route, inChurchMode): ["via": route.rawValue, "in_church_mode": inChurchMode]
        case let .appearanceChanged(change): ["setting": change.setting, "value": change.value]
        case let .textSizeChanged(context, method, size):
            ["context": context.rawValue, "method": method.rawValue, "point_size": size]
        case let .settingChanged(setting, isOn): ["setting": setting.rawValue, "is_on": isOn]
        case let .accompanimentPlayed(number, tempo, resumed):
            ["hymn_number": number, "tempo": tempo.rawValue, "resumed": resumed]
        case let .accompanimentPaused(number, progress):
            ["hymn_number": number, "progress_percent": progress]
        case let .accompanimentCompleted(number, tempo, verses):
            ["hymn_number": number, "tempo": tempo.rawValue, "verses": verses]
        case let .accompanimentTempoChanged(tempo): ["tempo": tempo.rawValue]
        case let .freePlayUsed(number, remaining): ["hymn_number": number, "remaining": remaining]
        case let .playLimitPaywallShown(number): ["hymn_number": number]
        case let .paywallViewed(feature, context):
            ["feature": feature.analyticsName, "context": context.rawValue]
        case let .paywallDismissed(feature, context, outcome):
            ["feature": feature.analyticsName, "context": context.rawValue, "outcome": outcome.rawValue]
        case let .purchaseStarted(product, feature), let .purchaseCompleted(product, feature),
             let .purchaseCancelled(product, feature):
            ["product": product, "feature": feature.analyticsName]
        case let .purchaseFailed(product, feature, reason):
            ["product": product, "feature": feature.analyticsName, "reason": reason.rawValue]
        case let .restoreStarted(source): ["source": source.rawValue]
        case let .restoreCompleted(found, pro): ["found_purchases": found, "pro_active": pro]
        case let .tipStarted(product), let .tipCompleted(product), let .tipCancelled(product): ["product": product]
        case let .tipFailed(product, reason): ["product": product, "reason": reason.rawValue]
        case .restoreFailed, .shareOpened, .featureBoardDisclosureAccepted: [:]
        case let .featureBoardOpened(disclosed): ["disclosed": disclosed]
        case let .featureBoardClosed(seconds, showedBoard):
            ["duration_seconds": seconds, "showed_board": showedBoard]
        case let .memoryGameStarted(part, level, words):
            ["part": part.rawValue, "level": level.analyticsName, "word_count": words]
        case let .memoryGameCompleted(part, level, score, streak, firstTry, hints, stars):
            ["part": part.rawValue, "level": level.analyticsName, "score": score, "best_streak": streak,
             "first_try_percent": firstTry, "hints_used": hints, "stars": stars]
        case let .memoryHintUsed(part, level, left):
            ["part": part.rawValue, "level": level.analyticsName, "hints_left": left]
        case let .memoryStreakReached(part, level, streak):
            ["part": part.rawValue, "level": level.analyticsName, "streak": streak]
        case let .memoryVerseLearned(part, stars): ["part": part.rawValue, "stars": stars]
        case let .memoryRoundReplayed(part, level, reason):
            ["part": part.rawValue, "level": level.analyticsName, "reason": reason.rawValue]
        case let .pitchPipeUsed(action): ["action": action.rawValue]
        case let .scriptureOpened(hymnal, number, book, confidence, surface):
            (["hymnal": hymnal, "book": book, "surface": surface.rawValue,
              "hymn_number": number, "confidence": confidence?.rawValue] as [String: Any?])
                .compactMapValues { $0 }
        case let .whatsNewViewed(version): ["version": version]
        case let .whatsNewDismissed(version, action): ["version": version, "action": action.rawValue]
        case let .tourStarted(source): ["source": source.rawValue]
        case let .tourStepCompleted(step): ["step": step]
        case let .tourFinished(completed, lastStep): ["completed": completed, "last_step": lastStep]
        case let .shareFinished(completed, activity):
            ["completed": completed, "activity": activity ?? "none"]
        case let .externalLinkOpened(link): ["link": link.rawValue]
        case let .intentRun(intent, succeeded): ["intent": intent.rawValue, "succeeded": succeeded]
        case let .errorOccurred(domain, code): ["domain": domain.rawValue, "code": code]
        }
    }
}

// MARK: - Screens

/// Sent as PostHog `$screen` events. PostHog also stamps the latest one on
/// every later event as `$screen_name`.
enum AnalyticsScreen: String, Sendable {
    case reader
    case churchMode = "church_mode"
    case more, appearance
    case hymnals
    case translations
    case paywall
    /// Support Advent Praise (the tips), from More.
    case support
    case search
    case library
    case numberPad = "number_pad"
    case whatsNew = "whats_new"
    case playlistEditor = "playlist_editor"
    case playlistHymnPicker = "playlist_hymn_picker"
    case aboutHymn = "about_hymn"
    /// The reader menu's About panel (the summary; `about_hymn` is the sheet).
    case aboutHymnPanel = "about_hymn_panel"
    case scriptureIndex = "scripture_index"
    case collections
    case pitchPipe = "pitch_pipe"
    case memoryGame = "memory_game"
    case servicePlanner = "service_planner"
    case servicePlan = "service_plan"
    /// About Advent Praise, the Privacy Policy and the Terms of Use, from More.
    case aboutApp = "about_app"
    case privacy
    case terms
    case share
    case featureBoard = "feature_board"
}

// MARK: - Names for enums defined elsewhere

extension MemoryRound.Level {
    var analyticsName: String { String(describing: self) }
}

extension ProFeature {
    var analyticsName: String {
        switch self {
        case .player: "player"
        case .airPlay: "air_play"
        case .mirroring: "mirroring"
        case .support: "support"
        }
    }
}
