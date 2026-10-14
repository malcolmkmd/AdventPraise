//
//  AirPlayButton.swift
//  Advent Praise 7 — Vesper design system
//
//  Worship mode's AirPlay control: the system route picker (AVRoutePickerView,
//  video devices first) inside a worship-sized circle. The picker only routes
//  media: picking a TV sends the accompaniment's SOUND there, it does not
//  start Screen Mirroring, so iOS never connects an external display and
//  the external display scene never appears. So church mode also plays the
//  worship display as a looping silent AirPlay video (AirPlayLyrics.swift),
//  which is what the TV shows when it's picked here.
//  The glyph turns tint while a route is active.
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
            .accessibilityHint("Shows the words on an AirPlay TV and plays the accompaniment there")
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

