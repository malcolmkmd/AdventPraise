//
//  PaywallScenery.swift
//  Advent Praise
//
//  The Pro paywall's picture: warm gold light rising from the bottom edge
//  that slowly breathes, like light through a church window, with a crowd
//  of raised hands across the whole bottom in front of it, gold-and-green
//  silhouettes like a congregation seen from the platform. The front row is
//  large and bright; the two rows behind are smaller, fainter, greener and
//  set a little higher. Every hand lifts into view on its own beat when the
//  paywall opens and sways at its own pace afterwards. The church logo
//  above the headline glows with the same light.
//
//  Everything is drawn: `PraiseHandShape` is a vector path (no images), the
//  light is gradients. The crowd is laid out from the width it is given
//  (more hands on iPad) by a fixed hash, so it looks the same every time.
//  All motion is transforms and opacity on separate layers driven by Core
//  Animation, nothing per frame in SwiftUI, so it stays at 60 fps. Reduce
//  Motion: no lift and no sway (the hands fade in), and the light only
//  breathes in opacity, slowly.
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

    /// Fingertips catch the light; the wrists sit in the green of the
    /// ground. Rows further back (`depth` 1 and 2) keep less of the gold.
    func handGradient(depth: Int) -> LinearGradient {
        let colors: [Color] = switch (isDark, depth) {
        case (true, 0): [gold, gold.opacity(0.92), green.opacity(0.85)]
        case (true, 1): [gold.opacity(0.9), green.opacity(0.9), green]
        case (true, _): [gold.opacity(0.7), green.opacity(0.95), green]
        case (false, 0): [brass.opacity(0.9), brass.opacity(0.7), green.opacity(0.75)]
        case (false, 1): [brass.opacity(0.8), green.opacity(0.8), green.opacity(0.9)]
        case (false, _): [brass.opacity(0.6), green.opacity(0.85), green.opacity(0.95)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
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

// MARK: - Crowd

/// Where one hand in the crowd stands and how it moves. Built once from
/// the width by `PraiseCrowd.layout`, with a fixed hash for the variety,
/// so the crowd is the same on every opening.
struct CrowdHandSpec: Identifiable {
    let id: String
    /// 0 is the front row; 1 and 2 stand behind it.
    let depth: Int
    /// Centre, from the leading edge.
    let x: CGFloat
    /// How far above the bottom edge the wrist sits.
    let baseline: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// Thumb on the trailing side.
    let flipped: Bool
    /// Degrees from upright, as the hand rests.
    let lean: Double
    /// Against the row's own opacity, so back rows fade.
    let opacity: Double
    /// Seconds after `lifted` before this hand rises.
    let liftDelay: Double
    /// Half the sway, in degrees, and the time of one swing each way.
    let swayAmplitude: Double
    let swayPeriod: Double
    let swayDelay: Double
    /// Points of rise and fall with the sway.
    let bob: CGFloat
}

enum PraiseCrowd {
    /// Each row, front to back: hand height against the front row's,
    /// how far the wrists sit above the bottom edge (of the front height),
    /// spacing between hands (of a hand's width), and the row's opacity.
    private static let rows: [(scale: CGFloat, rise: CGFloat, spacing: CGFloat, opacity: Double)] = [
        (1.00, 0.00, 0.80, 1.00),
        (0.74, 0.26, 0.82, 0.62),
        (0.52, 0.48, 0.84, 0.40),
    ]

    /// How much taller than a front-row hand the crowd stands (the back
    /// rows reach a little above the front fingertips).
    static let heightFactor: CGFloat = 1.3

    /// A fixed, even spread in 0…<1 for hand `index` in row `depth` (the
    /// classic sine hash), so the variety is the same every time.
    private static func noise(_ index: Int, _ depth: Int, _ salt: Int) -> Double {
        let x = sin(Double(index) * 12.9898 + Double(depth) * 78.233 + Double(salt) * 37.719) * 43758.5453
        return x - floor(x)
    }

    /// The crowd for a band `width` wide, front row hands `height` tall.
    /// Back rows first, so the front row draws over them.
    static func layout(width: CGFloat, height: CGFloat) -> [CrowdHandSpec] {
        var specs: [CrowdHandSpec] = []
        for (depth, row) in rows.enumerated().reversed() {
            let rowHeight = height * row.scale
            let rowWidth = rowHeight * PraiseHandShape.aspectRatio
            let spacing = rowWidth * row.spacing
            // Rows behind are offset by half a step so they show between the hands in front.
            let start = -spacing * 0.2 + (depth % 2 == 1 ? spacing * 0.5 : 0)
            let count = Int(ceil((width + spacing * 0.4) / spacing)) + 1
            for index in 0..<count {
                let sizeVariation = 1 + (noise(index, depth, 1) - 0.5) * 0.26
                let handHeight = rowHeight * sizeVariation
                let x = start + (CGFloat(index) + 0.5) * spacing + CGFloat(noise(index, depth, 2) - 0.5) * spacing * 0.36
                let leanSign: Double = noise(index, depth, 3) < 0.5 ? -1 : 1
                specs.append(CrowdHandSpec(
                    id: "\(depth).\(index)",
                    depth: depth,
                    x: x,
                    baseline: height * row.rise + CGFloat(noise(index, depth, 4) - 0.5) * height * 0.08,
                    width: handHeight * PraiseHandShape.aspectRatio,
                    height: handHeight,
                    flipped: noise(index, depth, 5) < 0.5,
                    lean: leanSign * (4 + noise(index, depth, 6) * 10),
                    opacity: row.opacity * (0.88 + noise(index, depth, 7) * 0.12),
                    liftDelay: 0.12 + Double(depth) * 0.14 + noise(index, depth, 8) * 0.34,
                    swayAmplitude: 1.1 + noise(index, depth, 9) * 1.2,
                    swayPeriod: 2.9 + noise(index, depth, 10) * 1.5,
                    swayDelay: 0.9 + noise(index, depth, 11) * 1.8,
                    bob: 1.5 + CGFloat(noise(index, depth, 12)) * 2.5))
            }
        }
        return specs
    }
}

/// The crowd of raised hands across the bottom edge. They lift into view
/// when `lifted` turns true, each on its own beat, and sway gently and
/// independently afterwards.
struct PaywallHands: View {
    let palette: PaywallPalette
    let lifted: Bool
    /// Height of a front-row hand; the forearms run off the bottom.
    var height: CGFloat = 190
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let opacity = palette.isDark ? 0.62 : 0.46
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                ForEach(PraiseCrowd.layout(width: geometry.size.width, height: height)) { spec in
                    CrowdHand(spec: spec, palette: palette, lifted: lifted, reduceMotion: reduceMotion)
                        .offset(x: spec.x - spec.width / 2, y: -spec.baseline)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomLeading)
        }
        .frame(height: height * PraiseCrowd.heightFactor)
        // The fingertips soften into the light, so words scrolled over them stay readable.
        .mask {
            LinearGradient(stops: [.init(color: .black.opacity(0.12), location: 0),
                                   .init(color: .black.opacity(0.5), location: 0.3),
                                   .init(color: .black, location: 0.62)],
                           startPoint: .top, endPoint: .bottom)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One hand in the crowd: it carries its own sway, so every hand keeps its
/// own time.
private struct CrowdHand: View {
    let spec: CrowdHandSpec
    let palette: PaywallPalette
    let lifted: Bool
    let reduceMotion: Bool
    @State private var sway = false

    var body: some View {
        let swayAngle = reduceMotion ? 0 : (sway ? 1 : -1) * spec.swayAmplitude
        let lift: CGFloat = lifted || reduceMotion ? 0 : spec.height * 0.95
        PraiseHandShape()
            .fill(palette.handGradient(depth: spec.depth))
            .frame(width: spec.width, height: spec.height)
            .scaleEffect(x: spec.flipped ? -1 : 1, y: 1)
            .rotationEffect(.degrees(spec.lean + swayAngle), anchor: .bottom)
            .offset(y: sway && !reduceMotion ? -spec.bob : 0)
            .opacity(spec.opacity)
            .offset(y: lift)
            .opacity(lifted ? 1 : 0)
            .animation(reduceMotion ? .easeInOut(duration: 0.6).delay(spec.liftDelay * 0.4)
                                    : .spring(duration: 1.5, bounce: 0.12).delay(spec.liftDelay), value: lifted)
            .onChange(of: lifted, initial: true) { _, isLifted in
                guard isLifted, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: spec.swayPeriod).repeatForever(autoreverses: true).delay(spec.swayDelay)) {
                    sway = true
                }
            }
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

/// Ground, light and the crowd together, for the paywall and the thank-you.
struct PaywallBackdrop: View {
    let palette: PaywallPalette
    let lifted: Bool
    /// Height of a front-row hand.
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
