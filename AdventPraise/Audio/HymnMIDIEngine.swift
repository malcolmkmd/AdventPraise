//
//  HymnMIDIEngine.swift
//  Advent Praise
//
//  Minimal native MIDI accompaniment: play / stop, and "which verse is
//  sounding" so the reader can follow along. Built on AVAudioEngine +
//  AVAudioSequencer + AVAudioUnitSampler (a bundled SoundFont piano).
//
//  Graph:  AVAudioSequencer ─▶ AVAudioUnitSampler ─▶ mainMixerNode ─▶ output
//
//  7.0 ships no MIDI files: the engine stays wired so accompaniment can return
//  by adding `<hymnal>-<number>.mid` + Piano.sf2 to the bundle, and the play
//  control only appears for hymns that have a file.
//

import AVFoundation
import Observation

// MARK: - Engine

@Observable
@MainActor
final class HymnMIDIEngine {

    private(set) var hymn: Hymn?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// 1-based verse currently sounding; nil before the first verse (the intro).
    private(set) var currentVerse: Int?
    /// Fires when the accompaniment reaches the end — playlists use it to advance.
    var onFinish: (() -> Void)?

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var sequencer: AVAudioSequencer?
    private var ticker: Task<Void, Never>?
    private var verseStartSeconds: [TimeInterval] = []
    private var soundFontLoaded = false

    enum EngineError: Error { case missingResource(String) }

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
    }

    /// The audio session is only claimed when something actually plays, so
    /// opening the app never interrupts other audio.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: Loading

    func load(_ hymn: Hymn) throws {
        stop()
        self.hymn = hymn
        guard let resource = hymn.midiResource,
              let url = Bundle.main.url(forResource: resource, withExtension: "mid") else {
            throw EngineError.missingResource(hymn.midiResource ?? "nil")
        }
        if !soundFontLoaded, let sf2 = Bundle.main.url(forResource: "Piano", withExtension: "sf2") {
            try sampler.loadSoundBankInstrument(
                at: sf2, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            soundFontLoaded = true
        }
        let seq = AVAudioSequencer(audioEngine: engine)
        try seq.load(from: url, options: [])
        seq.tracks.forEach { $0.destinationAudioUnit = sampler }
        seq.prepareToPlay()
        sequencer = seq

        duration = seq.tracks.map(\.lengthInSeconds).max() ?? 0
        verseStartSeconds = hymn.verseStartBeats.map { seq.seconds(forBeats: $0) }
        currentTime = 0
        currentVerse = nil
    }

    // MARK: Transport — play and stop, nothing more

    func play() {
        guard let seq = sequencer else { return }
        do {
            activateSession()
            if !engine.isRunning { try engine.start() }
            try seq.start()
            isPlaying = true
            startTicker()
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        ticker?.cancel()
        sequencer?.stop()
        sequencer?.currentPositionInSeconds = 0
        isPlaying = false
        currentTime = 0
        currentVerse = nil
    }

    func toggle() { isPlaying ? stop() : play() }

    // MARK: Private

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, let seq = self.sequencer else { return }
                self.currentTime = seq.currentPositionInSeconds
                let index = self.verseStartSeconds.lastIndex { $0 <= self.currentTime }
                self.currentVerse = index.map { $0 + 1 }
                if !seq.isPlaying || self.currentTime >= self.duration {
                    self.stop()
                    self.onFinish?()
                    return
                }
            }
        }
    }
}
