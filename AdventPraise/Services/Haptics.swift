//
//  Haptics.swift
//  Advent Praise
//
//  The one place the app makes haptics. Call sites say what happened
//  (`Haptics.play(.pageTurn)`), never how it should feel, so the feel can be
//  tuned here without touching a view.
//
//  - Standard events (selection, impacts, success / warning / error) go
//    through prepared UIKit feedback generators, which follow the system
//    Haptics switch in Settings.
//  - Events with a shape of their own (key press, page turn, threshold,
//    limit, toggle, purchase complete) use Core Haptics where the hardware
//    has it, and fall back to the nearest UIKit generator where it doesn't
//    (or if the engine can't start).
//  - Each event has a minimum interval, and anything inside 25 ms of the
//    last haptic is dropped (outcomes excepted), so a fast slider, a held
//    delete key or two code paths reporting the same change can't buzz.
//  - Off entirely when the user turns Haptics off (More → Reading) and
//    while the app is in the background (lock screen controls, Siri).
//  - Reduce Motion: the multi-pulse page turn and purchase flourish become
//    single plain taps.
//

import CoreHaptics
import SwiftUI
import UIKit

enum HapticEvent: CaseIterable, Sendable {
    /// A choice changed: a segment, chip, tempo, reorder.
    case selection
    case lightImpact
    case mediumImpact
    /// Panels and drawers opening, closing or settling on a detent.
    case softImpact
    /// A drag passed the point where letting go commits (page swipe).
    case thresholdCrossed
    /// Hit an end: no further hymn, smallest / largest text, pinch range, pad full.
    case limit
    case success
    case warning
    case error
    case purchaseComplete
    /// The hymn on screen changed.
    case pageTurn
    /// A number pad key.
    case keyPress
    case toggleOn
    case toggleOff

    static func toggle(_ isOn: Bool) -> HapticEvent { isOn ? .toggleOn : .toggleOff }

    /// The same event can't repeat faster than this.
    fileprivate var minimumInterval: Duration {
        switch self {
        case .keyPress: .milliseconds(35)
        case .selection: .milliseconds(50)
        case .lightImpact, .mediumImpact, .softImpact, .toggleOn, .toggleOff: .milliseconds(70)
        case .thresholdCrossed: .milliseconds(150)
        case .pageTurn: .milliseconds(250)
        case .limit: .milliseconds(350)
        case .success, .warning, .error: .milliseconds(400)
        case .purchaseComplete: .seconds(1)
        }
    }

    /// Outcomes are never swallowed by a tap that happened just before them.
    fileprivate var isOutcome: Bool {
        switch self {
        case .success, .warning, .error, .purchaseComplete: true
        default: false
        }
    }
}

@Observable
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// The user's Haptics switch (More → Reading). On by default.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    @ObservationIgnored private let supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    @ObservationIgnored private var engine: CHHapticEngine?
    @ObservationIgnored private var engineNeedsStart = true
    @ObservationIgnored private let selectionGenerator = UISelectionFeedbackGenerator()
    @ObservationIgnored private let notificationGenerator = UINotificationFeedbackGenerator()
    @ObservationIgnored private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    @ObservationIgnored private var lastPlayed: [HapticEvent: ContinuousClock.Instant] = [:]
    @ObservationIgnored private var lastAny: ContinuousClock.Instant?

    private static let enabledKey = "haptics.enabled"
    private static let globalFloor: Duration = .milliseconds(25)

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Self.enabledKey) == nil || defaults.bool(forKey: Self.enabledKey)
    }

    // MARK: Playing

    static func play(_ event: HapticEvent) { shared.play(event) }

    /// Warms up whatever `event` will use, ahead of a moment that needs to
    /// land exactly (a drag nearing its threshold, a pad about to be typed on).
    static func prepare(_ event: HapticEvent) { shared.prepare(event) }

    func play(_ event: HapticEvent) {
        guard isEnabled, UIApplication.shared.applicationState != .background, admit(event) else { return }
        if let pattern = pattern(for: event, reduced: UIAccessibility.isReduceMotionEnabled),
           playCoreHaptics(pattern) {
            return
        }
        playUIKit(event)
    }

    func prepare(_ event: HapticEvent) {
        guard isEnabled else { return }
        if pattern(for: event, reduced: false) != nil, startedEngine() != nil { return }
        switch event {
        case .selection: selectionGenerator.prepare()
        case .success, .warning, .error, .purchaseComplete: notificationGenerator.prepare()
        default: impactGenerator(fallbackStyle(for: event).style).prepare()
        }
    }

    /// Rate limiting. Records the event when it's let through.
    private func admit(_ event: HapticEvent) -> Bool {
        let now = ContinuousClock.now
        if let last = lastPlayed[event], now - last < event.minimumInterval { return false }
        if !event.isOutcome, let lastAny, now - lastAny < Self.globalFloor { return false }
        lastPlayed[event] = now
        lastAny = now
        return true
    }

    // MARK: UIKit

    private func playUIKit(_ event: HapticEvent) {
        switch event {
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .success, .purchaseComplete: notify(.success)
        case .warning: notify(.warning)
        case .error: notify(.error)
        default:
            let (style, intensity) = fallbackStyle(for: event)
            let generator = impactGenerator(style)
            generator.impactOccurred(intensity: intensity)
            generator.prepare()
        }
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    private func fallbackStyle(for event: HapticEvent) -> (style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        switch event {
        case .mediumImpact, .thresholdCrossed: (.medium, 1)
        case .softImpact, .pageTurn: (.soft, 1)
        case .keyPress: (.light, 0.7)
        case .limit: (.rigid, 0.8)
        case .toggleOff: (.soft, 0.8)
        default: (.light, 1)
        }
    }

    private func impactGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let generator = impactGenerators[style] { return generator }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = generator
        return generator
    }

    // MARK: Core Haptics

    private func playCoreHaptics(_ pattern: CHHapticPattern) -> Bool {
        guard let engine = startedEngine() else { return false }
        do {
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engineNeedsStart = true
            return false
        }
    }

    /// The engine, started. Nil without Core Haptics hardware or if it won't start.
    private func startedEngine() -> CHHapticEngine? {
        guard supportsCoreHaptics else { return nil }
        if engine == nil {
            engine = Self.makeEngine()
            engineNeedsStart = true
        }
        guard let engine else { return nil }
        if engineNeedsStart {
            do { try engine.start() } catch { return nil }
            engineNeedsStart = false
        }
        return engine
    }

    /// Nonisolated so the handlers aren't main-actor closures: Core Haptics
    /// calls them on its own queue, and they hop back to the main actor.
    private nonisolated static func makeEngine() -> CHHapticEngine? {
        guard let engine = try? CHHapticEngine() else { return nil }
        engine.playsHapticsOnly = true
        // Stops after a few idle seconds to save power; restarted on the next haptic.
        engine.isAutoShutdownEnabled = true
        engine.stoppedHandler = { @Sendable _ in
            Task { @MainActor in Haptics.shared.engineNeedsStart = true }
        }
        engine.resetHandler = { @Sendable in
            Task { @MainActor in Haptics.shared.engineNeedsStart = true }
        }
        return engine
    }

    /// The Core Haptics shape for `event`, or nil to use UIKit.
    private func pattern(for event: HapticEvent, reduced: Bool) -> CHHapticPattern? {
        guard supportsCoreHaptics else { return nil }
        let events: [CHHapticEvent]
        switch event {
        case .keyPress: events = [tap(0, intensity: 0.5, sharpness: 0.75)]
        case .limit: events = [tap(0, intensity: 0.65, sharpness: 1)]
        case .thresholdCrossed: events = [tap(0, intensity: 0.85, sharpness: 0.55)]
        case .toggleOn: events = [tap(0, intensity: 0.7, sharpness: 0.6)]
        case .toggleOff: events = [tap(0, intensity: 0.45, sharpness: 0.3)]
        case .pageTurn:
            // A soft brush, then the page landing.
            events = reduced ? [tap(0, intensity: 0.6, sharpness: 0.35)]
                             : [tap(0, intensity: 0.35, sharpness: 0.2), tap(0.05, intensity: 0.7, sharpness: 0.45)]
        case .purchaseComplete:
            guard !reduced else { return nil }   // the plain success notification
            // Three rising taps and a short warm swell.
            events = [tap(0, intensity: 0.45, sharpness: 0.3),
                      tap(0.09, intensity: 0.65, sharpness: 0.4),
                      tap(0.2, intensity: 1, sharpness: 0.6),
                      CHHapticEvent(eventType: .hapticContinuous,
                                    parameters: [.init(parameterID: .hapticIntensity, value: 0.3),
                                                 .init(parameterID: .hapticSharpness, value: 0.1),
                                                 .init(parameterID: .releaseTime, value: 0.2)],
                                    relativeTime: 0.2, duration: 0.3)]
        default: return nil
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }

    private func tap(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [.init(parameterID: .hapticIntensity, value: intensity),
                                   .init(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: time)
    }
}

// MARK: - SwiftUI

extension View {
    /// Plays `event` whenever `trigger` changes. Use instead of
    /// `sensoryFeedback`, which would bypass the user's Haptics switch.
    func haptic<T: Equatable>(_ event: HapticEvent, trigger: T) -> some View {
        onChange(of: trigger) { Haptics.play(event) }
    }

    /// Plays the event `feedback` returns for a change of `trigger`, if any.
    func haptic<T: Equatable>(trigger: T, _ feedback: @escaping (_ old: T, _ new: T) -> HapticEvent?) -> some View {
        onChange(of: trigger) { old, new in
            if let event = feedback(old, new) { Haptics.play(event) }
        }
    }
}
