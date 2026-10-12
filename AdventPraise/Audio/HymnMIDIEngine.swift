//
//  HymnMIDIEngine.swift
//  Advent Praise
//
//  The hymn accompaniment player. Plays a Cyber Hymnal MIDI file (one pass
//  through the tune) once per verse, with the chorus inside each pass when
//  the hymn has one, and reports which verse and line are sounding so the
//  reader can follow along. Play / pause, restart, seek, tempo and loop;
//  lock-screen controls through MPNowPlayingInfoCenter / MPRemoteCommandCenter.
//
//  Graph:  AVAudioSequencer ─▶ AVAudioUnitSampler ─▶ mainMixerNode ─▶ output
//  Sound:  Apple's General MIDI bank (gs_instruments.dls), piano; if the OS
//          has none, the sampler's built-in default voice. No bundled SoundFont.
//
//  Nothing here touches AVAudioEngine or the audio session until the first
//  play(). Building the graph at launch connected the sampler with
//  `format: nil` before any session existed; the mixer's hardware format was
//  0 Hz / 0 channels and AVAudioEngine raised an Objective-C exception, killing
//  the app on launch. Now: claim the session → build the graph with an
//  explicit, validated format → start. Any failure is logged and turns
//  accompaniment off; it never crashes. load() only parses the file
//  (AudioToolbox MusicSequence, no audio hardware) to learn its length.
//

import AVFoundation
import AudioToolbox
import MediaPlayer
import Observation
import os

/// Where the accompaniment is.
struct PlaybackPosition: Equatable, Sendable {
    /// The verse being played, as numbered in the hymn (0 for a chorus-only hymn).
    let verse: Int
    /// 1-based pass through the tune, for "verse 2 of 4".
    let pass: Int
    let isChorus: Bool
    /// Line of the verse or chorus being sung. Estimated: each pass is split
    /// evenly across its lines, which suits the regular metre of hymn tunes.
    let line: Int?
}

enum PlaybackTempo: String, CaseIterable, Identifiable, Sendable {
    case slow, medium, fast

    var id: String { rawValue }
    var rate: Float {
        switch self {
        case .slow: 0.8
        case .medium: 1
        case .fast: 1.2
        }
    }
    var name: LocalizedStringResource {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        }
    }
}

extension Hymn {
    /// One time through the tune: a verse, then the chorus when the hymn has exactly one.
    struct AccompanimentPass: Hashable, Sendable {
        let verse: Int
        let verseLines: Int
        let chorusLines: Int
    }

    /// The tune is played once per verse.
    var accompanimentPasses: [AccompanimentPass] {
        let choruses = blocks.compactMap { block -> [String]? in
            if case let .chorus(lines) = block { lines } else { nil }
        }
        let chorusLines = choruses.count == 1 ? choruses[0].count : 0
        let passes = blocks.compactMap { block -> AccompanimentPass? in
            guard case let .verse(number, lines) = block else { return nil }
            return AccompanimentPass(verse: number, verseLines: lines.count, chorusLines: chorusLines)
        }
        return passes.isEmpty ? [AccompanimentPass(verse: 0, verseLines: 0, chorusLines: chorusLines)] : passes
    }
}

// MARK: - Engine

@Observable
@MainActor
final class HymnMIDIEngine {

    private(set) var hymn: Hymn?
    private(set) var isPlaying = false
    /// Started and not yet stopped or finished (playing or paused part-way):
    /// the reader follows along and the Lectern shows the transport.
    private(set) var isActive = false
    /// Seconds into the whole performance (every verse), at the written tempo.
    private(set) var elapsed: TimeInterval = 0
    /// Length of the whole performance at the written tempo.
    private(set) var duration: TimeInterval = 0
    private(set) var position: PlaybackPosition?
    private(set) var passCount = 0
    /// False once audio setup has failed; the play control hides itself.
    private(set) var isAvailable = true

    var tempo: PlaybackTempo {
        didSet {
            UserDefaults.standard.set(tempo.rawValue, forKey: Keys.tempo)
            sequencer?.rate = tempo.rate
            updateNowPlaying()
            if tempo != oldValue { Analytics.track(.accompanimentTempoChanged(tempo: tempo)) }
        }
    }
    /// Start again from verse 1 after the last verse instead of finishing.
    var loops: Bool {
        didSet {
            UserDefaults.standard.set(loops, forKey: Keys.loops)
            if loops != oldValue { Analytics.track(.settingChanged(.loopAccompaniment, isOn: loops)) }
        }
    }

    /// Fires when the last verse ends (not when looping) — playlists use it to advance.
    @ObservationIgnored var onFinish: (() -> Void)?
    /// Lock screen / headphones "next track".
    @ObservationIgnored var onNextTrack: (() -> Void)?

    /// Wall-clock seconds, which is what people see: performance time ÷ tempo.
    var displayElapsed: TimeInterval { elapsed / Double(tempo.rate) }
    var displayDuration: TimeInterval { duration / Double(tempo.rate) }

    /// Built on first play, never at launch.
    @ObservationIgnored private var graph: (engine: AVAudioEngine, sampler: AVAudioUnitSampler)?
    @ObservationIgnored private var sequencer: AVAudioSequencer?
    @ObservationIgnored private var midiURL: URL?
    @ObservationIgnored private var source = ""
    @ObservationIgnored private var passes: [Hymn.AccompanimentPass] = []
    @ObservationIgnored private var passDuration: TimeInterval = 0
    /// The pass (0-based) and the offset into it; the truth while paused.
    @ObservationIgnored private var pass = 0
    @ObservationIgnored private var passOffset: TimeInterval = 0
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var resumeAfterInterruption = false
    @ObservationIgnored private var systemHooksInstalled = false
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdventPraise", category: "audio")

    private enum Keys {
        static let tempo = "player.tempo"
        static let loops = "player.loops"
    }

    enum EngineError: Error {
        case missingResource(String)
        case unreadableFile(String)
        case invalidOutputFormat
    }

    init() {
        tempo = UserDefaults.standard.string(forKey: Keys.tempo).flatMap(PlaybackTempo.init(rawValue:)) ?? .medium
        loops = UserDefaults.standard.bool(forKey: Keys.loops)
    }

    // MARK: Loading

    /// Picks the hymn to play. Audio-free: it resolves and parses the MIDI
    /// file, so opening a hymn never wakes the audio hardware. Loading the
    /// hymn that is already loaded does nothing, so playback carries on.
    func load(_ hymn: Hymn, source: String) throws {
        if self.hymn == hymn, midiURL != nil { return }
        unload()
        self.hymn = hymn
        self.source = source
        guard let resource = hymn.midiResource,
              let url = Bundle.main.url(forResource: resource, withExtension: "mid") else {
            throw EngineError.missingResource(hymn.midiResource ?? "nil")
        }
        guard let length = Self.sequenceLength(of: url), length > 0 else {
            throw EngineError.unreadableFile(resource)
        }
        midiURL = url
        passes = hymn.accompanimentPasses
        passCount = passes.count
        passDuration = length
        duration = length * Double(passes.count)
    }

    /// Follows the reader: keeps the current hymn if it's the one on screen,
    /// otherwise stops it and loads the new one (or nothing, without a file).
    func cue(_ hymn: Hymn, source: String) {
        guard hymn.hasAccompaniment else {
            if self.hymn != hymn { unload() }
            return
        }
        do { try load(hymn, source: source) } catch {
            Analytics.error(.audio, code: "load_\(Self.code(error))", error)
        }
    }

    /// Loads and plays `hymn`; false if it has no accompaniment.
    @discardableResult
    func start(_ hymn: Hymn, source: String) -> Bool {
        guard hymn.hasAccompaniment, (try? load(hymn, source: source)) != nil else { return false }
        seek(to: 0)
        play()
        return isPlaying
    }

    // MARK: Transport

    func play() {
        guard isAvailable, !isPlaying, let midiURL else { return }
        let resuming = pass > 0 || passOffset > 0
        do {
            try activateSession()
            let (engine, sampler) = try preparedGraph()
            if !engine.isRunning { try engine.start() }
            let seq = try sequencer ?? makeSequencer(url: midiURL, engine: engine, sampler: sampler)
            sequencer = seq
            seq.rate = tempo.rate
            seq.currentPositionInSeconds = passOffset
            try seq.start()
            isPlaying = true
            isActive = true
            installSystemHooks()
            updatePosition()
            startTicker()
            updateNowPlaying()
            if reportsTransport, let hymn {
                Analytics.track(.accompanimentPlayed(number: hymn.id, tempo: tempo, resumed: resuming))
            }
        } catch {
            Analytics.error(.audio, code: "playback_\(Self.code(error))", error)
            teardownGraph()
            isPlaying = false
            isActive = false
            isAvailable = false
            clearNowPlaying()
        }
    }

    /// Holds the place; the transport stays up and the lock screen keeps the hymn.
    func pause() {
        guard isPlaying else { return }
        ticker?.cancel()
        if let seq = sequencer { passOffset = min(seq.currentPositionInSeconds, passDuration) }
        sequencer?.stop()
        silence()
        graph?.engine.pause()
        isPlaying = false
        updatePosition()
        updateNowPlaying()
        if reportsTransport, let hymn {
            let progress = duration > 0 ? Int((elapsed / duration * 100).rounded()) : 0
            Analytics.track(.accompanimentPaused(number: hymn.id, progressPercent: progress))
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    /// False while the engine pauses or resumes itself (finishing, stopping,
    /// interruptions, route and configuration changes), so analytics only
    /// sees play and pause that someone asked for.
    @ObservationIgnored private var reportsTransport = true

    private func quietly(_ body: () -> Void) {
        let was = reportsTransport
        reportsTransport = false
        body()
        reportsTransport = was
    }

    /// A short code for analytics: the case name of our errors, else domain and number.
    private static func code(_ error: any Error) -> String {
        switch error {
        case EngineError.missingResource: return "missing_resource"
        case EngineError.unreadableFile: return "unreadable_file"
        case EngineError.invalidOutputFormat: return "invalid_output_format"
        default:
            let ns = error as NSError
            return "\(ns.domain).\(ns.code)"
        }
    }

    /// Back to the start of verse 1, and playing.
    func restart() {
        seek(to: 0)
        if !isPlaying { play() }
    }

    /// `time` is in performance seconds (0…duration), as the scrub bar uses.
    func seek(to time: TimeInterval) {
        guard passDuration > 0, !passes.isEmpty else { return }
        let clamped = min(max(time, 0), duration)
        pass = min(Int(clamped / passDuration), passes.count - 1)
        passOffset = min(clamped - Double(pass) * passDuration, passDuration)
        if isPlaying, let seq = sequencer {
            silence()
            seq.currentPositionInSeconds = passOffset
        }
        updatePosition()
        updateNowPlaying()
    }

    /// Ends the performance: rewinds, lets the audio session go, clears the lock screen.
    func stop() {
        quietly { pause() }
        resumeAfterInterruption = false
        pass = 0
        passOffset = 0
        isActive = false
        updatePosition()
        releaseAudio()
    }

    private func unload() {
        stop()
        hymn = nil
        midiURL = nil
        sequencer = nil
        passes = []
        passCount = 0
        passDuration = 0
        duration = 0
    }

    // MARK: Following along

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard isPlaying, let seq = sequencer else { return }
        let offset = seq.currentPositionInSeconds
        // The sequencer may also stop by itself at the end of the file.
        if offset >= passDuration || !seq.isPlaying {
            if pass + 1 < passes.count || loops {
                // Next verse (or verse 1 again when looping): the tune from the top.
                pass = pass + 1 < passes.count ? pass + 1 : 0
                seq.currentPositionInSeconds = 0
                if !seq.isPlaying { try? seq.start() }
                passOffset = 0
                updatePosition()
                updateNowPlaying()
                return
            }
            finish()
            return
        }
        passOffset = offset
        updatePosition()
    }

    private func finish() {
        quietly { pause() }
        if let hymn { Analytics.track(.accompanimentCompleted(number: hymn.id, tempo: tempo, verses: passCount)) }
        pass = 0
        passOffset = 0
        isActive = false
        updatePosition()
        onFinish?()
        if !isPlaying { releaseAudio() }
    }

    private func updatePosition() {
        elapsed = Double(pass) * passDuration + passOffset
        let next = currentPosition()
        if next != position { position = next }
    }

    private func currentPosition() -> PlaybackPosition? {
        guard isActive, passes.indices.contains(pass), passDuration > 0 else { return nil }
        let current = passes[pass]
        let lines = current.verseLines + current.chorusLines
        guard lines > 0 else { return PlaybackPosition(verse: current.verse, pass: pass + 1, isChorus: false, line: nil) }
        let fraction = min(max(passOffset / passDuration, 0), 0.9999)
        let index = Int(fraction * Double(lines))
        if index < current.verseLines {
            return PlaybackPosition(verse: current.verse, pass: pass + 1, isChorus: false, line: index)
        }
        return PlaybackPosition(verse: current.verse, pass: pass + 1, isChorus: true, line: index - current.verseLines)
    }

    // MARK: Setup (first play only)

    /// The audio session is only claimed when something actually plays, so
    /// opening the app never interrupts other audio. Not mixable: that's what
    /// gives the hymn the lock screen and the headphone controls.
    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    /// Stops the engine and hands audio back to whatever was playing before.
    private func releaseAudio() {
        guard graph != nil else { clearNowPlaying(); return }
        graph?.engine.stop()
        sequencer = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.log.notice("Audio session didn't deactivate: \(String(describing: error), privacy: .public)")
        }
        clearNowPlaying()
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

    /// Apple's General MIDI bank (piano, program 0) where the OS has one;
    /// otherwise the sampler's built-in default voice still sounds.
    private func loadInstrument(into sampler: AVAudioUnitSampler) {
        let candidates = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Components/CoreAudio.component/gs_instruments.dls",
        ].map(URL.init(fileURLWithPath:))
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            do {
                try sampler.loadSoundBankInstrument(
                    at: url, program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                return
            } catch {
                Analytics.error(.audio, code: "sound_bank_\(Self.code(error))", error)
            }
        }
        Self.log.notice("No system sound bank; using the sampler's default voice")
    }

    private func makeSequencer(url: URL, engine: AVAudioEngine, sampler: AVAudioUnitSampler) throws -> AVAudioSequencer {
        let seq = AVAudioSequencer(audioEngine: engine)
        try seq.load(from: url, options: [])
        seq.tracks.forEach { $0.destinationAudioUnit = sampler }
        seq.prepareToPlay()
        return seq
    }

    /// All notes off on every channel, so a seek or pause leaves nothing ringing.
    private func silence() {
        guard let sampler = graph?.sampler else { return }
        for channel in UInt8(0)..<16 {
            sampler.sendController(123, withValue: 0, onChannel: channel)
            sampler.sendController(120, withValue: 0, onChannel: channel)
        }
    }

    private func teardownGraph() {
        ticker?.cancel()
        sequencer?.stop()
        sequencer = nil
        graph?.engine.stop()
        graph = nil
    }

    /// Rebuilds the graph at the new hardware format, keeping the place.
    private func rebuildGraph(resume: Bool) {
        let wasPlaying = isPlaying
        quietly {
            pause()
            teardownGraph()
            if resume, wasPlaying { play() }
        }
    }

    // MARK: System: interruptions, route changes, lock screen

    /// Installed with the first play, like the rest of the audio stack.
    private func installSystemHooks() {
        guard !systemHooksInstalled else { return }
        systemHooksInstalled = true
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(
                rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated { self?.handleInterruption(type, options: options) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            // Headphones pulled out: pause rather than play out loud.
            guard reason == .oldDeviceUnavailable else { return }
            MainActor.assumeIsolated { self?.quietly { self?.pause() } }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildGraph(resume: false) }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: nil, queue: .main) { [weak self] note in
            let sender = note.object.map { ObjectIdentifier($0 as AnyObject) }
            MainActor.assumeIsolated {
                guard let self, let engine = self.graph?.engine, sender == ObjectIdentifier(engine) else { return }
                self.rebuildGraph(resume: true)
            }
        })
        registerRemoteCommands()
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began?:
            guard isPlaying else { return }
            quietly { pause() }
            resumeAfterInterruption = true
        case .ended?:
            defer { resumeAfterInterruption = false }
            if resumeAfterInterruption, options.contains(.shouldResume) { quietly { play() } }
        default:
            break
        }
    }

    private func registerRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let next = self?.onNextTrack else { return .noActionableNowPlayingItem }
                next()
                return .success
            }
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let wallSeconds = event.positionTime
            MainActor.assumeIsolated {
                guard let self else { return }
                self.seek(to: wallSeconds * Double(self.tempo.rate))
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard isActive, let hymn else { return }
        var verse = ""
        if let position, passCount > 0 {
            verse = String(localized: "Verse \(position.pass) of \(passCount)")
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "\(hymn.id). \(hymn.title)",
            MPMediaItemPropertyArtist: source,
            MPMediaItemPropertyAlbumTitle: verse,
            MPMediaItemPropertyPlaybackDuration: displayDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: displayElapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
    }

    private func clearNowPlaying() {
        guard systemHooksInstalled else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: File

    /// Length of the MIDI file in seconds at its written tempo. Parses the
    /// file with AudioToolbox; touches no audio hardware.
    private static func sequenceLength(of url: URL) -> TimeInterval? {
        var created: MusicSequence?
        guard NewMusicSequence(&created) == noErr, let sequence = created else { return nil }
        defer { DisposeMusicSequence(sequence) }
        guard MusicSequenceFileLoad(sequence, url as CFURL, .midiType, MusicSequenceLoadFlags()) == noErr else { return nil }
        var count: UInt32 = 0
        MusicSequenceGetTrackCount(sequence, &count)
        var beats: MusicTimeStamp = 0
        for index in 0..<count {
            var found: MusicTrack?
            guard MusicSequenceGetIndTrack(sequence, index, &found) == noErr, let track = found else { continue }
            var length: MusicTimeStamp = 0
            var size = UInt32(MemoryLayout<MusicTimeStamp>.size)
            if MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &length, &size) == noErr {
                beats = max(beats, length)
            }
        }
        var seconds: Float64 = 0
        guard MusicSequenceGetSecondsForBeats(sequence, beats, &seconds) == noErr else { return nil }
        return seconds
    }
}
