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
//  Nothing here touches AVAudioEngine until the first play(). Building the
//  graph at launch connected the sampler with `format: nil` before any audio
//  session existed; the mixer's hardware format was 0 Hz / 0 channels and
//  AVAudioEngine raised an Objective-C exception, killing the app on launch.
//  Now: claim the session → build the graph with an explicit, validated format
//  → start. Any failure is logged and turns accompaniment off; it never crashes.
//

import AVFoundation
import Observation
import os

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
    /// False once audio setup has failed; the play control hides itself.
    private(set) var isAvailable = true
    /// Fires when the accompaniment reaches the end — playlists use it to advance.
    var onFinish: (() -> Void)?

    /// Built on first play, never at launch.
    @ObservationIgnored private var graph: (engine: AVAudioEngine, sampler: AVAudioUnitSampler)?
    @ObservationIgnored private var sequencer: AVAudioSequencer?
    @ObservationIgnored private var midiURL: URL?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var verseStartSeconds: [TimeInterval] = []

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdventPraise", category: "audio")

    enum EngineError: Error {
        case missingResource(String)
        case invalidOutputFormat
    }

    // MARK: Loading

    /// Picks the hymn to play. Cheap and audio-free: it only resolves the MIDI
    /// file, so opening a hymn never wakes the audio hardware.
    func load(_ hymn: Hymn) throws {
        stop()
        self.hymn = hymn
        sequencer = nil
        midiURL = nil
        duration = 0
        verseStartSeconds = []
        guard let resource = hymn.midiResource,
              let url = Bundle.main.url(forResource: resource, withExtension: "mid") else {
            throw EngineError.missingResource(hymn.midiResource ?? "nil")
        }
        midiURL = url
    }

    // MARK: Transport — play and stop, nothing more

    func play() {
        guard isAvailable, let hymn, let midiURL else { return }
        do {
            try activateSession()
            let (engine, sampler) = try preparedGraph()
            if !engine.isRunning { try engine.start() }
            let seq = try sequencer ?? makeSequencer(url: midiURL, hymn: hymn, engine: engine, sampler: sampler)
            sequencer = seq
            try seq.start()
            isPlaying = true
            startTicker()
        } catch {
            Self.log.error("Accompaniment disabled: \(String(describing: error), privacy: .public)")
            teardown()
            isAvailable = false
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

    // MARK: Setup (first play only)

    /// The audio session is only claimed when something actually plays, so
    /// opening the app never interrupts other audio.
    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func preparedGraph() throws -> (AVAudioEngine, AVAudioUnitSampler) {
        if let graph { return graph }
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        // AVAudioEngine reports bad formats by raising an Objective-C exception,
        // which Swift can't catch — so validate before connecting.
        // Stereo at the hardware rate: the sampler renders stereo whatever the
        // route's channel count.
        let rate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
            throw EngineError.invalidOutputFormat
        }
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        loadInstrument(into: sampler)
        engine.prepare()
        graph = (engine, sampler)
        return (engine, sampler)
    }

    /// Bundled Piano.sf2 first, then the system General MIDI bank where the OS
    /// has one; failing both, the sampler's built-in default voice still sounds.
    private func loadInstrument(into sampler: AVAudioUnitSampler) {
        let candidates = [
            Bundle.main.url(forResource: "Piano", withExtension: "sf2"),
            URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            do {
                try sampler.loadSoundBankInstrument(
                    at: url, program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                return
            } catch {
                Self.log.error("Sound bank \(url.lastPathComponent, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }
        Self.log.notice("No sound bank available; using the sampler's default voice")
    }

    private func makeSequencer(url: URL, hymn: Hymn, engine: AVAudioEngine,
                               sampler: AVAudioUnitSampler) throws -> AVAudioSequencer {
        let seq = AVAudioSequencer(audioEngine: engine)
        try seq.load(from: url, options: [])
        seq.tracks.forEach { $0.destinationAudioUnit = sampler }
        seq.prepareToPlay()
        duration = seq.tracks.map(\.lengthInSeconds).max() ?? 0
        verseStartSeconds = hymn.verseStartBeats.map { seq.seconds(forBeats: $0) }
        return seq
    }

    private func teardown() {
        ticker?.cancel()
        sequencer?.stop()
        sequencer = nil
        graph?.engine.stop()
        graph = nil
        isPlaying = false
    }

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
