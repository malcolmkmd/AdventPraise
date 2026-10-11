//
//  DesignTokens.swift
//  Advent Praise 7 — Vesper design system
//
//  The single source of truth for colour, type, spacing, radii, motion and
//  glass. Derived from VesperTheme.swift (new-sources) and extended for
//  Dynamic Type, large print, worship mode and accessibility contrast.
//
//  Names are prefixed `DS` so this file can sit beside the prototype's
//  VesperTheme.swift during migration without symbol clashes. When the app
//  adopts the library, delete the palette/glass parts of VesperTheme.swift.
//
//  See design/DESIGN.md for the rules behind every value.
//

import SwiftUI

// MARK: - Namespace

enum DS {}

// MARK: - Palette

extension DS {
    /// Brand colours. Evergreen = navigation, actions, play.
    /// Brass = anything musical (verse numerals, chorus labels, hymn numbers, prices).
    enum Palette {
        static let evergreen       = Color(dsHex: 0x1F7466) // light grounds
        static let evergreenDeep   = Color(dsHex: 0x19604F) // sepia ground (AA on #E6D6B9)
        static let evergreenOnDark = Color(dsHex: 0x5FB8A6) // dark grounds
        static let brass           = Color(dsHex: 0x7F5B1C)
        static let brassDeep       = Color(dsHex: 0x6B4C14) // sepia ground (AA on #E6D6B9)
        static let brassOnDark     = Color(dsHex: 0xD4A853)
        /// What's New / Stage: always dark, regardless of reading surface.
        static let stage           = Color(dsHex: 0x0E1110)
        static let stageRaised     = Color(dsHex: 0x1A1F1D)
        static let destructive     = Color(dsHex: 0xB3261E)
    }

    /// Opacity steps for fills and strokes drawn with `.primary` or a tint.
    /// Never invent new ones in a component.
    enum Fill {
        static let row: Double = 0.05          // list rows, grouped sections
        static let inset: Double = 0.06        // keys, inputs, icon buttons
        static let hairline: Double = 0.08     // key borders, glass fallback stroke (light)
        static let stroke: Double = 0.12       // chips, swatches, glass fallback stroke (dark)
        static let tintActive: Double = 0.10   // the hymn handle while its tray is open
        static let tintSelected: Double = 0.12 // selected chip / card
        static let tintOn: Double = 0.14       // toggled-on tile, current verse badge
        static let highlight: Double = 0.18    // search-match highlight (brass)
        static let dimmed: Double = 0.55       // verses not currently sung
        static let disabled: Double = 0.40
    }
}

// MARK: - Reading surface

/// The ground the lyrics sit on. Every component reads it from the
/// environment (`\.dsSurface`) to pick tint, brass and contrast.
enum DSSurface: String, CaseIterable, Identifiable, Codable, Sendable {
    case paper, parchment, sepia, muted, black

    var id: String { rawValue }

    var name: LocalizedStringKey {
        switch self {
        case .paper: "Paper"
        case .parchment: "Parchment"
        case .sepia: "Sepia"
        case .muted: "Muted"
        case .black: "Black"
        }
    }

    var isDark: Bool { self == .muted || self == .black }
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    var background: Color {
        switch self {
        case .paper: Color(dsHex: 0xF7F4EE)
        case .parchment: Color(dsHex: 0xF3E9D4)
        case .sepia: Color(dsHex: 0xE6D6B9)
        case .muted: Color(dsHex: 0x262A29)
        case .black: .black
        }
    }

    var foreground: Color {
        switch self {
        case .paper: Color(dsHex: 0x1C1F1E)
        case .parchment: Color(dsHex: 0x3B2F1E)
        case .sepia: Color(dsHex: 0x3E2F1D)
        case .muted: Color(dsHex: 0xD9DBD8)
        case .black: Color(dsHex: 0xE8E6E0)
        }
    }

    /// Opaque raised surface. Used instead of material when the person has
    /// Reduce Transparency on (iOS 17–25 path) and for keys on the pad.
    var elevated: Color {
        switch self {
        case .paper: Color(dsHex: 0xFCFBF8)
        case .parchment: Color(dsHex: 0xF9F2E3)
        case .sepia: Color(dsHex: 0xEFE3CC)
        case .muted: Color(dsHex: 0x323736)
        case .black: Color(dsHex: 0x1B1C1B)
        }
    }

    /// Secondary text. Opacity is tuned per surface to keep ≥ 4.5:1
    /// (the prototype's flat 0.62 measured ~3.6:1 on Sepia, ~4.0:1 on Parchment).
    /// Use this, not the hierarchical `.secondary` style, for text.
    var secondary: Color { foreground.opacity(self == .sepia ? 0.78 : 0.72) }

    var tint: Color {
        switch self {
        case .sepia: DS.Palette.evergreenDeep
        case .muted, .black: DS.Palette.evergreenOnDark
        default: DS.Palette.evergreen
        }
    }

    var brass: Color {
        switch self {
        case .sepia: DS.Palette.brassDeep
        case .muted, .black: DS.Palette.brassOnDark
        default: DS.Palette.brass
        }
    }

    /// Foreground for text/icons placed on a solid `tint` fill (play, Go).
    var onTint: Color { isDark ? .black : .white }

    // MARK: High contrast (worship mode, or Increase Contrast)

    /// Worship mode and the system "Increase Contrast" setting collapse every
    /// surface to one of two maximum-contrast grounds.
    var highContrastBackground: Color { isDark ? .black : .white }
    var highContrastForeground: Color { isDark ? Color(dsHex: 0xF4F1EA) : Color(dsHex: 0x0B0C0C) }
}

// MARK: - Spacing (4-pt grid, values taken from the Vesper screens)

extension DS {
    enum Space {
        static let hair: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let s: CGFloat = 8      // between siblings in a row
        static let m: CGFloat = 12     // between groups in a panel
        static let panel: CGFloat = 14 // inner padding of Lectern panels
        static let l: CGFloat = 20     // sheet side margin, Lectern side inset
        static let block: CGFloat = 22 // between verses
        static let gutter: CGFloat = 28 // reader side margin (iPhone)
        static let top: CGFloat = 38   // reader top inset under safe area
        static let chorusIndent: CGFloat = 40
        /// Max line measure for lyrics on iPad / landscape.
        static let readingMeasure: CGFloat = 640
        /// Max width of the floating Lectern on iPad.
        static let lecternMaxWidth: CGFloat = 560
    }

    enum Size {
        static let hitTarget: CGFloat = 44
        static let worshipHitTarget: CGFloat = 72
        static let lecternRow: CGFloat = 64
        static let padKey: CGFloat = 50
        static let row: CGFloat = 52
        static let compactRow: CGFloat = 48
        static let verseBadge: CGFloat = 26
        static let numberTile: CGFloat = 36
        static let swatch: CGFloat = 32
    }
}

// MARK: - Radii (always .continuous)

extension DS {
    enum Radius {
        static let dock: CGFloat = 32     // Lectern collapsed
        static let panel: CGFloat = 30    // Lectern expanded, What's New tiles
        static let capsule: CGFloat = 22
        static let card: CGFloat = 18     // font cards, GlassCard
        static let tile: CGFloat = 16     // tray tiles, inputs, rows, swatches
        static let key: CGFloat = 14      // pad keys, primary buttons
        static let chip: CGFloat = 14
        static let badge: CGFloat = 11    // number tiles
        static let swatch: CGFloat = 9    // hymnal colour square
    }
}

extension RoundedRectangle {
    /// `RoundedRectangle(cornerRadius: r, style: .continuous)` — the only corner style we use.
    static func ds(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Typography

extension DS {
    /// Chrome type. Every style is built on a text style so it follows
    /// Dynamic Type. Serif (New York) for anything that *is* the hymnal —
    /// titles, numbers, lyrics; SF for controls and metadata.
    enum Typeface {
        static let display     = Font.system(.largeTitle, design: .serif, weight: .bold)      // 34
        static let hymnTitle   = Font.system(.title, design: .serif, weight: .semibold)       // 28
        static let sheetTitle  = Font.system(.title2, design: .serif, weight: .semibold)      // 22
        static let panelTitle  = Font.system(.title3, design: .serif, weight: .semibold)      // 20
        static let rowTitle    = Font.system(.callout, design: .serif, weight: .semibold)     // 16
        static let rowBody     = Font.system(.callout, design: .serif)                        // 16
        static let numeral     = Font.system(.headline, design: .serif, weight: .semibold)    // 17
        static let padDigit    = Font.system(.title2, design: .serif, weight: .medium)        // 22
        static let padReadout  = Font.system(.title, design: .serif, weight: .medium)         // 28
        static let label       = Font.system(.subheadline, weight: .semibold)                 // 15
        static let button      = Font.system(.subheadline, weight: .bold)                     // 15
        static let detail      = Font.system(.footnote)                                       // 13
        static let caption     = Font.system(.caption)                                        // 12
        static let eyebrow     = Font.system(.caption2, weight: .bold)                        // 11, uppercase + tracking
    }

    /// Lyric sizes. The person picks a step; Dynamic Type then multiplies it
    /// (see `DSLyricText`). Three scales share one slider.
    enum LyricScale: String, CaseIterable, Identifiable, Codable, Sendable {
        case standard, largePrint, worship

        var id: String { rawValue }

        var name: LocalizedStringKey {
            switch self {
            case .standard: "Standard"
            case .largePrint: "Large print"
            case .worship: "Worship"
            }
        }

        /// Point sizes at the default Dynamic Type setting (Large).
        var steps: [CGFloat] {
            switch self {
            case .standard: [16, 18, 19, 21, 24]
            case .largePrint: [26, 28, 32, 36, 40]
            case .worship: [36, 42, 48, 56, 64]
            }
        }

        var defaultStep: Int { 2 }

        /// Upper bound on the Dynamic Type multiplier. Large print and worship
        /// are already big; uncapped they wrap one word per line on iPhone.
        var dynamicTypeCap: CGFloat {
            switch self {
            case .standard: 2.2
            case .largePrint: 1.5
            case .worship: 1.2
            }
        }

        /// Big type needs proportionally less leading.
        var leadingScale: CGFloat {
            switch self {
            case .standard: 1
            case .largePrint: 0.8
            case .worship: 0.6
            }
        }

        /// How far pinch-to-zoom may take the base size. A little wider than
        /// the slider's steps, so pinching feels free without breaking layout.
        var pinchRange: ClosedRange<CGFloat> {
            switch self {
            case .standard: 14...32
            case .largePrint: 24...48
            case .worship: 30...80
            }
        }
    }

    enum LineSpacing: String, CaseIterable, Identifiable, Codable, Sendable {
        case compact, normal, relaxed
        var id: String { rawValue }
        var name: LocalizedStringKey {
            switch self {
            case .compact: "Compact"
            case .normal: "Normal"
            case .relaxed: "Relaxed"
            }
        }
        /// Extra leading as a fraction of the point size.
        var leading: CGFloat {
            switch self {
            case .compact: 0.18
            case .normal: 0.34
            case .relaxed: 0.55
            }
        }
    }

    enum ReadingFont: String, CaseIterable, Identifiable, Codable, Sendable {
        case serif, sans
        var id: String { rawValue }
        var name: LocalizedStringKey { self == .serif ? "Serif" : "Sans" }
        var detail: LocalizedStringKey { self == .serif ? "New York · for the hymnal" : "San Francisco · clean and plain" }
        var design: Font.Design { self == .serif ? .serif : .default }

        /// The refrain is set in a contrasting family, bold italic, so it reads
        /// as a second voice: a humanist sans against New York, a transitional
        /// serif against SF. Both ship with iOS and have a drawn bold italic.
        var chorusFace: String { self == .serif ? "AvenirNext-BoldItalic" : "Baskerville-BoldItalic" }
        /// Evens out x-height so the chorus doesn't look bigger or smaller than the verses.
        var chorusSizeRatio: CGFloat { self == .serif ? 0.92 : 1.06 }
    }
}

/// Everything the reader's text needs. A value type so components stay
/// previewable; the app's `@Observable` settings object vends one.
struct DSReadingStyle: Equatable, Sendable {
    /// Changing the scale or step drops any pinched size.
    var scale: DS.LyricScale = .standard { didSet { pinchedPointSize = nil } }
    var step: Int = 2 { didSet { pinchedPointSize = nil } }
    var font: DS.ReadingFont = .serif
    var lineSpacing: DS.LineSpacing = .normal
    var centered = false
    /// A size between the steps, set by pinch-to-zoom. nil means "use `step`".
    var pinchedPointSize: CGFloat?

    var basePointSize: CGFloat {
        if let pinchedPointSize {
            return min(max(pinchedPointSize, scale.pinchRange.lowerBound), scale.pinchRange.upperBound)
        }
        let steps = scale.steps
        return steps[min(max(step, 0), steps.count - 1)]
    }

    var isDefaultSize: Bool { pinchedPointSize == nil && step == scale.defaultStep }

    /// Keeps a pinched size; the slider shows the nearest step.
    mutating func pinch(to size: CGFloat) {
        let size = min(max(size, scale.pinchRange.lowerBound), scale.pinchRange.upperBound)
        step = scale.steps.indices.min { abs(scale.steps[$0] - size) < abs(scale.steps[$1] - size) } ?? scale.defaultStep
        pinchedPointSize = size
    }

    mutating func resetSize() { step = scale.defaultStep }
    var alignment: TextAlignment { centered ? .center : .leading }
    var frameAlignment: Alignment { centered ? .center : .leading }
    var horizontalAlignment: HorizontalAlignment { centered ? .center : .leading }

    static let worship = DSReadingStyle(scale: .worship, step: 2, font: .serif, lineSpacing: .compact, centered: true)
}

extension View {
    /// Small-caps style label: 11 pt bold, uppercase, tracked.
    func dsEyebrow(tracking: CGFloat = 1.3) -> some View {
        font(DS.Typeface.eyebrow).tracking(tracking).textCase(.uppercase)
    }
}

/// Lyric text at the person's chosen step × Dynamic Type (capped per scale).
struct DSLyricText: View {
    let text: String
    var style: DSReadingStyle
    var italic = false
    var weight: Font.Weight = .regular
    /// A named font (PostScript name) in place of the system face, e.g. the chorus face.
    var face: String?
    var sizeRatio: CGFloat = 1
    /// A line (by index in `text`'s "\n"-separated lines) drawn in brass, for
    /// following the accompaniment. Colour only, so nothing re-wraps.
    var highlightedLine: Int?
    /// 1 at the default Dynamic Type size; grows with the system setting.
    @ScaledMetric(relativeTo: .body) private var dynamicUnit: CGFloat = 1
    @Environment(\.dsSurface) private var surface

    init(_ text: String, style: DSReadingStyle, italic: Bool = false, weight: Font.Weight = .regular,
         face: String? = nil, sizeRatio: CGFloat = 1, highlightedLine: Int? = nil) {
        self.text = text
        self.style = style
        self.italic = italic
        self.weight = weight
        self.face = face
        self.sizeRatio = sizeRatio
        self.highlightedLine = highlightedLine
    }

    var pointSize: CGFloat { style.basePointSize * min(dynamicUnit, style.scale.dynamicTypeCap) }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        guard let highlightedLine else { return result }
        var start = result.startIndex
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let end = result.characters.index(start, offsetBy: line.count)
            if index == highlightedLine {
                result[start..<end].foregroundColor = surface.brass
                break
            }
            guard end < result.endIndex else { break }
            start = result.characters.index(after: end)
        }
        return result
    }

    var body: some View {
        // `fixedSize`: Dynamic Type is already in `pointSize`, so it mustn't be applied twice.
        let font = face.map { Font.custom($0, fixedSize: pointSize * sizeRatio) }
            ?? Font.system(size: pointSize * sizeRatio, weight: weight, design: style.font.design)
        Text(attributed)
            .font(italic && face == nil ? font.italic() : font)
            .lineSpacing(pointSize * style.lineSpacing.leading * style.scale.leadingScale)
            .multilineTextAlignment(style.alignment)
            .frame(maxWidth: .infinity, alignment: style.frameAlignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Motion

extension DS {
    /// No overshoot anywhere: chrome settles with a critically damped spring
    /// (`bounce: 0`) or a plain ease-out, so it never wobbles under a tap.
    enum Motion {
        /// The Lectern opening, closing, switching panels (handle, title, tabs):
        /// a calm ease-out.
        static let lectern = Animation.easeOut(duration: 0.3)
        /// Entering / leaving focus (chrome-free) reading.
        static let focus = Animation.easeOut(duration: 0.3)
        /// Selection of a card, swatch or chip.
        static let select = Animation.easeOut(duration: 0.2)
        /// Press-down on keys and tiles: short, no spring.
        static let press = Animation.easeOut(duration: 0.12)
        /// Current-verse highlight moving during playback / worship.
        static let verse = Animation.easeInOut(duration: 0.35)
        /// Small state changes: previews, toggles, labels.
        static let quick = Animation.easeInOut(duration: 0.2)
        /// Changing reading surface — a slow cross-fade, never a spring.
        static let surface = Animation.easeInOut(duration: 0.3)

        /// Reduce Motion: springs and moves become a plain cross-fade.
        static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.2) : animation
        }
    }
}

/// Subtle press feedback for keys and tiles: a slight dip and dim, no bounce.
/// Reduce Motion keeps only the dim.
struct DSPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Glass

/// How far a glass layer floats. Drives the iOS 17–25 material + shadow.
enum DSGlassDepth: Sendable {
    case dock      // collapsed Lectern, floating capsules
    case capsule   // expanded Lectern, pad, small floating controls
    case card      // GlassCard, What's New tiles
    case sheet     // full panels

    var material: Material {
        switch self {
        case .dock: .ultraThinMaterial
        case .capsule: .thinMaterial
        case .card: .thinMaterial
        case .sheet: .regularMaterial
        }
    }
    var shadowRadius: CGFloat { self == .dock ? 15 : 16 }
    var shadowY: CGFloat { self == .dock ? 5 : 6 }
}

/// The one way to make a floating layer.
/// iOS 26: system Liquid Glass. iOS 17–25: material + hairline + warm shadow,
/// or an opaque `elevated` fill when Reduce Transparency is on.
struct DSGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var depth: DSGlassDepth = .capsule
    var tint: Color? = nil
    var interactive = false

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.environment(\.dsOnGlass, true).glassEffect(glass, in: shape)
        } else {
            content
                .environment(\.dsOnGlass, true)
                .background { fallbackFill }
                .overlay(shape.strokeBorder(surface.isDark ? Color.white.opacity(DS.Fill.stroke)
                                                           : Color.black.opacity(DS.Fill.hairline), lineWidth: 1))
                .shadow(color: shadowColor, radius: depth.shadowRadius, y: depth.shadowY)
        }
    }

    @available(iOS 26, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }

    @ViewBuilder private var fallbackFill: some View {
        if reduceTransparency {
            shape.fill(surface.elevated)
                .overlay(shape.fill((tint ?? .clear).opacity(0.22)))
        } else {
            shape.fill(depth.material)
                .overlay(shape.fill((tint ?? .clear).opacity(0.22)))
        }
    }

    private var shadowColor: Color {
        surface.isDark ? .black.opacity(0.45) : Color(dsHex: 0x1C1F1F).opacity(0.12)
    }
}

extension View {
    /// Apply Vesper glass. See DESIGN.md › Glass for when this is allowed.
    func dsGlass<S: InsettableShape>(_ shape: S, depth: DSGlassDepth = .capsule,
                                     tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(DSGlass(shape: shape, depth: depth, tint: tint, interactive: interactive))
    }
}

/// A list area that is only as tall as its content, and scrolls once it
/// would pass `maxHeight`. (A ScrollView under `.frame(maxHeight:)` always
/// grows to the full cap, leaving a short list floating in empty glass.)
struct DSFittingScroll<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        CappedIdealHeight(maxHeight: maxHeight) {
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Sizes its single child to the child's ideal height, capped at `maxHeight`.
private struct CappedIdealHeight: Layout {
    let maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, maxHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Groups neighbouring glass shapes so they blend and morph together on
/// iOS 26 (`GlassEffectContainer`). A plain pass-through before that.
struct DSGlassGroup<Content: View>: View {
    var spacing: CGFloat = DS.Space.s
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The reading surface beneath the current view.
    @Entry var dsSurface: DSSurface = .paper
    /// Worship mode: maximum contrast, no decoration, bigger targets.
    @Entry var dsWorshipMode: Bool = false
    /// True inside a glass layer (the Lectern, a standalone pad, a popover).
    /// Controls there must not add glass of their own — glass on glass.
    @Entry var dsOnGlass: Bool = false
}

extension View {
    /// Put a subtree on a reading surface: sets `dsSurface`, colour scheme and ground.
    func dsSurface(_ surface: DSSurface, paintsBackground: Bool = true) -> some View {
        modifier(DSSurfaceModifier(surface: surface, paintsBackground: paintsBackground))
    }
}

private struct DSSurfaceModifier: ViewModifier {
    let surface: DSSurface
    let paintsBackground: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsWorshipMode) private var worship

    func body(content: Content) -> some View {
        let high = worship || contrast == .increased
        content
            .environment(\.dsSurface, surface)
            .environment(\.colorScheme, surface.colorScheme)
            .foregroundStyle(high ? surface.highContrastForeground : surface.foreground)
            .tint(surface.tint)
            .background {
                if paintsBackground {
                    (high ? surface.highContrastBackground : surface.background).ignoresSafeArea()
                }
            }
    }
}

// MARK: - Helpers

extension Color {
    /// `0xRRGGBB`. Named `dsHex` to avoid clashing with the prototype's `Color(hex:)`.
    init(dsHex hex: UInt32, opacity: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
