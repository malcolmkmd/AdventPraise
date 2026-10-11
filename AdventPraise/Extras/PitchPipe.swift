//
//  PitchPipe.swift
//  Advent Praise
//
//  Sounds a hymn's starting note so a song leader can pitch it. A soft sine
//  tone rendered by AVAudioSourceNode in its own AVAudioEngine, so it never
//  touches the MIDI accompaniment graph.
//
//  Data: Resources/Extras/pitch_notes.json (ships empty), e.g.
//
//      "english": { "12": { "key": "F major", "note": "C4" } }
//
//  When a hymn has no entry the singer picks a note, and that choice is
//  remembered per hymn on this device.
//

import AVFoundation
import Observation
import os

// MARK: - Notes

struct StartingNote: Decodable, Hashable, Sendable {
    /// The hymn's key as printed, e.g. "F major".
    var key: String?
    /// Scientific pitch name of the first sung note, e.g. "C4", "F#4", "Bb3".
    var note: String?
}

enum Pitch {
    static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// "C4" → 60, "F#4"/"F♯4" → 66, "Bb3"/"B♭3" → 58.
    static func midi(_ name: String) -> Int? {
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var rest = Substring(name.trimmingCharacters(in: .whitespaces))
        guard let letter = rest.first.flatMap({ letters[Character($0.uppercased())] }) else { return nil }
        rest = rest.dropFirst()
        var semitone = letter
        while let c = rest.first, "#♯b♭".contains(c) {
            semitone += (c == "#" || c == "♯") ? 1 : -1
            rest = rest.dropFirst()
        }
        guard let octave = Int(rest) else { return nil }
        return (octave + 1) * 12 + semitone
    }

    static func name(_ midi: Int) -> String { names[((midi % 12) + 12) % 12] + String(midi / 12 - 1) }
    static func frequency(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }
}

enum PitchNotes {
    private static let file: PerHymnFile<StartingNote> = ExtrasBundle.decode("pitch_notes") ?? .empty
    private static let customKey = "pitch.custom.v1"

    static func published(hymnal: String, number: Int) -> StartingNote? { file.entry(hymnal: hymnal, number: number) }

    /// The singer's own choice for this hymn, if any.
    static func custom(hymnal: String, number: Int) -> Int? {
        (UserDefaults.standard.dictionary(forKey: customKey) as? [String: Int])?["\(hymnal)#\(number)"]
    }

    static func setCustom(_ midi: Int?, hymnal: String, number: Int) {
        var all = UserDefaults.standard.dictionary(forKey: customKey) as? [String: Int] ?? [:]
        all["\(hymnal)#\(number)"] = midi
        UserDefaults.standard.set(all, forKey: customKey)
    }
}

// MARK: - Tone

@Observable
@MainActor
final class PitchPipe {
    private(set) var sounding: Int?

    /// Seconds a tap sounds for before fading.
    var duration: Double = 2.5

    private let engine = AVAudioEngine()
    private let voice = ToneVoice()
    private var isConfigured = false
    private var stopper: Task<Void, Never>?

    func play(_ midi: Int) {
        configureIfNeeded()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }
        voice.start(frequency: Pitch.frequency(midi))
        sounding = midi
        stopper?.cancel()
        stopper = Task { [weak self, duration] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopper?.cancel()
        voice.release()
        sounding = nil
        stopper = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))   // let the fade finish
            guard !Task.isCancelled, let self, self.sounding == nil else { return }
            self.engine.pause()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = rate > 0 ? rate : 44_100
        let node = voice.makeNode(sampleRate: sampleRate)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        isConfigured = true
    }
}

/// The render state, shared with the audio thread behind a lock.
final class ToneVoice: Sendable {
    private struct State {
        var frequency = 440.0
        var target = 0.0     // amplitude the envelope moves toward
        var level = 0.0
        var phase = 0.0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func start(frequency: Double) {
        state.withLock {
            $0.frequency = frequency
            $0.target = 0.28
        }
    }

    func release() { state.withLock { $0.target = 0 } }

    /// Built outside the main actor: the render block runs on the audio thread.
    nonisolated func makeNode(sampleRate: Double) -> AVAudioSourceNode {
        let state = self.state
        return AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            state.withLock { s in
                let step = 2 * Double.pi * s.frequency / sampleRate
                let attack = 1 / (0.04 * sampleRate)       // ~40 ms in
                let decay = 1 / (0.25 * sampleRate)        // ~250 ms out
                for frame in 0..<Int(frameCount) {
                    if s.level < s.target { s.level = min(s.target, s.level + attack) }
                    else if s.level > s.target { s.level = max(s.target, s.level - decay) }
                    // A touch of the octave and twelfth gives a reedy, pipe-like tone.
                    let sample = s.level * (sin(s.phase) + 0.18 * sin(2 * s.phase) + 0.08 * sin(3 * s.phase)) / 1.26
                    s.phase += step
                    if s.phase > 2 * Double.pi { s.phase -= 2 * Double.pi }
                    for buffer in buffers {
                        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = Float(sample)
                    }
                }
            }
            return noErr
        }
    }
}
