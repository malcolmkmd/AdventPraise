//
//  ScreenMirroring.swift
//  Advent Praise
//
//  Without Pro, a TV or projector gets no worship display of its own:
//  ExternalDisplay.swift only gives the external screen a window with Pro,
//  so iOS mirrors the phone. Mirroring, recording, iPhone Mirroring on a
//  Mac and broadcasts all show the phone as it is, so while one is on, a
//  free user's screen carries a small Go Pro banner in a bottom corner.
//  It shows in the mirrored picture, never covers or blanks the words, and
//  tapping it on the phone opens the paywall. Pro, or nothing mirrored:
//  no banner.
//
//  Capture comes from `UITraitCollection.sceneCaptureState` (iOS 17; it
//  replaces `UIScreen.isCaptured`), watched on every window scene the app
//  shows. An external display without Pro counts too, before iOS reports
//  the capture.
//

import SwiftUI
import UIKit

@Observable
@MainActor
final class ScreenMirroring {
    /// Window scenes being captured: mirrored, recorded or broadcast.
    private(set) var capturedScenes: Set<ObjectIdentifier> = []
    /// `mirroring_detected` goes once per session (launch).
    @ObservationIgnored private var hasTracked = false
    @ObservationIgnored private let track: (AnalyticsEvent) -> Void

    init(track: @escaping (AnalyticsEvent) -> Void = { Analytics.track($0) }) {
        self.track = track
    }

    var isCaptured: Bool {
        #if DEBUG
        if DebugLaunch.mirroring { return true }
        #endif
        return !capturedScenes.isEmpty
    }

    /// Why the banner shows, or nil when it doesn't: Pro never sees it. An
    /// external display (which, without Pro, iOS mirrors) wins over a capture.
    static func bannerRoute(isPro: Bool, isCaptured: Bool, hasExternalDisplay: Bool) -> MirroringRoute? {
        guard !isPro else { return nil }
        if hasExternalDisplay { return .externalDisplay }
        return isCaptured ? .capture : nil
    }

    /// The banner appeared: `mirroring_detected`, the first time this session.
    func bannerShown(via route: MirroringRoute, inChurchMode: Bool) {
        guard !hasTracked else { return }
        hasTracked = true
        track(.mirroringDetected(via: route, inChurchMode: inChurchMode))
    }

    fileprivate func update(_ scene: UIWindowScene) {
        let id = ObjectIdentifier(scene)
        if scene.traitCollection.sceneCaptureState == .active {
            capturedScenes.insert(id)
        } else {
            capturedScenes.remove(id)
        }
    }
}

// MARK: - Watching the scene

extension View {
    /// Reports this window scene's capture state to `mirroring`. Once per
    /// window, on a view that stays in it (the root).
    func watchesScreenCapture(_ mirroring: ScreenMirroring) -> some View {
        background(CaptureProbe(mirroring: mirroring).allowsHitTesting(false).accessibilityHidden(true))
    }
}

private struct CaptureProbe: UIViewRepresentable {
    let mirroring: ScreenMirroring
    func makeUIView(context: Context) -> CaptureProbeView { CaptureProbeView(mirroring: mirroring) }
    func updateUIView(_ view: CaptureProbeView, context: Context) {}
}

/// Registers on the scene, not on itself: church mode's full-screen cover
/// takes the root out of the window, and the scene's traits still change.
private final class CaptureProbeView: UIView {
    private let mirroring: ScreenMirroring
    private weak var scene: UIWindowScene?

    init(mirroring: ScreenMirroring) {
        self.mirroring = mirroring
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let scene = window?.windowScene, scene !== self.scene else { return }
        self.scene = scene
        mirroring.update(scene)
        scene.registerForTraitChanges([UITraitSceneCaptureState.self]) { [mirroring] (scene: UIWindowScene, _) in
            mirroring.update(scene)
        }
    }
}

// MARK: - Banner

/// The banner while the screen is mirrored and the user isn't Pro, else
/// nothing. Sends `mirroring_detected` and opens the paywall when tapped.
struct MirroringBannerSlot: View {
    let model: ReaderModel
    var inChurchMode = false
    /// Space under the banner, only while it shows.
    var bottomSpacing: CGFloat = 0
    @Environment(ScreenMirroring.self) private var mirroring
    @Environment(PurchaseStore.self) private var store
    @Environment(ChurchPresentation.self) private var church
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var route: MirroringRoute? {
        ScreenMirroring.bannerRoute(isPro: store.isPro, isCaptured: mirroring.isCaptured,
                                    hasExternalDisplay: church.isExternalScreenConnected)
    }

    var body: some View {
        ZStack {
            if route != nil {
                MirroringBanner { model.paywall = .mirroring }
                    .padding(.bottom, bottomSpacing)
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion), value: route)
        .onChange(of: route, initial: true) { _, route in
            if let route { mirroring.bannerShown(via: route, inChurchMode: inChurchMode) }
        }
    }
}

/// Logo, name and one line on a dark capsule: small on the phone, legible
/// across a room on the mirrored screen, and the same on every surface.
struct MirroringBanner: View {
    let action: () -> Void

    private static let logoWidth: CGFloat = 26
    private static let logoGradient = LinearGradient(
        colors: [Color(dsHex: 0xF3D68C), Color(dsHex: 0xE2B560), Color(dsHex: 0xB9892F)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.s) {
                SDALogoShape()
                    .fill(Self.logoGradient, style: FillStyle(eoFill: true))
                    .frame(width: Self.logoWidth, height: Self.logoWidth / SDALogoShape.aspectRatio)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Advent Praise")
                        .font(.footnote.weight(.semibold))
                    Text("Go Pro for a clean worship display")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .lineLimit(1)
            }
            .padding(.leading, DS.Space.s)
            .padding(.trailing, DS.Space.m)
            .padding(.vertical, DS.Space.xs)
            // Opaque: lyrics scrolling under it would muddy it on a TV.
            .background(Capsule().fill(DS.Palette.stageRaised).shadow(color: .black.opacity(0.35), radius: 8, y: 2))
            .overlay(Capsule().strokeBorder(DS.Palette.brassOnDark.opacity(0.4), lineWidth: 1))
            .foregroundStyle(.white)
            .contentShape(Capsule())
        }
        .buttonStyle(DSPressStyle())
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Advent Praise. Go Pro for a clean worship display")
        .accessibilityHint("Your screen is being mirrored. Opens Advent Praise Pro.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Mirroring banner") {
    VStack(spacing: 24) {
        MirroringBanner {}
        MirroringBanner {}.padding().background(Color.white)
    }
    .padding()
    .background(Color.black)
}
