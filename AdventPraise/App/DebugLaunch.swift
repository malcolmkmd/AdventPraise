//
//  DebugLaunch.swift
//  Advent Praise
//
//  DEBUG builds only: launch arguments that open a screen straight away, so
//  simulator screenshots can be taken without tapping through the app.
//
//    -uiDebugSurface sepia        reading surface (paper, parchment, sepia, muted, black)
//    -uiDebugSheet memory         a Tools screen (about, memory, support; the rest are pages in More:
//                                 scripture, collections, pitch, planner, aboutApp, privacy, terms)
//    -uiDebugCollection gospel    a collection's hymns (with -uiDebugSheet collections)
//    -uiDebugSeedPlans YES        sample service plans (with -uiDebugSheet planner; nothing is saved; "empty": none)
//    -uiDebugPlan Vespers         a service plan by name (with -uiDebugSheet planner)
//    -uiDebugTranslations YES     the reader menu, on Translation
//    -uiDebugMenu theme           the reader menu (translation, theme, text, about; "bar": no panel)
//    -uiDebugMotionSpeed 0.05     the Lectern and reader menu springs slowed down, for screenshots
//    -uiDebugMore YES             the More sheet
//    -uiDebugFeatureBoard YES     Vote on features over More (needs a board; -featureBoard.disclosedAt 0 skips the notice)
//    -uiDebugPro YES              Pro unlocked (otherwise StoreKit decides: free unless bought in the
//                                 StoreKit configuration)
//    -uiDebugFree YES             free whatever StoreKit says (a simulator can keep a test purchase)
//    -uiDebugMIDI YES             MIDI Piano owned (the player alone), whatever StoreKit says
//    -uiDebugFreePlaysUsed 4      free plays already used (4: the next is the last; 5: Play opens the paywall)
//    -uiDebugPaywall YES          the Pro paywall (YES/player, airplay, mirroring, or support: opened from More).
//                                 "player" is the MIDI gate: Pro plus "Just the MIDI piano", prices from
//                                 the StoreKit configuration (add -uiDebugFree YES on a sim that bought Pro)
//    -uiDebugTour step-3          the onboarding tour at step 3 (1…8), set up for its screenshot:
//                                 the tray, menu, church mode or More already open where the step
//                                 needs it. "sidebar": step 8's iPad sidebar stage. Pass
//                                 -whatsNew.lastSeenVersion 7.0 with it; the tour never starts
//                                 from What's New while this is set
//    -tourSeen YES                the tour has been taken (plain UserDefaults): it never runs
//    -UITestSkipTour YES          UI tests: the tour never runs
//    -uiDebugTipThanks YES        the tip thank-you sheet (with -uiDebugSheet support)
//    -uiDebugPaywallDelay 2       the paywall opens this many seconds after launch, for a recording
//    -uiDebugChurch YES           church mode
//    -uiDebugExternal verse       the external screen's view on the phone (verse 2, "title", or "blank")
//    -uiDebugExternalConnected YES  as if a TV or projector were connected (church mode's remote)
//    -uiDebugRenderExternal /tmp/tv  writes the worship display at 1920×1080 to /tmp/tv-verse.png,
//                                 -chorus.png, -title.png and -blank.png (with -uiDebugPro YES)
//    -uiDebugMirroring YES        as if the screen were mirrored (the Go Pro banner, without Pro)
//    -uiDebugCentered YES        centered text alignment
//    -uiDebugHymn 412             opens this hymn number
//    -uiDebugQueue 12,30,45       runs these numbers as a service plan
//    -uiDebugChurchPad YES        church mode's number pad (with -uiDebugChurch)
//    -uiDebugChurchTranslations YES  church mode's translation switcher (with -uiDebugChurch)
//    -uiDebugChurchControls YES  church mode's controls never auto-hide
//    -uiDebugChurchBlock 2        church mode opens on this block of the sung sequence (0: verse 1)
//    -reader.hymnal tswana        opens this hymnal (plain UserDefaults; key from hymnals.json)
//    -uiDebugLectern hymn         a Lectern panel open (hymn tray, library)
//    -haptics.enabled NO          the Haptics switch off (plain UserDefaults)
//    -uiDebugPageDrag 60          the page-swipe arrow, frozen mid-drag
//    -uiDebugScroll 80            the reader scrolled 80 pt (header part-way / collapsed)
//    -uiDebugLegacyHeader YES     the header's iOS 17 scroll tracking on any OS
//    -uiDebugMemoryMoves 3        Memorise: 3 right picks, then a wrong one (99: finish)
//    -whatsNew.lastSeenVersion 7.0  skips What's New (plain UserDefaults)
//    -uiDebugNoSplash YES         no launch splash (What's New, if due, shows at once)
//    -uiDebugSplashSpeed 0.05     the splash reveal slowed down, for screenshots
//    -uiDebugPlay YES             the accompaniment playing (the hymn on screen)
//    -uiDebugDigits 100           the number pad open with these digits typed
//
//    -screenshotState 1…8        an App Store screenshot, fixed (SCREENSHOTS.md): replaces every
//                                 other -uiDebug argument with a preset (see ScreenshotState)
//

#if DEBUG
import Foundation

enum DebugLaunch {
    private static var defaults: UserDefaults { .standard }

    static var screenshotState: ScreenshotState? { ScreenshotState(rawValue: defaults.integer(forKey: "screenshotState")) }

    /// Rewrites the launch arguments for `-screenshotState`. Call before
    /// anything reads UserDefaults (AppServices.shared does). Idempotent.
    static func applyScreenshotState() {
        guard let state = screenshotState else { return }
        let domain = UserDefaults.argumentDomain
        // The argument domain is volatile, so it can be swapped: the preset wins
        // over the saved values, and other -uiDebug arguments are dropped.
        var arguments = defaults.volatileDomain(forName: domain).filter { !$0.key.hasPrefix("uiDebug") }
        arguments.merge(state.arguments) { _, preset in preset }
        defaults.removeVolatileDomain(forName: domain)
        defaults.setVolatileDomain(arguments, forName: domain)
    }

    static var surface: DSSurface? { defaults.string(forKey: "uiDebugSurface").flatMap(DSSurface.init) }
    static var sheet: ExtraSheet? { defaults.string(forKey: "uiDebugSheet").flatMap(ExtraSheet.init) }
    /// A collection id, e.g. "gospel": pushed over Collections in More.
    static var collection: String? { defaults.string(forKey: "uiDebugCollection") }
    /// Sample service plans in place of the saved ones (not written back); "empty": none.
    static var seededPlans: String? { defaults.string(forKey: "uiDebugSeedPlans") }
    /// A service plan's name: pushed over the Service planner in More.
    static var plan: String? { defaults.string(forKey: "uiDebugPlan") }

    /// `-uiDebugSheet` for a screen that is a page in More (all but About
    /// this hymn, Memorise and Support): More's path to it, with the collection or plan asked for.
    @MainActor static func morePages(model: ReaderModel) -> [MorePage]? {
        guard let sheet, let page = MorePage(sheet) else { return nil }
        var pages = [page]
        if sheet == .collections, let id = collection,
           let found = HymnCollections.all.first(where: { $0.id == id }) {
            pages.append(.collection(found))
        }
        if sheet == .planner, let name = plan,
           let found = ServicePlanner.shared.plans.first(where: { $0.name == name }) {
            pages.append(.plan(found.id))
        }
        return pages
    }
    static var showsTranslations: Bool { defaults.bool(forKey: "uiDebugTranslations") }
    /// The reader menu open at launch; `panel` nil is the bar alone.
    struct Menu { let panel: ReaderMenuPanel? }
    static var menu: Menu? {
        defaults.string(forKey: "uiDebugMenu").map { Menu(panel: ReaderMenuPanel(rawValue: $0)) }
    }
    /// Playback rate of the Lectern / reader menu spring. 1 when unset.
    static var motionSpeed: Double {
        let speed = defaults.double(forKey: "uiDebugMotionSpeed")
        return speed > 0 ? speed : 1
    }
    static var showsMore: Bool { defaults.bool(forKey: "uiDebugMore") }
    /// The Privacy Policy opens scrolled to Content we include.
    static var showsCredits: Bool { defaults.bool(forKey: "uiDebugCredits") }
    static var showsFeatureBoard: Bool { defaults.bool(forKey: "uiDebugFeatureBoard") }
    /// Pro unlocked whatever StoreKit says, so the app can be exercised.
    static var pro: Bool { defaults.bool(forKey: "uiDebugPro") }
    /// Free whatever StoreKit says (a simulator can keep a test purchase).
    static var free: Bool { defaults.bool(forKey: "uiDebugFree") }
    /// MIDI Piano owned (not Pro), whatever StoreKit says.
    static var midi: Bool { defaults.bool(forKey: "uiDebugMIDI") }
    /// The onboarding tour, opened at this step for a screenshot. "step-3",
    /// "3", or "sidebar" (step 8's iPad sidebar stage).
    static var tour: TourStart? {
        guard let raw = defaults.string(forKey: "uiDebugTour")?.lowercased() else { return nil }
        if raw == "sidebar" { return .sidebar }
        let digits = raw.filter(\.isNumber)
        guard let number = Int(digits), let step = TourStep(rawValue: number) else { return nil }
        return .step(step)
    }

    /// Where `-uiDebugTour` opens the tour.
    enum TourStart: Equatable {
        case step(TourStep)
        /// Step 8's iPad stage: the sidebar's Pro and Support rows.
        case sidebar
    }
    /// Free plays already used (0…5); stored, so it outlasts the launch.
    static var freePlaysUsed: Int? {
        defaults.object(forKey: "uiDebugFreePlaysUsed") == nil ? nil : defaults.integer(forKey: "uiDebugFreePlaysUsed")
    }
    static var showsChurch: Bool { defaults.bool(forKey: "uiDebugChurch") }
    /// "verse" or "title": the external screen's view, drawn on the phone.
    static var external: String? { defaults.string(forKey: "uiDebugExternal") }
    static var externalConnected: Bool { defaults.bool(forKey: "uiDebugExternalConnected") }
    /// A path prefix: the worship display is rendered to PNGs there at launch.
    static var renderExternal: String? { defaults.string(forKey: "uiDebugRenderExternal") }
    /// The screen counts as captured (mirrored), whatever iOS says.
    static var mirroring: Bool { defaults.bool(forKey: "uiDebugMirroring") }
    /// The paywall, leading with this feature. "YES" is the player.
    static var paywall: ProFeature? {
        switch defaults.string(forKey: "uiDebugPaywall")?.lowercased() {
        case "yes", "1", "true", "player": .player
        case "airplay": .airPlay
        case "mirroring": .mirroring
        case "support": .support
        default: nil
        }
    }
    static var showsTipThanks: Bool { defaults.bool(forKey: "uiDebugTipThanks") }
    /// Seconds after launch before the paywall opens, so a recording can start on the reader.
    static var paywallDelay: Double { defaults.double(forKey: "uiDebugPaywallDelay") }
    static var centered: Bool { defaults.bool(forKey: "uiDebugCentered") }
    static var queue: [Int]? {
        defaults.string(forKey: "uiDebugQueue").map { $0.split(separator: ",").compactMap { Int($0) } }
    }
    static var showsChurchPad: Bool { defaults.bool(forKey: "uiDebugChurchPad") }
    static var showsChurchTranslations: Bool { defaults.bool(forKey: "uiDebugChurchTranslations") }
    /// Church mode's controls stay up, for screenshots.
    static var keepsChurchControls: Bool { defaults.bool(forKey: "uiDebugChurchControls") }
    /// Church mode's starting block (verse or chorus, in sung order) in place of the first.
    static var churchBlock: Int { defaults.integer(forKey: "uiDebugChurchBlock") }
    /// "hymn" (the tray) or "library": a Lectern panel open.
    static var lectern: LecternState? {
        switch defaults.string(forKey: "uiDebugLectern") {
        case "hymn": .hymn
        case "library": .library
        default: nil
        }
    }
    static var hymn: Int? { defaults.object(forKey: "uiDebugHymn") == nil ? nil : defaults.integer(forKey: "uiDebugHymn") }
    /// Memorise: plays this many right picks, then one wrong one.
    static var memoryMoves: Int { defaults.integer(forKey: "uiDebugMemoryMoves") }
    /// Shows the page-swipe edge arrow as if dragged this far toward the next
    /// hymn. (Positive: a leading "-" would read as another argument.)
    /// The reader opens scrolled this many points down (the header part-way or collapsed).
    static var scrollY: CGFloat? {
        defaults.object(forKey: "uiDebugScroll") == nil ? nil : CGFloat(defaults.double(forKey: "uiDebugScroll"))
    }
    static var pageDrag: CGFloat? {
        defaults.object(forKey: "uiDebugPageDrag") == nil ? nil : -CGFloat(defaults.double(forKey: "uiDebugPageDrag"))
    }
    static var skipsSplash: Bool { defaults.bool(forKey: "uiDebugNoSplash") }
    /// Playback rate of the splash reveal (0.05 to catch frames). 1 when unset.
    static var splashSpeed: Double {
        let speed = defaults.double(forKey: "uiDebugSplashSpeed")
        return speed > 0 ? speed : 1
    }
    static var plays: Bool { defaults.bool(forKey: "uiDebugPlay") }
    static var digits: String? { defaults.string(forKey: "uiDebugDigits") }
}

/// The App Store screenshots, each a fixed state: Pro (no paywall or free-play
/// prompts), no splash or What's New, Christ In Song 191 "Blessed Assurance"
/// in the default reading style, nothing favourited or recent.
enum ScreenshotState: Int, CaseIterable {
    case reader = 1, player, numberPad, servicePlans, hymnals, appearance, darkReader, church

    static let hymn = 191

    var arguments: [String: Any] {
        var arguments: [String: Any] = [
            "uiDebugPro": true,
            "uiDebugNoSplash": true,
            "uiDebugSurface": self == .darkReader ? "black" : "paper",
            "reader.hymnal": "english",
            "reader.lastHymn": Self.hymn,
            "reader.favourites.v2": [String](),
            "reader.recents": [Int](),
            // Unreadable, so the reading style starts from its defaults.
            "reading.settings.v1": Data(),
        ]
        switch self {
        case .reader, .darkReader: break
        case .player: arguments["uiDebugPlay"] = true
        case .numberPad: arguments["uiDebugDigits"] = "100"
        case .servicePlans: arguments["uiDebugSheet"] = "planner"; arguments["uiDebugSeedPlans"] = "YES"
        case .hymnals: arguments["uiDebugMenu"] = "translation"
        case .appearance: arguments["uiDebugMenu"] = "theme"
        case .church:
            arguments["uiDebugChurch"] = true
            arguments["uiDebugChurchControls"] = true
            // Verse 2, "Perfect submission, perfect delight" (after verse 1 and the chorus).
            arguments["uiDebugChurchBlock"] = 2
        }
        return arguments
    }
}
#endif
