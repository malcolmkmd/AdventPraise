//
//  VesperTheme.swift
//  Advent Praise
//
//  Design tokens, reading settings and the glass-surface modifier shared by
//  every screen. "Vesper" is the name of the visual system: a warm paper
//  ground, an Evergreen tint for the app, Brass for anything musical, and a
//  permanently dark "Stage" for Now Playing.
//

import SwiftUI
import UIKit

// MARK: - Palette

enum Vesper {
    /// Primary tint — navigation, actions, play.
    static let evergreen = Color(red: 0.122, green: 0.455, blue: 0.400)      // #1F7466
    static let evergreenOnDark = Color(red: 0.373, green: 0.722, blue: 0.651) // #5FB8A6
    /// Musical accent — verse numerals, chorus labels, solo.
    static let brass = Color(red: 0.498, green: 0.357, blue: 0.110)          // #7F5B1C
    static let brassOnDark = Color(red: 0.831, green: 0.659, blue: 0.325)    // #D4A853
    enum Radius {
        static let dock: CGFloat = 32      // the Lectern, collapsed
        static let panel: CGFloat = 30     // the Lectern, expanded
        static let capsule: CGFloat = 22
        static let card: CGFloat = 18
        static let key: CGFloat = 14
        static let chip: CGFloat = 14
    }
}

// MARK: - Reading environment

enum ReadingEnvironment: String, CaseIterable, Identifiable, Codable {
    case paper, parchment, sepia, muted, black
    var id: String { rawValue }

    var name: String {
        switch self {
        case .paper: "Paper"
        case .parchment: "Parchment"
        case .sepia: "Sepia"
        case .muted: "Muted"
        case .black: "Black"
        }
    }

    var background: Color {
        switch self {
        case .paper: Color(red: 0.969, green: 0.957, blue: 0.933)     // #F7F4EE
        case .parchment: Color(red: 0.953, green: 0.914, blue: 0.831) // #F3E9D4
        case .sepia: Color(red: 0.902, green: 0.839, blue: 0.725)     // #E6D6B9
        case .muted: Color(red: 0.149, green: 0.165, blue: 0.161)     // #262A29
        case .black: .black
        }
    }

    var foreground: Color {
        switch self {
        case .paper: Color(red: 0.110, green: 0.122, blue: 0.118)     // #1C1F1E
        case .parchment: Color(red: 0.231, green: 0.184, blue: 0.118) // #3B2F1E
        case .sepia: Color(red: 0.243, green: 0.184, blue: 0.114)     // #3E2F1D
        case .muted: Color(red: 0.851, green: 0.859, blue: 0.847)     // #D9DBD8
        case .black: Color(red: 0.910, green: 0.902, blue: 0.878)     // #E8E6E0
        }
    }

    var isDark: Bool { self == .muted || self == .black }
    var secondary: Color { foreground.opacity(0.62) }
    var tint: Color { isDark ? Vesper.evergreenOnDark : Vesper.evergreen }
    var brass: Color { isDark ? Vesper.brassOnDark : Vesper.brass }
    /// The system appearance a sheet should adopt over this environment.
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

enum ReadingFont: String, CaseIterable, Identifiable, Codable {
    case serif, sans
    var id: String { rawValue }
    var name: String { self == .serif ? "Serif" : "Sans" }
    var detail: String { self == .serif ? "New York · for the hymnal" : "San Francisco · clean and plain" }
    var design: Font.Design { self == .serif ? .serif : .default }
}

enum LineSpacingOption: String, CaseIterable, Identifiable, Codable {
    case compact, normal, relaxed
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    /// Extra leading as a fraction of the point size.
    var leading: CGFloat {
        switch self {
        case .compact: 0.18
        case .normal: 0.34
        case .relaxed: 0.55
        }
    }
}

// MARK: - Reading settings (persisted)

@Observable
@MainActor
final class ReadingSettings {
    static let sizeSteps: [CGFloat] = [16, 18, 19, 21, 24]
    /// Large print: the same five steps, sized for reading at arm's length.
    static let largePrintSteps: [CGFloat] = [28, 32, 36, 42, 48]

    var sizeIndex: Int { didSet { save() } }
    var lineSpacing: LineSpacingOption { didSet { save() } }
    var alignment: TextAlignment { didSet { save() } }
    var font: ReadingFont { didSet { save() } }
    var environment: ReadingEnvironment { didSet { save() } }
    var largePrint: Bool { didSet { save() } }
    /// Print a hymn's single chorus after every verse, as it is sung.
    var repeatChorus: Bool { didSet { save() } }

    var steps: [CGFloat] { largePrint ? Self.largePrintSteps : Self.sizeSteps }
    var pointSize: CGFloat { steps[sizeIndex] }
    /// Lyric and title fonts also follow the system Dynamic Type setting via `typeScale`.
    func lyricFont(scale: CGFloat) -> Font {
        .system(size: pointSize * scale, weight: largePrint ? .medium : .regular, design: font.design)
    }
    func titleFont(scale: CGFloat) -> Font {
        .system(size: max(28, pointSize * 1.2) * scale, weight: .semibold, design: font.design)
    }
    func lineSpacingPoints(scale: CGFloat) -> CGFloat { pointSize * scale * lineSpacing.leading }

    func stepSize(by delta: Int) {
        sizeIndex = min(max(sizeIndex + delta, 0), steps.count - 1)
    }

    private static let key = "reading.settings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            sizeIndex = saved.sizeIndex
            lineSpacing = saved.lineSpacing
            alignment = saved.centered ? .center : .leading
            font = saved.font
            environment = saved.environment
            largePrint = saved.largePrint ?? false
            repeatChorus = saved.repeatChorus ?? false
        } else {
            sizeIndex = 2
            lineSpacing = .normal
            alignment = .leading
            font = .serif
            environment = .paper
            largePrint = false
            repeatChorus = false
        }
    }

    private struct Snapshot: Codable {
        var sizeIndex: Int
        var lineSpacing: LineSpacingOption
        var centered: Bool
        var font: ReadingFont
        var environment: ReadingEnvironment
        var largePrint: Bool?
        var repeatChorus: Bool?
    }

    private func save() {
        let snapshot = Snapshot(sizeIndex: sizeIndex, lineSpacing: lineSpacing,
                                centered: alignment == .center, font: font, environment: environment,
                                largePrint: largePrint, repeatChorus: repeatChorus)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - Glass surfaces

/// One modifier for every floating layer. On iOS 26 it uses the system's
/// Liquid Glass; earlier systems fall back to a material with a hairline
/// and a warm shadow so the layering reads the same.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    enum Depth { case dock, capsule, sheet }
    let shape: S
    let depth: Depth
    var isDark = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(material, in: shape)
                .overlay(shape.strokeBorder(isDark ? .white.opacity(0.12) : .black.opacity(0.08), lineWidth: 1))
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
    }

    private var material: Material {
        switch depth {
        case .dock: .ultraThinMaterial
        case .capsule: .thinMaterial
        case .sheet: .regularMaterial
        }
    }
    private var shadowColor: Color { isDark ? .black.opacity(0.45) : Color(red: 0.11, green: 0.12, blue: 0.12).opacity(0.12) }
    private var shadowRadius: CGFloat { depth == .dock ? 15 : 16 }
    private var shadowY: CGFloat { depth == .dock ? 5 : 6 }
}

extension View {
    func glassSurface<S: InsettableShape>(_ shape: S, depth: GlassSurface<S>.Depth, isDark: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, depth: depth, isDark: isDark))
    }
}

// MARK: - Dynamic Type

/// A fixed design size that still follows the system text size setting.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let italic: Bool

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, italic: Bool, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
        self.italic = italic
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: size, weight: weight, design: design)
        content.font(italic ? font.italic() : font)
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default,
                    italic: Bool = false, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, italic: italic, relativeTo: style))
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
