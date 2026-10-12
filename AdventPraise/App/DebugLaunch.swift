//
//  DebugLaunch.swift
//  Advent Praise
//
//  DEBUG builds only: launch arguments that open a screen straight away, so
//  simulator screenshots can be taken without tapping through the app.
//
//    -uiDebugSurface sepia        reading surface (paper, parchment, sepia, muted, black)
//    -uiDebugSheet memory         a Tools sheet (about, pitch, memory, …)
//    -uiDebugTranslations YES     the reader's translation popover
//    -uiDebugMore YES             the More drawer
//    -uiDebugFree YES             Pro locked (player and AirPlay show the paywall)
//    -uiDebugPaywall YES          the Pro paywall
//    -uiDebugChurch YES           church mode
//    -uiDebugExternal verse       the external screen's view on the phone (verse 2, or "title")
//    -uiDebugCentered YES        centered text alignment
//    -uiDebugHymn 412             opens this hymn number
//    -uiDebugQueue 12,30,45       runs these numbers as a service plan
//    -uiDebugChurchPad YES        church mode's number pad (with -uiDebugChurch)
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
    static var showsTranslations: Bool { defaults.bool(forKey: "uiDebugTranslations") }
    static var showsMore: Bool { defaults.bool(forKey: "uiDebugMore") }
    /// Pro locked, as for a free user (only matters without a RevenueCat key).
    static var free: Bool { defaults.bool(forKey: "uiDebugFree") }
    static var showsChurch: Bool { defaults.bool(forKey: "uiDebugChurch") }
    /// "verse" or "title": the external screen's view, drawn on the phone.
    static var external: String? { defaults.string(forKey: "uiDebugExternal") }
    static var showsPaywall: Bool { defaults.bool(forKey: "uiDebugPaywall") }
    static var centered: Bool { defaults.bool(forKey: "uiDebugCentered") }
    static var queue: [Int]? {
        defaults.string(forKey: "uiDebugQueue").map { $0.split(separator: ",").compactMap { Int($0) } }
    }
    static var showsChurchPad: Bool { defaults.bool(forKey: "uiDebugChurchPad") }
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
