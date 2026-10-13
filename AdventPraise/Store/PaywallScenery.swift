//
//  PaywallScenery.swift
//  Advent Praise
//
//  The Pro paywall's picture: warm gold light rising from the bottom edge
//  that slowly breathes, like light through a church window, with two
//  raised hands in front of it as soft gold-and-green silhouettes. The hands
//  lift into view when the paywall opens and sway a little afterwards. The
//  church logo above the headline glows with the same light.
//
//  Everything is drawn: `PraiseHandShape` is a vector path (no images), the
//  light is gradients. All motion is transforms and opacity on a handful of
//  layers, so it stays smooth. Reduce Motion: no lift and no sway (the hands
//  fade in), and the light only breathes in opacity, slowly.
//

import SwiftUI

// MARK: - Palette

/// The paywall's colours on the current reading surface.
struct PaywallPalette {
    let isDark: Bool
    let ground: Color
    /// The light itself.
    let gold: Color
    /// Text and strokes in gold: dark enough to read on light grounds.
    let brass: Color
    let green: Color

    init(surface: DSSurface) {
        isDark = surface.isDark
        ground = surface.isDark ? DS.Palette.stage : surface.background
        gold = surface.isDark ? Color(dsHex: 0xE2B560) : Color(dsHex: 0xD9A84A)
        brass = surface.brass
        green = surface.tint
    }

    /// Fingertips catch the light; the wrists sit in the green of the ground.
    var handGradient: LinearGradient {
        LinearGradient(colors: isDark ? [gold, gold.opacity(0.92), green.opacity(0.85)]
                                      : [brass.opacity(0.9), brass.opacity(0.7), green.opacity(0.75)],
                       startPoint: .top, endPoint: .bottom)
    }

    var logoGradient: LinearGradient {
        LinearGradient(colors: isDark ? [Color(dsHex: 0xF3D68C), gold, Color(dsHex: 0xB9892F)]
                                      : [Color(dsHex: 0xC89B3C), brass, Color(dsHex: 0x6B4C14)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Hand

/// One raised open hand, palm to the viewer, thumb on the leading side,
/// forearm running off the bottom. Drawn in its rect; the forearm reaches
/// past `rect.maxY` so it can sit on an edge. Flip horizontally for the
/// other hand.
struct PraiseHandShape: Shape {
    /// Width over height of the drawing.
    static let aspectRatio: CGFloat = 0.78

    func path(in rect: CGRect) -> Path {
        // Unit space: x 0…1, y 0…1 (down). Overlaps are unioned into one
        // outline, so a translucent fill shows no seams.
        var hand = Path(roundedRect: CGRect(x: 0.37, y: 0.58, width: 0.27, height: 0.60), cornerRadius: 0.07)
        hand = hand.union(Path(roundedRect: CGRect(x: 0.30, y: 0.37, width: 0.43, height: 0.32), cornerRadius: 0.12))
        for finger in Self.fingers {
            hand = hand.union(finger.path)
        }
        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width, y: rect.height)
        return hand.applying(transform)
    }

    private struct Finger {
        let base: CGPoint
        /// Degrees from straight up; positive leans to the trailing side.
        let angle: Double
        let length: CGFloat
        let width: CGFloat

        var path: Path {
            let capsule = Path(roundedRect: CGRect(x: -width / 2, y: -length - width / 2, width: width, height: length + width),
                               cornerRadius: width / 2)
            let transform = CGAffineTransform(translationX: base.x, y: base.y)
                .rotated(by: angle * .pi / 180)
            return capsule.applying(transform)
        }
    }

    private static let fingers: [Finger] = [
        Finger(base: CGPoint(x: 0.34, y: 0.56), angle: -46, length: 0.25, width: 0.115),   // thumb
        Finger(base: CGPoint(x: 0.39, y: 0.42), angle: -7, length: 0.29, width: 0.105),    // index
        Finger(base: CGPoint(x: 0.50, y: 0.41), angle: -1, length: 0.33, width: 0.105),    // middle
        Finger(base: CGPoint(x: 0.61, y: 0.42), angle: 5, length: 0.30, width: 0.10),      // ring
        Finger(base: CGPoint(x: 0.70, y: 0.46), angle: 12, length: 0.23, width: 0.095),    // little
    ]
}

// MARK: - Light

/// Gold light rising from the bottom edge, breathing. Fills its container;
/// put it behind everything and let it ignore the safe area.
struct PaywallLight: View {
    let palette: PaywallPalette
    /// Lower for a small sheet (the thank-you), where the full light would wash out the text.
    var intensity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        let gold = palette.gold
        let wash = palette.isDark ? 0.36 : 0.30
        ZStack {
            // A steady warm floor.
            LinearGradient(stops: [.init(color: gold.opacity(0), location: 0.42),
                                   .init(color: gold.opacity(wash * intensity), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            // The breathing part: a pool of light at the bottom centre, and
            // two soft columns through it, like window lights on a floor.
            ZStack {
                EllipticalGradient(colors: [gold.opacity((palette.isDark ? 0.55 : 0.42) * intensity), gold.opacity(0)],
                                   center: UnitPoint(x: 0.5, y: 1.04),
                                   startRadiusFraction: 0, endRadiusFraction: 0.72)
                LinearGradient(stops: [.init(color: gold.opacity(0), location: 0.18),
                                       .init(color: gold.opacity(0.16 * intensity), location: 0.36),
                                       .init(color: gold.opacity(0), location: 0.50),
                                       .init(color: gold.opacity(0.16 * intensity), location: 0.64),
                                       .init(color: gold.opacity(0), location: 0.82)],
                               startPoint: .leading, endPoint: .trailing)
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .opacity(breathing ? 1 : 0.62)
            .scaleEffect(x: breathing && !reduceMotion ? 1.06 : 1, y: breathing && !reduceMotion ? 1.1 : 1, anchor: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // One slow breath in, then steady breathing. Reduce Motion: opacity only, slower.
            let period: Double = reduceMotion ? 6.5 : 4.6
            withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) { breathing = true }
        }
    }
}

// MARK: - Hands

/// Two raised hands on the bottom edge. They lift into view when `lifted`
/// turns true and sway gently afterwards.
struct PaywallHands: View {
    let palette: PaywallPalette
    let lifted: Bool
    /// Height of the hands' drawing; the forearms run off the bottom.
    var height: CGFloat = 190
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway = false

    var body: some View {
        let width = height * PraiseHandShape.aspectRatio
        let opacity = palette.isDark ? 0.62 : 0.46
        HStack(alignment: .bottom, spacing: -width * 0.16) {
            hand(width: width, flipped: false, lean: -9, phase: 1)
            hand(width: width, flipped: true, lean: 9, phase: -1)
        }
        // The fingertips soften into the light, so words scrolled over them stay readable.
        .mask {
            LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0),
                                   .init(color: .black, location: 0.5)],
                           startPoint: .top, endPoint: .bottom)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: lifted, initial: true) { _, isLifted in
            guard isLifted, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true).delay(1.1)) { sway = true }
        }
    }

    /// `phase` ±1: the hands sway in opposite directions.
    private func hand(width: CGFloat, flipped: Bool, lean: Double, phase: Double) -> some View {
        let swayAngle = reduceMotion ? 0 : (sway ? 1.6 : -1.6) * phase
        let lift: CGFloat = lifted || reduceMotion ? 0 : height * 0.92
        return PraiseHandShape()
            .fill(palette.handGradient)
            .frame(width: width, height: height)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .rotationEffect(.degrees(lean + swayAngle), anchor: .bottom)
            .offset(y: (sway && !reduceMotion ? -3 : 0) * phase)
            .offset(y: lift)
            .opacity(lifted ? 1 : 0)
            .animation(reduceMotion ? .easeInOut(duration: 0.6)
                                    : .spring(duration: 1.5, bounce: 0.12).delay(flipped ? 0.32 : 0.2), value: lifted)
    }
}

// MARK: - Logo

/// The church logo, lit from below: a gold fill with a soft glow behind it
/// that breathes with the light.
struct PaywallLogo: View {
    let palette: PaywallPalette
    var width: CGFloat = 84
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    var body: some View {
        let height = width / SDALogoShape.aspectRatio
        ZStack {
            SDALogoShape()
                .fill(palette.gold, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
                .blur(radius: width * 0.2)
                .scaleEffect(1.18)
                .opacity((glowing ? 0.9 : 0.45) * (palette.isDark ? 1 : 0.6))
            SDALogoShape()
                .fill(palette.logoGradient, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .accessibilityLabel("Seventh-day Adventist Church logo")
        .onAppear {
            withAnimation(.easeInOut(duration: reduceMotion ? 6.5 : 4.6).repeatForever(autoreverses: true)) { glowing = true }
        }
    }
}

// MARK: - Backdrop

/// Ground, light and hands together, for the paywall and the thank-you.
struct PaywallBackdrop: View {
    let palette: PaywallPalette
    let lifted: Bool
    var handHeight: CGFloat = 190
    var lightIntensity: Double = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.ground
            PaywallLight(palette: palette, intensity: lightIntensity)
            PaywallHands(palette: palette, lifted: lifted, height: handHeight)
                .padding(.bottom, -handHeight * 0.1)
        }
        .clipped()
        .ignoresSafeArea()
    }
}

#Preview("Scenery · dark") {
    PaywallBackdrop(palette: PaywallPalette(surface: .black), lifted: true)
}

#Preview("Scenery · paper") {
    PaywallBackdrop(palette: PaywallPalette(surface: .paper), lifted: true)
}

#Preview("Hand") {
    PraiseHandShape().fill(.primary).frame(width: 156, height: 200).padding()
}
