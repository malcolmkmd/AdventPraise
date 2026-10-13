//
//  DebugLaunch.swift
//  Advent Praise
//
//  DEBUG builds only: launch arguments that open a screen straight away, so
//  simulator screenshots can be taken without tapping through the app.
//
//    -uiDebugSurface sepia        reading surface (paper, parchment, sepia, muted, black)
//    -uiDebugSheet memory         a Tools sheet (about, pitch, memory, …)
//    -uiDebugCollection gospel    a collection's hymns (with -uiDebugSheet collections)
//    -uiDebugTranslations YES     the reader menu, on Translation
//    -uiDebugMenu theme           the reader menu (translation, theme, text, about; "bar": no panel)
//    -uiDebugMotionSpeed 0.05     the Lectern and reader menu springs slowed down, for screenshots
//    -uiDebugMore YES             the More drawer
//    -uiDebugFeatureBoard YES     Vote on features (needs a board; -featureBoard.disclosedAt 0 skips the notice)
//    -uiDebugFree YES             Pro locked (player and AirPlay show the paywall)
//    -uiDebugPaywall YES          the Pro paywall (YES/player, airplay, or support: opened from More)
//    -uiDebugTipThanks YES        the tip thank-you sheet (with -uiDebugPaywall)
//    -uiDebugChurch YES           church mode
//    -uiDebugExternal verse       the external screen's view on the phone (verse 2, or "title")
//    -uiDebugCentered YES        centered text alignment
//    -uiDebugHymn 412             opens this hymn number
//    -uiDebugQueue 12,30,45       runs these numbers as a service plan
//    -uiDebugChurchPad YES        church mode's number pad (with -uiDebugChurch)
//    -uiDebugChurchTranslations YES  church mode's translation switcher (with -uiDebugChurch)
//    -uiDebugChurchControls YES  church mode's controls never auto-hide
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
//

#if DEBUG
import Foundation

enum DebugLaunch {
    private static var defaults: UserDefaults { .standard }

    static var surface: DSSurface? { defaults.string(forKey: "uiDebugSurface").flatMap(DSSurface.init) }
    static var sheet: ExtraSheet? { defaults.string(forKey: "uiDebugSheet").flatMap(ExtraSheet.init) }
    /// A collection id, e.g. "gospel": opened inside the Collections sheet.
    static var collection: String? { defaults.string(forKey: "uiDebugCollection") }
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
    static var showsFeatureBoard: Bool { defaults.bool(forKey: "uiDebugFeatureBoard") }
    /// Pro locked, as for a free user (only matters without a RevenueCat key).
    static var free: Bool { defaults.bool(forKey: "uiDebugFree") }
    static var showsChurch: Bool { defaults.bool(forKey: "uiDebugChurch") }
    /// "verse" or "title": the external screen's view, drawn on the phone.
    static var external: String? { defaults.string(forKey: "uiDebugExternal") }
    /// The paywall, leading with this feature. "YES" is the player.
    static var paywall: ProFeature? {
        switch defaults.string(forKey: "uiDebugPaywall")?.lowercased() {
        case "yes", "1", "true", "player": .player
        case "airplay": .airPlay
        case "support": .support
        default: nil
        }
    }
    static var showsTipThanks: Bool { defaults.bool(forKey: "uiDebugTipThanks") }
    static var centered: Bool { defaults.bool(forKey: "uiDebugCentered") }
    static var queue: [Int]? {
        defaults.string(forKey: "uiDebugQueue").map { $0.split(separator: ",").compactMap { Int($0) } }
    }
    static var showsChurchPad: Bool { defaults.bool(forKey: "uiDebugChurchPad") }
    static var showsChurchTranslations: Bool { defaults.bool(forKey: "uiDebugChurchTranslations") }
    /// Church mode's controls stay up, for screenshots.
    static var keepsChurchControls: Bool { defaults.bool(forKey: "uiDebugChurchControls") }
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
}
#endif
