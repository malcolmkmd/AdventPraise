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
    /// An external screen is connected. With Pro it has its own worship
    /// display; without, iOS mirrors the phone.
    var isExternalScreenConnected = false
    /// The worship display shows only its ground (between hymns, for a
    /// sermon). Set from the phone; turning a verse shows the words again.
    var isBlanked = false
    /// The Live Activity's End button: church mode closes when it can.
    var endRequested = false
}
