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
//  is also sent as AirPlay *video*: each slide (ExternalHymnView at
//  1920 × 1080, exactly what a mirrored or cabled screen shows) is rendered to
//  a short silent H.264 clip that loops in an AVPlayer allowing external
//  playback. Turning a verse renders the next slide and swaps the loop.
//  The MIDI keeps playing through the audio session, which follows the same
//  AirPlay route; the clip is muted so nothing doubles.
//
//  With Screen Mirroring or a cable the external display scene takes over
//  (usesExternalPlaybackWhileExternalScreenIsActive = false). Pro only, like
//  the scene: without Pro the AirPlay button is the paywall.
//

import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
final class AirPlayLyricsCaster {
    static let shared = AirPlayLyricsCaster()

    let player: AVQueuePlayer = {
        let player = AVQueuePlayer()
        player.isMuted = true
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .advance
        return player
    }()

    private var looper: AVPlayerLooper?
    private var isRunning = false
    private var currentKey = ""
    private var renderTask: Task<Void, Never>?
    private let folder: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("airplay-lyrics", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Church mode opened with Pro: keep a slide looping, ready for AirPlay.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        follow()
    }

    func stop() {
        isRunning = false
        renderTask?.cancel()
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        currentKey = ""
    }

    /// Re-renders whenever what the worship display shows changes.
    private func follow() {
        guard isRunning else { return }
        let services = AppServices.shared
        let key = withObservationTracking {
            Self.slideKey(services)
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        guard key != currentKey else { return }
        currentKey = key
        renderTask?.cancel()
        renderTask = Task { [weak self] in
            // Let quick taps through several verses settle on one.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, let self, self.isRunning, let image = Self.renderSlide(services) else { return }
            let url = self.folder.appendingPathComponent("\(abs(key.hashValue)).mp4")
            if !FileManager.default.fileExists(atPath: url.path) {
                guard (try? await SlideClipWriter.write(image, to: url)) != nil else { return }
            }
            guard !Task.isCancelled, self.isRunning, self.currentKey == key else { return }
            self.play(url)
        }
    }

    private func play(_ url: URL) {
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        looper?.disableLooping()
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    private static func slideKey(_ s: AppServices) -> String {
        let c = s.church, m = s.reader
        return "\(m.hymnal.id)|\(m.hymn.id)|\(c.index)|\(c.isActive)|\(c.isBlanked)|\(s.settings.worshipPointSize)|\(s.settings.largePrint)"
    }

    private static func renderSlide(_ s: AppServices) -> CGImage? {
        let view = ExternalHymnView(model: s.reader, church: s.church)
            .environment(s.settings)
            .frame(width: 1920, height: 1080)
            .transaction { $0.animation = nil }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1920, height: 1080)
        return renderer.cgImage
    }
}

/// One still image as a 2-second silent H.264 clip (a frame each second).
enum SlideClipWriter {
    enum Failure: Error { case setup, write }

    static func write(_ image: CGImage, to url: URL) async throws {
        let width = 1920, height = 1080
        let tmp = url.deletingPathExtension().appendingPathExtension("tmp.mp4")
        try? FileManager.default.removeItem(at: tmp)
        let writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000,
                                              AVVideoMaxKeyFrameIntervalKey: 1],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw Failure.setup }
        writer.add(input)
        guard writer.startWriting() else { throw Failure.setup }
        writer.startSession(atSourceTime: .zero)

        guard let buffer = pixelBuffer(image, width: width, height: height) else { throw Failure.setup }
        for second in 0...2 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(second), timescale: 1)) else {
                throw Failure.write
            }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 2, timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw Failure.write }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    private static func pixelBuffer(_ image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
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

/// An almost invisible layer for the caster's player, so iOS treats church
/// mode as playing video and offers the TV as a video AirPlay route.
struct AirPlayLyricsLayer: UIViewRepresentable {
    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        (view.layer as? AVPlayerLayer)?.player = AirPlayLyricsCaster.shared.player
        view.isUserInteractionEnabled = false
        view.alpha = 0.01
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}
}
