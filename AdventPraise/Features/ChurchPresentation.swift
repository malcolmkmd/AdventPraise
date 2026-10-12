//
//  ChurchPresentation.swift
//  Advent Praise
//
//  What church mode is showing, shared by the phone and an external screen
//  (AirPlay or a cable). The phone's ChurchModeView moves the verse; the
//  external screen's ExternalHymnView follows it. Lives in AppServices so
//  both scenes see one value.
//

import Observation
import SwiftUI

@Observable
@MainActor
final class ChurchPresentation {
    /// Church mode is open on the phone.
    var isActive = false
    /// The block of `hymn.sungSequence` being sung.
    var index = 0
    /// An external screen is connected and drawing the hymn.
    var isExternalScreenConnected = false
}
