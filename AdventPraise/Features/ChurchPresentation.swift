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
import UIKit

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
    /// A message on the big screen, over the blank ground (or the image).
    var announcement: String?
    /// A picture on the big screen, aspect-fit on black; `imageID` keys the
    /// AirPlay video's page.
    var image: UIImage?
    var imageID: String?
    /// Something other than the hymn is up: Clear goes back to blank or lyrics.
    var isShowingSpecial: Bool { announcement != nil || image != nil }

    func clearSpecial() {
        announcement = nil
        image = nil
        imageID = nil
    }

    /// The Live Activity's End button: church mode closes when it can.
    var endRequested = false
}
