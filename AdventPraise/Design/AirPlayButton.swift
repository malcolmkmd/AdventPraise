//
//  AirPlayButton.swift
//  Advent Praise 7 — Vesper design system
//
//  Worship mode's AirPlay control: the system route picker (AVRoutePickerView,
//  video devices first) inside a worship-sized circle. Picking a TV or
//  projector connects it as an external screen, and ExternalHymnView draws
//  the hymn there. The glyph turns tint while a route is active.
//
//  iOS 26: interactive Liquid Glass. Fallback: the opaque raised circle the
//  other worship buttons use, so it stays legible over large lyrics.
//

import AVKit
import SwiftUI

struct AirPlayRouteButton: View {
    let size: CGFloat
    @Environment(\.dsSurface) private var surface

    var body: some View {
        // The picker draws its glyph at its full bounds: a small one shows the
        // glyph (and its active tint), a clear full-size one takes the tap.
        let picker = RoutePicker(tint: UIColor(surface.highContrastForeground), activeTint: UIColor(surface.tint))
            .frame(width: size * 0.42, height: size * 0.42)
            .allowsHitTesting(false)
            .frame(width: size, height: size)
            .overlay { RoutePicker(tint: .clear, activeTint: .clear) }
            .contentShape(Circle())
            .accessibilityLabel("AirPlay")
            .accessibilityHint("Shows the hymn on a TV or projector")
        if #available(iOS 26, *) {
            picker.glassEffect(.regular.interactive(), in: Circle())
        } else {
            picker
                .background(Circle().fill(surface.elevated))
                .overlay(Circle().strokeBorder(surface.highContrastForeground.opacity(0.25), lineWidth: 1))
        }
    }
}

private struct RoutePicker: UIViewRepresentable {
    let tint: UIColor
    let activeTint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = tint
        view.activeTintColor = activeTint
    }
}
