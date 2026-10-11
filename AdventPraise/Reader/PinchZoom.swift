//
//  PinchZoom.swift
//  Advent Praise
//
//  Pinch-to-zoom state shared by the reader and church mode: the lyric size
//  while fingers are down, clamped to a range, with a limit haptic each time
//  the pinch reaches either end. The view commits `end()` to settings.
//

import SwiftUI

struct PinchZoom {
    /// The size while a pinch is under way; nil otherwise.
    private(set) var liveSize: CGFloat?
    /// From the first pinch movement until just after release, so swipes and
    /// taps made by the same fingers are ignored.
    private(set) var isActive = false
    private var startSize: CGFloat = 0
    private var atLimit = false

    @MainActor
    mutating func update(magnification: CGFloat, from size: CGFloat, in range: ClosedRange<CGFloat>) {
        if liveSize == nil { startSize = size }
        isActive = true
        let raw = startSize * magnification
        let limited = raw < range.lowerBound || raw > range.upperBound
        if limited && !atLimit { Haptics.play(.limit) }
        atLimit = limited
        liveSize = min(max(raw, range.lowerBound), range.upperBound)
    }

    /// The size to keep, if the pinch moved at all.
    mutating func end() -> CGFloat? {
        defer { liveSize = nil; atLimit = false }
        return liveSize
    }

    mutating func settle() { isActive = false }
}
