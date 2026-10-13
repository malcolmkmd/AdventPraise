//
//  VesperTheme.swift
//  Advent Praise
//
//  Persisted reading settings and a Dynamic Type helper. Colour, type,
//  spacing and glass live in Design/DesignTokens.swift (the Vesper system);
//  haptics in Services/Haptics.swift.
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
    /// Church mode's base lyric size, before Dynamic Type and large print.
    /// Set by its text size buttons (one worship step at a time) and by
    /// pinching (anywhere in the worship pinch range).
    var worshipPointSize: CGFloat { didSet { save() } }

    /// 42 pt: a typical four-line verse fits an iPhone without scrolling.
    static let defaultWorshipPointSize = DS.LyricScale.worship.steps[1]

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
                                   centered: saved.centered,
                                   pinchedPointSize: saved.pointSize)
            surface = saved.environment
            repeatChorus = saved.repeatChorus ?? false
            worshipPointSize = (saved.worshipPointSize ?? Self.defaultWorshipPointSize)
                .clamped(to: DS.LyricScale.worship.pinchRange)
        } else {
            style = DSReadingStyle()
            surface = .paper
            repeatChorus = false
            worshipPointSize = Self.defaultWorshipPointSize
        }
        reported = Reported(style: style, surface: surface, repeatChorus: repeatChorus)
        Analytics.setAppearance(surface: surface, largePrint: style.scale == .largePrint)
    }

    // MARK: Analytics

    /// How the next reader size change was made, when the change alone can't
    /// tell (a double-tap reset looks like the slider). Cleared once reported.
    @ObservationIgnored var nextSizeMethod: TextSizeMethod?
    @ObservationIgnored private var reported: Reported?
    @ObservationIgnored private var reportTask: Task<Void, Never>?

    private struct Reported {
        var style: DSReadingStyle
        var surface: DSSurface
        var repeatChorus: Bool
    }

    /// Reports changes a second after they settle, so dragging the size
    /// slider or flicking through surfaces sends the final choice only.
    /// Church mode's size is reported where it changes (ChurchModeView).
    private func scheduleReport() {
        reportTask?.cancel()
        reportTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reportChanges()
        }
    }

    private func reportChanges() {
        guard let old = reported else { return }
        reported = Reported(style: style, surface: surface, repeatChorus: repeatChorus)
        var changes: [AppearanceChange] = []
        if surface != old.surface { changes.append(.surface(surface)) }
        if style.font != old.style.font { changes.append(.font(style.font)) }
        if style.lineSpacing != old.style.lineSpacing { changes.append(.lineSpacing(style.lineSpacing)) }
        if style.centered != old.style.centered { changes.append(.centered(style.centered)) }
        if style.scale != old.style.scale { changes.append(.largePrint(style.scale == .largePrint)) }
        changes.forEach { Analytics.track(.appearanceChanged($0)) }
        // Switching print scale moves the size with it; that's the large print change, not a resize.
        if style.scale == old.style.scale, Int(style.basePointSize) != Int(old.style.basePointSize) {
            let method = nextSizeMethod ?? (style.pinchedPointSize != nil ? .pinch : .slider)
            Analytics.track(.textSizeChanged(context: .reader, method: method, pointSize: Int(style.basePointSize)))
        }
        nextSizeMethod = nil
        if repeatChorus != old.repeatChorus { Analytics.track(.settingChanged(.repeatChorus, isOn: repeatChorus)) }
        if surface != old.surface || style.scale != old.style.scale {
            Analytics.setAppearance(surface: surface, largePrint: style.scale == .largePrint)
        }
    }

    /// The worship step the text size buttons would move to from wherever a
    /// pinch left the size; nil at either end.
    func worshipStepTarget(by delta: Int) -> CGFloat? {
        let steps = DS.LyricScale.worship.steps
        return delta > 0 ? steps.first { $0 > worshipPointSize + 0.5 } : steps.last { $0 < worshipPointSize - 0.5 }
    }

    /// Church mode: one text-size step smaller or larger. False at a limit.
    @discardableResult
    func stepWorshipText(by delta: Int) -> Bool {
        guard let target = worshipStepTarget(by: delta) else { return false }
        worshipPointSize = target
        return true
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
        /// A pinched reader size between the steps.
        var pointSize: CGFloat?
        var worshipPointSize: CGFloat?
    }

    private func save() {
        let snapshot = Snapshot(sizeIndex: style.step, lineSpacing: style.lineSpacing,
                                centered: style.centered, font: style.font, environment: surface,
                                largePrint: largePrint, repeatChorus: repeatChorus,
                                pointSize: style.pinchedPointSize, worshipPointSize: worshipPointSize)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        scheduleReport()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
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

// MARK: - Model adapters

extension HymnalInfo {
    /// The shape `LanguagePicker` and `LanguageMenuButton` take.
    var designHymnal: DSHymnal {
        DSHymnal(id: id, name: name, language: language, color: color)
    }
}

extension Hymn {
    var designSummary: DSHymnSummary {
        DSHymnSummary(number: id, title: title, firstLine: blocks.first?.lines.first)
    }
}

