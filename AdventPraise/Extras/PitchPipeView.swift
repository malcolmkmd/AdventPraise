//
//  PitchPipeView.swift
//  Advent Praise
//
//  The pitch pipe sheet: the hymn's starting note (published or the singer's
//  own), one big button to sound it, and a chromatic keyboard to choose.
//

import SwiftUI

struct PitchPipeView: View {
    let hymnal: Hymnal
    let hymn: Hymn
    @State private var pipe = PitchPipe()
    @State private var chosen: Int?
    @State private var octave = 4
    @Environment(\.dsSurface) private var surface

    private var published: StartingNote? { PitchNotes.published(hymnal: hymnal.id, number: hymn.id) }
    private var publishedMIDI: Int? { published?.note.flatMap(Pitch.midi) }
    /// The singer's choice wins over the published note.
    private var note: Int? { chosen ?? publishedMIDI }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                soundButton
                keyboard
                if chosen != nil, publishedMIDI != nil {
                    Button("Use the hymnal’s note") { choose(nil) }
                        .font(DS.Typeface.button)
                        .foregroundStyle(surface.tint)
                        .frame(minHeight: DS.Size.hitTarget)
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Pitch pipe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chosen = PitchNotes.custom(hymnal: hymnal.id, number: hymn.id)
            if let note { octave = note / 12 - 1 }
        }
        .onDisappear { pipe.stop() }
        .analyticsScreen(.pitchPipe)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Hymn \(hymn.id)")
                .dsEyebrow(tracking: 1.2)
                .foregroundStyle(surface.secondary)
            Text(hymn.title)
                .scaledFont(size: 22, weight: .semibold, design: .serif)
                .multilineTextAlignment(.center)
            Group {
                if let key = published?.key, !key.isEmpty {
                    Text("Key of \(key)")
                } else if publishedMIDI == nil {
                    Text("No starting note on file for this hymn. Choose one below and it will be remembered.")
                }
            }
            .scaledFont(size: 14)
            .foregroundStyle(surface.secondary)
            .multilineTextAlignment(.center)
        }
    }

    private var soundButton: some View {
        Button {
            guard let note else { return }
            if pipe.sounding == note { pipe.stop() } else {
                pipe.play(note)
                Analytics.track(.pitchPipeUsed(chosen != nil ? .customNote : .publishedNote))
            }
            Haptics.play(.mediumImpact)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: pipe.sounding == nil ? "tuningfork" : "speaker.wave.2.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .symbolEffect(.variableColor.iterative, isActive: pipe.sounding != nil)
                Text(note.map(Pitch.name) ?? "—")
                    .scaledFont(size: 34, weight: .bold, design: .serif, relativeTo: .largeTitle)
                Text(note == nil ? "Choose a note" : (chosen != nil ? "Your note" : "Starting note"))
                    .scaledFont(size: 12, weight: .semibold).textCase(.uppercase).tracking(1)
            }
            // Solid tint with onTint (≥ 5.6:1). With no note yet it is an
            // outlined, unfilled circle with full-contrast text, not a faded one.
            .foregroundStyle(note == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(surface.onTint))
            .frame(width: 180, height: 180)
            .background(Circle().fill(note == nil ? surface.elevated : surface.tint))
            .overlay(Circle().strokeBorder(note == nil ? surface.controlBorder : .clear, lineWidth: 1.5))
        }
        .buttonStyle(DSPressStyle())
        .disabled(note == nil)
        .accessibilityLabel(note.map { "Sound \(Pitch.name($0))" } ?? "No note chosen")
        .accessibilityHint("Plays the starting note for a few seconds")
    }

    private var keyboard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Choose a note").scaledFont(size: 13, weight: .bold).textCase(.uppercase).tracking(1)
                    .foregroundStyle(surface.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Stepper("Octave \(octave)", value: $octave, in: 2...5)
                    .scaledFont(size: 14)
                    .fixedSize()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<12, id: \.self) { semitone in
                    let midi = (octave + 1) * 12 + semitone
                    Button {
                        choose(midi)
                        pipe.play(midi)
                        Haptics.play(.selection)
                        Analytics.track(.pitchPipeUsed(.keyChosen))
                    } label: {
                        NoteKey(name: Pitch.names[semitone], isSelected: note == midi)
                    }
                    .buttonStyle(DSPressStyle())
                    .accessibilityLabel(Pitch.name(midi))
                    .accessibilityAddTraits(note == midi ? .isSelected : [])
                }
            }
        }
    }

    private func choose(_ midi: Int?) {
        chosen = midi
        PitchNotes.setCustom(midi, hymnal: hymnal.id, number: hymn.id)
    }
}

/// One key of the chromatic keyboard. Selected: solid tint, onTint name.
/// Otherwise: elevated with a 3:1 outline and full-contrast name.
private struct NoteKey: View {
    let name: String
    let isSelected: Bool
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Text(name)
            .scaledFont(size: 18, weight: .semibold, design: .serif)
            .foregroundStyle(isSelected ? AnyShapeStyle(surface.onTint) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle.ds(DS.Radius.key).fill(isSelected ? surface.tint : surface.elevated))
            .overlay(RoundedRectangle.ds(DS.Radius.key)
                .strokeBorder(isSelected ? .clear : surface.controlBorder, lineWidth: 1))
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
            .animation(DS.Motion.select, value: isSelected)
    }
}
