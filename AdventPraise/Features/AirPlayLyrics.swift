//
//  AirPlayLyrics.swift
//  Advent Praise
//
//  Church mode's words on a TV picked from the in-app AirPlay button.
//
//  AVRoutePickerView only routes media; it never starts Screen Mirroring, so
//  picking a TV there gives the app no external display scene and
//  ExternalDisplay.swift has nothing to draw into (the TV just shows its idle
//  "Connected to iPhone" screen while the MIDI plays). So the worship display
//  is also sent as AirPlay *video*: when a hymn opens, every page of it
//  (each verse and chorus of the sung sequence, then the blank ground;
//  ExternalHymnView at 1920 × 1080, exactly what a mirrored or cabled screen
//  shows) is rendered into ONE H.264 video, a short still segment per page
//  (12 s, looped by seeking).
//  Turning a verse only seeks within that one item, so the AirPlay receiver
//  never reloads and never flashes black. A new hymn's video is pre-rendered
//  (next, previous, playlist neighbour) and pre-rolled in an AVQueuePlayer.
//  The MIDI keeps playing through the audio session, which follows the same
//  AirPlay route; the clip is muted so nothing doubles.
//
//  With Screen Mirroring or a cable the external display scene takes over
//  (usesExternalPlaybackWhileExternalScreenIsActive = false). Pro only, like
//  the scene: without Pro the AirPlay button is the paywall.
//

import AVFoundation
import os
import Observation
import SwiftUI
import UIKit

@MainActor
final class AirPlayLyricsCaster {
    static let shared = AirPlayLyricsCaster()
    nonisolated static let log = Logger(subsystem: "com.mDev.Advent-Praise", category: "AirPlayLyrics")

    /// Seconds each page holds before seeking back to its own start. Short,
    /// so a hymn's video encodes in a moment; one key frame per segment.
    nonisolated static let segment: Int64 = 12

    /// A queue so a new hymn's video is pre-rolled behind the current one and
    /// swapped with advanceToNextItem, not a cold replaceCurrentItem.
    let player: AVQueuePlayer = {
        let player = AVQueuePlayer()
        player.isMuted = false   // the video's audio track is silence
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .none
        return player
    }()

    private var isRunning = false
    private var videoKey = ""
    private var pageCount = 0
    private var page = -1
    private var buildTask: Task<Void, Never>?
    private var prerenderTask: Task<Void, Never>?
    /// Finished videos by key (hymnal, hymn, text size), for this session.
    private var cache: [String: (url: URL, pages: Int)] = [:]
    private var loopObserver: Any?
    private var externalObservation: NSKeyValueObservation?
    private var routeObserver: NSObjectProtocol?
    private let folder: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("airplay-lyrics", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Church mode opened with Pro: keep the hymn's video playing, ready for AirPlay.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try session.setActive(true)
        } catch {
            Self.log.error("session: \(String(describing: error), privacy: .public)")
        }
        externalObservation = player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { player, _ in
            Self.log.notice("externalPlaybackActive=\(player.isExternalPlaybackActive, privacy: .public)")
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            let outs = AVAudioSession.sharedInstance().currentRoute.outputs
                .map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
            Self.log.notice("route: \(outs, privacy: .public)")
        }
        Self.log.notice("caster started")
        follow()
    }

    func stop() {
        isRunning = false
        buildTask?.cancel(); buildTask = nil
        prerenderTask?.cancel(); prerenderTask = nil
        clearPlayback()
        externalObservation = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        routeObserver = nil
    }

    private func clearPlayback() {
        player.pause()
        player.removeAllItems()
        if let loopObserver { player.removeTimeObserver(loopObserver) }
        loopObserver = nil
        videoKey = ""; page = -1; pageCount = 0
    }

    /// Follows the phone: a new hymn loads its (usually pre-rendered) video;
    /// a new verse only seeks.
    private func follow() {
        guard isRunning else { return }
        let services = AppServices.shared
        let (key, wanted, external) = withObservationTracking {
            (Self.videoKey(services, hymn: services.reader.hymn), Self.pageIndex(services),
             services.church.isExternalScreenConnected)
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        // Screen Mirroring or a cable: the external display scene shows the
        // words (best quality); the AirPlay video stands down until it's gone.
        if external {
            if player.currentItem != nil || buildTask != nil {
                Self.log.notice("external display connected: AirPlay video off")
                buildTask?.cancel(); buildTask = nil
                clearPlayback()
            }
            return
        }
        if key != videoKey {
            videoKey = key
            page = -1
            if let hit = cache[key] {
                load(hit.url, pages: hit.pages)
            } else {
                let hymn = services.reader.hymn
                buildTask?.cancel()
                buildTask = Task { [weak self] in
                    guard let self, let built = await self.video(for: hymn, key: key) else { return }
                    guard !Task.isCancelled, self.isRunning, self.videoKey == key else { return }
                    self.load(built.url, pages: built.pages)
                }
            }
            prerenderNeighbours(services)
        } else if pageCount > 0, wanted != page {
            show(page: wanted)
        }
    }

    /// Renders (or finds) a hymn's video.
    private func video(for hymn: Hymn, key: String) async -> (url: URL, pages: Int)? {
        if let hit = cache[key] { return hit }
        let started = Date()
        let images = Self.renderPages(AppServices.shared, hymn: hymn)
        let url = folder.appendingPathComponent("\(abs(key.hashValue)).mp4")
        do { try await HymnVideoWriter.write(images, to: url) } catch {
            Self.log.error("video failed: \(String(describing: error), privacy: .public)")
            return nil
        }
        Self.log.notice("video \(hymn.id, privacy: .public): \(images.count) pages in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
        cache[key] = (url, images.count)
        return (url, images.count)
    }

    /// The next hymn (playlist or hymnal order) and the previous one, ready
    /// before they're asked for.
    private func prerenderNeighbours(_ services: AppServices) {
        prerenderTask?.cancel()
        let reader = services.reader
        let current = reader.hymn
        var neighbours: [Hymn] = []
        if let next = reader.upcomingHymn { neighbours.append(next) }
        if let next = reader.hymnal.hymn(after: current.id) { neighbours.append(next) }
        if let previous = reader.hymnal.hymn(after: current.id, offset: -1) { neighbours.append(previous) }
        let currentBuild = buildTask
        prerenderTask = Task { [weak self] in
            await currentBuild?.value   // the hymn on screen first
            try? await Task.sleep(for: .milliseconds(300))
            for hymn in neighbours where hymn.id != current.id {
                guard let self, !Task.isCancelled, self.isRunning else { return }
                let key = Self.videoKey(services, hymn: hymn)
                if self.cache[key] == nil { _ = await self.video(for: hymn, key: key) }
            }
        }
    }

    private func load(_ url: URL, pages: Int) {
        if let loopObserver { player.removeTimeObserver(loopObserver) }
        loopObserver = nil
        pageCount = pages
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        let target = min(max(Self.pageIndex(AppServices.shared), 0), pages - 1)
        // Pre-roll the new item at its page, then hand over in one step.
        item.seek(to: CMTime(value: Int64(target) * Self.segment, timescale: 1),
                  toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
        if player.items().isEmpty {
            player.insert(item, after: nil)
        } else {
            player.insert(item, after: player.items().last)
            player.advanceToNextItem()
            for old in player.items() where old !== item { player.remove(old) }
        }
        page = -1
        show(page: target)
        player.play()
    }

    /// Seeks to the page's segment and keeps playing its still frames; near
    /// the segment's end, seeks back to its start (same item, no reload).
    private func show(page newPage: Int) {
        guard pageCount > 0 else { return }
        let target = min(max(newPage, 0), pageCount - 1)
        page = target
        let start = CMTime(value: Int64(target) * Self.segment, timescale: 1)
        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        if let loopObserver { player.removeTimeObserver(loopObserver) }
        let end = CMTime(value: Int64(target + 1) * Self.segment * 1000 - 600, timescale: 1000)
        loopObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: end)], queue: .main) { [weak self] in
            Task { @MainActor in
                guard let self, self.page == target else { return }
                self.player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        if player.rate == 0, player.currentItem != nil { player.play() }
        Self.log.notice("page \(target, privacy: .public)")
    }

    /// The video depends on the hymn and the text size, not the verse.
    private static func videoKey(_ s: AppServices, hymn: Hymn) -> String {
        "\(s.reader.hymnal.id)|\(hymn.id)|\(s.settings.worshipPointSize)|\(s.settings.largePrint)"
    }

    /// Pages: the sung sequence's blocks, then the blank ground last.
    private static func pageIndex(_ s: AppServices) -> Int {
        let count = s.reader.hymn.sungSequence.count
        if s.church.isBlanked { return count }
        return min(s.church.index, max(count - 1, 0))
    }

    /// Each page drawn by the worship display itself, from a private copy of
    /// the presentation state so a cabled screen never sees it change.
    private static func renderPages(_ s: AppServices, hymn: Hymn) -> [CGImage] {
        let count = hymn.sungSequence.count
        let state = ChurchPresentation()
        state.isActive = true
        var images: [CGImage] = []
        for index in 0...count {
            state.index = min(index, max(count - 1, 0))
            state.isBlanked = index == count
            let view = ExternalHymnView(model: s.reader, church: state, hymnOverride: hymn)
                .environment(s.settings)
                .frame(width: 1920, height: 1080)
                .transaction { $0.animation = nil }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: 1920, height: 1080)
            if let image = renderer.cgImage { images.append(image) }
        }
        return images
    }
}

/// The hymn's pages as one H.264 video, each a still segment of
/// `AirPlayLyricsCaster.segment` seconds (a frame a second, a key frame at
/// every segment start for exact seeks), with a silent AAC track so AirPlay
/// receivers get an ordinary A/V item.
enum HymnVideoWriter {
    enum Failure: Error { case setup, write }

    static func write(_ images: [CGImage], to url: URL) async throws {
        let width = 1920, height = 1080
        let segment = Int(AirPlayLyricsCaster.segment)
        let seconds = segment * images.count
        let tmp = url.deletingPathExtension().appendingPathExtension("tmp.mp4")
        try? FileManager.default.removeItem(at: tmp)
        let writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_000_000,
                                              AVVideoMaxKeyFrameIntervalKey: Int(AirPlayLyricsCaster.segment),
                                              AVVideoAllowFrameReorderingKey: false],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        let sampleRate = 44_100.0
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 64_000,
        ])
        audio.expectsMediaDataInRealTime = false
        guard writer.canAdd(input), writer.canAdd(audio) else { throw Failure.setup }
        writer.add(input)
        writer.add(audio)
        guard writer.startWriting() else { throw Failure.setup }
        writer.startSession(atSourceTime: .zero)

        // Each input pulls its own samples on its own queue (the pattern
        // AVAssetWriter is built for): pushing one input far ahead of the
        // other stalls it forever.
        var frames: [CVPixelBuffer] = []
        for image in images {
            guard let buffer = pixelBuffer(image, width: width, height: height) else { throw Failure.setup }
            frames.append(buffer)
        }
        let rate = Int(sampleRate)
        let sendableFrames = UncheckedBox(frames), sendableAdaptor = UncheckedBox(adaptor)
        let sendableInput = UncheckedBox(input), sendableAudio = UncheckedBox(audio)
        async let videoDone: Bool = withCheckedContinuation { done in
            var second = 0, finished = false
            sendableInput.value.requestMediaDataWhenReady(on: DispatchQueue(label: "airplay.video")) {
                let input = sendableInput.value
                while input.isReadyForMoreMediaData, second < seconds {
                    let ok = sendableAdaptor.value.append(sendableFrames.value[second / segment],
                                                          withPresentationTime: CMTime(value: CMTimeValue(second), timescale: 1))
                    second += 1
                    if !ok { second = seconds + 1 }
                }
                if !finished, second >= seconds {
                    finished = true
                    input.markAsFinished()
                    done.resume(returning: second == seconds)
                }
            }
        }
        async let audioDone: Bool = withCheckedContinuation { done in
            var second = 0, finished = false
            sendableAudio.value.requestMediaDataWhenReady(on: DispatchQueue(label: "airplay.audio")) {
                let audio = sendableAudio.value
                while audio.isReadyForMoreMediaData, second < seconds {
                    let ok = silence(frames: rate, at: second * rate, rate: sampleRate).map { audio.append($0) } ?? false
                    second += 1
                    if !ok { second = seconds + 1 }
                }
                if !finished, second >= seconds {
                    finished = true
                    audio.markAsFinished()
                    done.resume(returning: second == seconds)
                }
            }
        }
        let (videoOK, audioOK) = await (videoDone, audioDone)
        guard videoOK, audioOK else {
            AirPlayLyricsCaster.log.error("append failed: \(String(describing: writer.error), privacy: .public)")
            writer.cancelWriting()
            throw Failure.write
        }
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw Failure.write }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    nonisolated private static func silence(frames: Int, at start: Int, rate: Double) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
                                               mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &format) == noErr, let format else { return nil }
        let bytes = frames * 4
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes,
                                                 blockAllocator: nil, customBlockSource: nil, offsetToData: 0,
                                                 dataLength: bytes, flags: kCMBlockBufferAssureMemoryNowFlag,
                                                 blockBufferOut: &block) == noErr, let block else { return nil }
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
        var sample: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: frames,
            presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(rate)),
            packetDescriptions: nil, sampleBufferOut: &sample) == noErr else { return nil }
        return sample
    }

    nonisolated private static func pixelBuffer(_ image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &buffer)
                == kCVReturnSuccess, let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                        | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

private struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }

/// A full-size layer for the caster's player, behind church mode's words, so iOS treats church
/// mode as playing video and offers the TV as a video AirPlay route.
struct AirPlayLyricsLayer: UIViewRepresentable {
    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        (view.layer as? AVPlayerLayer)?.player = AirPlayLyricsCaster.shared.player
        view.isUserInteractionEnabled = false
        // A real, full-size player behind the words (the lyric covers it).
        (view.layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}
}

/// Church mode's "Show on TV": Screen Mirroring, the best way to put the words
/// on a TV (the external display scene: full quality, instant verse changes).
struct ScreenMirroringHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    Text("For the best picture and instant verse changes, use Screen Mirroring.")
                        .font(.body)
                    step(1, "Open Control Centre (swipe down from the top-right corner).")
                    step(2, "Tap Screen Mirroring.")
                    step(3, "Choose your TV or projector.")
                    step(4, "Come back to Advent Praise. The words fill the TV, and this phone becomes the remote.")
                    Text("A cable to a TV or projector works the same way.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Show on TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.m) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 24)
            Text(text).font(.body)
        }
        .accessibilityElement(children: .combine)
    }
}
