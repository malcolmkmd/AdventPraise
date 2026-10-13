//
//  LecternPlayer.swift
//  Advent Praise
//
//  The accompaniment transport. It unfolds above the Lectern's row once a
//  hymn starts playing and stays while it is paused: a scrub bar across all
//  the verses, then restart, the verse being played and tempo. Play /
//  pause is the round button in the row itself. Inside the Lectern's glass,
//  so it draws no glass of its own.
//

import SwiftUI

struct LecternPlayerStrip: View {
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            PlayerScrubber()
            // Two matching pills either side of the verse, which stays centred.
            HStack(spacing: DS.Space.s) {
                Button { player.restart(); Haptics.play(.lightImpact) } label: {
                    PlayerPill(title: "Restart", systemImage: "backward.end.fill")
                }
                .accessibilityHint("Plays from the start of verse 1")
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verseLabel)
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .fixedSize()
                tempoButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(DSPressStyle())
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.top, DS.Space.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lectern.transport")
    }

    private var verseLabel: String {
        guard let position = player.position, player.passCount > 0 else { return "" }
        if position.verse == 0 { return String(localized: "Chorus") }
        return String(localized: "Verse \(position.pass) of \(player.passCount)")
    }

    /// Tapping steps through slow, medium and fast. A Button, not a Menu: a
    /// Menu's UIKit tap competes with the Lectern's swipe and often missed.
    private var tempoButton: some View {
        Button { step(1) } label: {
            PlayerPill(title: player.tempo.name, systemImage: "metronome")
        }
        .accessibilityLabel("Tempo")
        .accessibilityValue(Text(player.tempo.name))
        .accessibilityHint("Changes to the next tempo")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func step(_ offset: Int) {
        let all = PlaybackTempo.allCases
        guard let index = all.firstIndex(of: player.tempo) else { return }
        player.tempo = all[(index + offset + all.count) % all.count]
        Haptics.play(.selection)
    }
}

/// A transport control's label: icon and word in a quiet capsule, 44 pt tall
/// and at least 44 pt wide. The frame and content shape are inside the label:
/// a frame outside a Button doesn't widen what it hits.
private struct PlayerPill: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            Text(title).contentTransition(.interpolate)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(DS.Typeface.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, DS.Space.m)
        .frame(minWidth: DS.Size.hitTarget, minHeight: DS.Size.hitTarget)
        .background(Capsule().fill(Color.primary.opacity(DS.Fill.inset)))
        .contentShape(Capsule())
    }
}

/// The scrub bar, with elapsed and total time (at the chosen tempo). Its own
/// view: it is the only thing that redraws as the music moves.
private struct PlayerScrubber: View {
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(\.dsSurface) private var surface
    /// The thumb's position while dragging; the engine seeks on release.
    @State private var dragging: TimeInterval?
    @State private var isEditing = false

    var body: some View {
        let rate = Double(player.tempo.rate)
        let shown = dragging ?? player.elapsed
        HStack(spacing: DS.Space.s) {
            Text(Self.clock(shown / rate))
                .frame(minWidth: 36, alignment: .leading)
            // Dragging moves the thumb and seeks on release; VoiceOver's
            // adjustments arrive without editing and seek straight away.
            Slider(value: Binding(get: { shown }, set: { isEditing ? (dragging = $0) : player.seek(to: $0) }),
                   in: 0...max(player.duration, 1)) { editing in
                isEditing = editing
                if !editing, let dragging {
                    player.seek(to: dragging)
                    self.dragging = nil
                }
            }
            .tint(surface.tint)
            .accessibilityLabel("Position")
            .accessibilityValue("\(Self.clock(shown / rate)) of \(Self.clock(player.displayDuration))")
            Text(Self.clock(player.displayDuration))
                .frame(minWidth: 36, alignment: .trailing)
        }
        .font(DS.Typeface.caption.monospacedDigit())
        .foregroundStyle(surface.secondary)
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(seconds, 0).rounded()).formatted(.time(pattern: .minuteSecond))
    }
}
