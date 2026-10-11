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
//    -whatsNew.lastSeenVersion 7.0  skips What's New (plain UserDefaults)
//

#if DEBUG
import Foundation

enum DebugLaunch {
    private static var defaults: UserDefaults { .standard }

    static var surface: DSSurface? { defaults.string(forKey: "uiDebugSurface").flatMap(DSSurface.init) }
    static var sheet: ExtraSheet? { defaults.string(forKey: "uiDebugSheet").flatMap(ExtraSheet.init) }
    static var showsTranslations: Bool { defaults.bool(forKey: "uiDebugTranslations") }
}
#endif
