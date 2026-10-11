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
//    -uiDebugPageDrag 60          the page-swipe arrow, frozen mid-drag
//    -uiDebugMemoryMoves 3        Memorise: 3 right picks, then a wrong one (99: finish)
//    -whatsNew.lastSeenVersion 7.0  skips What's New (plain UserDefaults)
//

#if DEBUG
import Foundation

enum DebugLaunch {
    private static var defaults: UserDefaults { .standard }

    static var surface: DSSurface? { defaults.string(forKey: "uiDebugSurface").flatMap(DSSurface.init) }
    static var sheet: ExtraSheet? { defaults.string(forKey: "uiDebugSheet").flatMap(ExtraSheet.init) }
    static var showsTranslations: Bool { defaults.bool(forKey: "uiDebugTranslations") }
    /// Memorise: plays this many right picks, then one wrong one.
    static var memoryMoves: Int { defaults.integer(forKey: "uiDebugMemoryMoves") }
    /// Shows the page-swipe edge arrow as if dragged this far toward the next
    /// hymn. (Positive: a leading "-" would read as another argument.)
    static var pageDrag: CGFloat? {
        defaults.object(forKey: "uiDebugPageDrag") == nil ? nil : -CGFloat(defaults.double(forKey: "uiDebugPageDrag"))
    }
}
#endif
