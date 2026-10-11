//
//  LecternPlayer.swift
//  Advent Praise
//
//  The accompaniment transport. It unfolds above the Lectern's row once a
//  hymn starts playing and stays while it is paused: a scrub bar across all
//  the verses, then restart, the verse being played, tempo and loop. Play /
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
            HStack(spacing: DS.Space.s) {
                Button("Restart", systemImage: "backward.end.fill") { player.restart(); Haptics.play(.lightImpact) }
                    .labelStyle(.iconOnly)
                    .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    .accessibilityHint("Plays from the start of verse 1")
                Text(verseLabel)
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)
                tempoMenu
                Toggle("Loop", systemImage: "repeat", isOn: loopBinding)
                    .toggleStyle(.button)
                    .labelStyle(.iconOnly)
                    .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    .accessibilityHint("Starts again from verse 1 after the last verse")
            }
            .font(.body.weight(.semibold))
            .buttonStyle(DSPressStyle())
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.top, DS.Space.xs)
    }

    private var verseLabel: String {
        guard let position = player.position, player.passCount > 0 else { return "" }
        if position.verse == 0 { return String(localized: "Chorus") }
        return String(localized: "Verse \(position.pass) of \(player.passCount)")
    }

    private var tempoMenu: some View {
        Menu {
            Picker("Tempo", selection: tempoBinding) {
                ForEach(PlaybackTempo.allCases) { tempo in
                    Text(tempo.name).tag(tempo)
                }
            }
        } label: {
            Label {
                Text(player.tempo.name)
            } icon: {
                Image(systemName: "metronome")
            }
            .font(DS.Typeface.caption.weight(.semibold))
            .padding(.horizontal, DS.Space.s)
            .frame(minHeight: DS.Size.hitTarget)
            .background(Capsule().fill(Color.primary.opacity(DS.Fill.inset)))
        }
        .accessibilityLabel("Tempo")
        .accessibilityValue(Text(player.tempo.name))
    }

    private var tempoBinding: Binding<PlaybackTempo> {
        Binding(get: { player.tempo }, set: { player.tempo = $0; Haptics.play(.selection) })
    }

    private var loopBinding: Binding<Bool> {
        Binding(get: { player.loops }, set: { player.loops = $0; Haptics.play(.toggle($0)) })
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
