//
//  SplashView.swift
//  Advent Praise
//
//  Picks up from the launch screen (LaunchBackground + LaunchLogo, centred in
//  the full screen at 160 pt) and reveals the app through the mark: the ring
//  dips a little, then grows past the screen's corners, its inside a window
//  onto the app (the Twitter reveal). About a second, critically damped.
//  Reduce Motion: a plain cross-fade.
//
//  Layers are the template PDFs from Tools/make_splash_logo.swift, tinted
//  here with the DS tokens. Keep `Palette` in step with LaunchLogo and
//  LaunchBackground or the hand-off from the launch screen will flash.
//

import SwiftUI

/// Where the launch splash is. What's New waits for `.finished`.
enum SplashPhase: Sendable {
    /// No splash in this tree (previews, debug skip): nothing to wait for.
    case none
    case showing
    case finished
}

extension EnvironmentValues {
    @Entry var splashPhase: SplashPhase = .none
}

extension View {
    /// Covers the view with the splash once, when the window first appears.
    func splashReveal() -> some View {
        modifier(SplashReveal())
    }
}

private struct SplashReveal: ViewModifier {
    @State private var phase: SplashPhase = SplashTiming.skips ? .none : .showing
    /// The app settles from slightly enlarged as the window opens.
    @State private var contentScale: CGFloat = SplashTiming.skips ? 1 : SplashView.contentStartScale

    func body(content: Content) -> some View {
        content
            .scaleEffect(contentScale)
            .environment(\.splashPhase, phase)
            .overlay {
                if phase == .showing {
                    SplashView(contentScale: $contentScale) { phase = .finished }
                }
            }
    }
}

struct SplashView: View {
    static let markSize: CGFloat = 160
    /// Ring stroke on the 160-pt canvas (Tools/make_splash_logo.swift).
    static let ringWidth: CGFloat = 5
    static let contentStartScale: CGFloat = 1.06

    @Binding var contentScale: CGFloat
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    /// The disc behind the letters and the letters themselves; fading them is
    /// what opens the window.
    @State private var markOpacity: Double = 1
    @State private var opacity: Double = 1

    private var palette: Palette { colorScheme == .dark ? .dark : .light }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RevealHole(diameter: Self.markSize * scale)
                    .fill(palette.background, style: FillStyle(eoFill: true))
                ZStack {
                    Circle().fill(palette.background).opacity(markOpacity)
                    Image(.splashRing).resizable().foregroundStyle(palette.ring)
                    Image(.splashMonogram).resizable().foregroundStyle(palette.monogram).opacity(markOpacity)
                }
                .frame(width: Self.markSize, height: Self.markSize)
                .scaleEffect(scale)
            }
            .frame(width: size.width, height: size.height)
            .task { await reveal(in: size) }
        }
        .ignoresSafeArea()
        .opacity(opacity)
        .accessibilityHidden(true)
    }

    /// Big enough that the ring's inner edge clears the screen's corners.
    private func coverScale(for size: CGSize) -> CGFloat {
        let halfDiagonal = hypot(size.width, size.height) / 2
        return halfDiagonal / (Self.markSize / 2 - Self.ringWidth) * 1.08
    }

    private func reveal(in size: CGSize) async {
        let timing = SplashTiming.self
        if reduceMotion {
            try? await Task.sleep(for: timing.seconds(0.3))
            contentScale = 1
            withAnimation(timing.animation(.easeInOut(duration: 0.4))) { opacity = 0 } completion: { onFinished() }
            return
        }
        // Hold the launch frame a beat, so the hand-off isn't felt.
        try? await Task.sleep(for: timing.seconds(0.15))
        withAnimation(timing.animation(.spring(duration: 0.3, bounce: 0))) { scale = 0.88 }
        try? await Task.sleep(for: timing.seconds(0.2))
        withAnimation(timing.animation(.easeOut(duration: 0.22))) { markOpacity = 0 }
        withAnimation(timing.animation(.spring(duration: 0.75, bounce: 0))) {
            scale = coverScale(for: size)
            contentScale = 1
        } completion: {
            onFinished()
        }
    }
}

extension SplashView {
    /// The DS tokens on the brand ground: light is the app icon (gold ring,
    /// paper letters on evergreen); dark is gold and evergreen on the Stage.
    struct Palette {
        let background: Color
        let ring: Color
        let monogram: Color

        static let light = Palette(background: DS.Palette.evergreen, ring: DS.Palette.brassOnDark,
                                   monogram: DSSurface.paper.background)
        static let dark = Palette(background: DS.Palette.stage, ring: DS.Palette.brassOnDark,
                                  monogram: DS.Palette.evergreenOnDark)
    }
}

/// The screen with a round hole in the middle, filled even-odd.
private struct RevealHole: Shape {
    var diameter: CGFloat

    var animatableData: CGFloat {
        get { diameter }
        set { diameter = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2,
                                   width: diameter, height: diameter))
        return path
    }
}

/// Debug launch arguments slow the splash down or skip it (see DebugLaunch).
private enum SplashTiming {
    static var skips: Bool {
        #if DEBUG
        DebugLaunch.skipsSplash
        #else
        false
        #endif
    }

    static var speed: Double {
        #if DEBUG
        DebugLaunch.splashSpeed
        #else
        1
        #endif
    }

    static func seconds(_ value: Double) -> Duration { .seconds(value / speed) }
    static func animation(_ animation: Animation) -> Animation { animation.speed(speed) }
}

#Preview("Splash") {
    DSPreviewBackdrop()
        .dsSurface(.paper)
        .splashReveal()
}
