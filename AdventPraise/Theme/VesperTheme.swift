//
//  VesperTheme.swift
//  Advent Praise
//
//  Persisted reading settings, Dynamic Type helper and haptics. Colour, type,
//  spacing and glass live in Design/DesignTokens.swift (the Vesper system).
//

import SwiftUI
import UIKit

// MARK: - Reading settings (persisted)

@Observable
@MainActor
final class ReadingSettings {
    var style: DSReadingStyle { didSet { save() } }
    var surface: DSSurface { didSet { save() } }
    /// Print a hymn's single chorus after every verse, as it is sung.
    var repeatChorus: Bool { didSet { save() } }

    var largePrint: Bool {
        get { style.scale == .largePrint }
        set {
            guard newValue != largePrint else { return }
            var next = style
            next.scale = newValue ? .largePrint : .standard
            next.step = min(next.step, next.scale.steps.count - 1)
            style = next
        }
    }

    private static let key = "reading.settings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            style = DSReadingStyle(scale: (saved.largePrint ?? false) ? .largePrint : .standard,
                                   step: min(max(saved.sizeIndex, 0), 4),
                                   font: saved.font,
                                   lineSpacing: saved.lineSpacing,
                                   centered: saved.centered)
            surface = saved.environment
            repeatChorus = saved.repeatChorus ?? false
        } else {
            style = DSReadingStyle()
            surface = .paper
            repeatChorus = false
        }
    }

    /// Decodes the v1 snapshot. Raw values match `DSSurface`, `DS.ReadingFont` and `DS.LineSpacing`.
    private struct Snapshot: Codable {
        var sizeIndex: Int
        var lineSpacing: DS.LineSpacing
        var centered: Bool
        var font: DS.ReadingFont
        var environment: DSSurface
        var largePrint: Bool?
        var repeatChorus: Bool?
    }

    private func save() {
        let snapshot = Snapshot(sizeIndex: style.step, lineSpacing: style.lineSpacing,
                                centered: style.centered, font: style.font, environment: surface,
                                largePrint: largePrint, repeatChorus: repeatChorus)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
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

// MARK: - Model adapters

extension HymnalInfo {
    /// The shape `LanguagePicker` and `LanguageMenuButton` take.
    var designHymnal: DSHymnal {
        DSHymnal(id: id, name: name, language: language, swatch: color)
    }
}

extension Hymn {
    var designSummary: DSHymnSummary {
        DSHymnSummary(number: id, title: title, firstLine: blocks.first?.lines.first)
    }
}

