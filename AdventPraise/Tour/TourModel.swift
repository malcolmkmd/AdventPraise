//
//  TourModel.swift
//  Advent Praise
//
//  The onboarding tour: eight coach marks over the real app. It runs once,
//  right after What's New is dismissed, and again from More's Replay tour.
//  Each step dims the screen around a real control (TourOverlay.swift draws
//  the cut-out and the card) and waits for the person to use it: open the
//  number pad and go to a hymn, swipe, open the tray, the globe, Play,
//  Memorise, church mode and its actions, then where Pro and Support live.
//  A step's later stages explain what opened and offer Next; Skip tour is
//  on every card.
//
//  The model is a small state machine. It never reaches into the reader:
//  the hosts report what happened (`observe`) and run the few side effects
//  a Next needs (`perform`: close the tray, stop the piano, leave church
//  mode). While it runs, nothing played counts toward the free plays
//  (`FreePlays.isTourActive`, wired in AppServices).
//

import Observation
import OSLog
import SwiftUI

/// The eight stops, in order. The raw value is the step number shown.
enum TourStep: Int, CaseIterable, Identifiable, Sendable {
    case numberPad = 1, swipe, tray, globe, player, memorise, church, pro
    var id: Int { rawValue }

    var next: TourStep? { TourStep(rawValue: rawValue + 1) }
}

enum TourSource: String, Sendable {
    case whatsNew = "whats_new"
    case more
    /// `-uiDebugTour`, for screenshots.
    case debug
}

/// Which hierarchy draws a stage's coach: the reader's root, church mode's
/// full-screen cover, or More's sheet. Each hosts its own overlay, since a
/// cover or sheet sits above everything in the root.
enum TourArea: Sendable {
    case root, church, more
}

/// A real control the tour points at. Views mark themselves with
/// `.tourAnchor(_:)`; the overlay in the same area finds the frame.
enum TourTarget: Hashable, Sendable {
    /// The Lectern's keypad button, number pad, title, hymn tray, Play and transport.
    case jump, numberPad, title, tray, play, transport
    /// The globe in the navigation bar, and the menu bar it grows into.
    case globe, menuBar
    /// Tiles in the hymn tray.
    case memoriseTile, churchTile, moreTile
    /// Church mode's presenter actions (the slider) and its Leave button.
    case churchActions, churchLeave
    /// More's Pro card and Support row.
    case proCard, supportRow
    /// The iPad sidebar's two rows, lit together.
    case sidebarPro, sidebarSupport
}

/// What the reader is like right now, which shapes a few stages.
struct TourContext: Equatable, Sendable {
    /// The open hymn has a piano, so Play is on the bar.
    var hasAccompaniment = true
    /// iPad: the sidebar is out, so step 8 can point at its rows too.
    var sidebarVisible = false
    /// iPad: the keypad opens a popover the tour can't see into.
    var isRegularWidth = false
}

/// One card: where it is drawn, what it points at, what it says and whether
/// it offers Next or waits for the control to be used.
struct TourStage {
    var area: TourArea
    /// The controls lit together; empty for a card alone.
    var targets: [TourTarget]
    var title: LocalizedStringKey
    var body: LocalizedStringKey
    /// Explains rather than asks: the card offers Next (Done on the last).
    var showsNext = false
    /// Under a sheet the person is exploring: no card at all until it closes.
    var isHidden = false
    /// Taps outside the cut-out are swallowed. Off for the swipe step.
    var blocksTouches = true

    var target: TourTarget? { targets.first }
}

/// What the hosts tell the tour.
enum TourSignal: Equatable, Sendable {
    case lectern(LecternState)
    case hymnChanged
    case menuOpen(Bool)
    case playing(Bool)
    case memoriseOpen(Bool)
    case churchOpen(Bool)
    case churchActionsOpen(Bool)
    case moreOpen(Bool)
}

/// What a Next may need done to the reader.
enum TourAction: Equatable, Sendable {
    /// Before step 1: the tray and the menu closed.
    case resetChrome
    case closeLectern
    case closeMenu
    case stopPlayer
    case leaveChurchMode
    case closeMore
}

@Observable
@MainActor
final class TourModel {
    enum Phase: Equatable {
        case idle
        case running(TourStep, stage: Int)
        /// "You're all set", after step 8.
        case finale
    }

    private(set) var phase: Phase = .idle
    /// What the reader is like; the root host keeps it current.
    var context = TourContext()
    /// A start asked for while something else was up (What's New's Try
    /// Worship Mode opens church mode first). The root host starts it once
    /// the screen is clear.
    private(set) var pending: TourSource?
    /// The root host runs these for the model.
    @ObservationIgnored var perform: ((TourAction) -> Void)?
    /// FreePlays follows this (AppServices).
    @ObservationIgnored var onActiveChanged: ((Bool) -> Void)?
    @ObservationIgnored private var source: TourSource = .more
    @ObservationIgnored private var furthestStep: TourStep = .numberPad

    static let completedKey = "tourSeen"
    /// The 7.0.1 builds before `tourSeen` wrote this; still honoured.
    static let legacyCompletedKey = "tour.completed"
    /// `-UITestSkipTour YES`: UI tests never see the tour.
    static var skippedForUITests: Bool { UserDefaults.standard.bool(forKey: "UITestSkipTour") }
    private let defaults = UserDefaults.standard
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdventPraise", category: "tour")

    var isActive: Bool { phase != .idle }
    var hasCompleted: Bool { defaults.bool(forKey: Self.completedKey) || defaults.bool(forKey: Self.legacyCompletedKey) }

    var step: TourStep? {
        if case .running(let step, _) = phase { return step }
        return nil
    }

    var stageIndex: Int {
        if case .running(_, let stage) = phase { return stage }
        return 0
    }

    /// The card to draw now, if any.
    var stage: TourStage? {
        switch phase {
        case .idle:
            return nil
        case .running(let step, let index):
            let all = stages(for: step)
            return all.indices.contains(index) ? all[index] : nil
        case .finale:
            return TourStage(area: .root, targets: [], title: "You’re all set",
                             body: "That’s the tour. Replay it any time from More. Happy singing.", showsNext: true)
        }
    }

    /// For the card's "Step 3 of 8" and transitions: one value per card.
    var cardID: String {
        switch phase {
        case .idle: "idle"
        case .running(let step, let stage): "\(step.rawValue).\(stage)"
        case .finale: "finale"
        }
    }

    // MARK: Starting and ending

    /// What's New has just closed: the tour follows, once, unless it has
    /// been taken or a debug argument owns the tour.
    func offerAfterWhatsNew() {
        guard !hasCompleted, !isActive, pending == nil, !Self.skippedForUITests else { return }
        #if DEBUG
        guard DebugLaunch.tour == nil, DebugLaunch.screenshotState == nil else { return }
        #endif
        pending = .whatsNew
    }

    /// Launch with What's New already dismissed (an existing user): the tour
    /// runs once, when the reader is clear.
    func offerOnLaunch() { offerAfterWhatsNew() }

    /// The screen is clear (no church mode, More or sheet): a pending start goes ahead.
    func startPending() {
        guard let pending else { return }
        self.pending = nil
        start(from: pending)
    }

    func start(from source: TourSource, at step: TourStep = .numberPad, stage: Int = 0) {
        self.source = source
        furthestStep = step
        pending = nil
        perform?(.resetChrome)
        Analytics.track(.tourStarted(source: source))
        set(.running(step, stage: stage))
        Haptics.play(.softImpact)
        onActiveChanged?(true)
    }

    /// Skip tour: ends it here. It won't come back after What's New.
    func skip() {
        guard isActive else { return }
        finish(completed: false)
    }

    /// Next, or Done on the last card.
    func advance() {
        switch phase {
        case .idle: return
        case .finale: finish(completed: true)
        case .running(let step, let index):
            leave(step, stage: index)
            moveOn(from: step, stage: index)
        }
    }

    private func finish(completed: Bool) {
        defaults.set(true, forKey: Self.completedKey)
        Analytics.track(.tourFinished(completed: completed, lastStep: furthestStep.rawValue))
        set(.idle)
        Haptics.play(completed ? .success : .softImpact)
        onActiveChanged?(false)
    }

    // MARK: Observing

    /// Something happened in the reader. The current stage decides whether
    /// it was the thing being asked for.
    func observe(_ signal: TourSignal) {
        guard case .running(let step, let index) = phase else { return }
        switch (step, index, signal) {
        // 1 · Number pad: open it, type, Go.
        case (.numberPad, 0, .lectern(.pad)): go(step, 1)
        case (.numberPad, 1, .lectern(.collapsed)), (.numberPad, 1, .lectern(.search)): go(step, 0)
        case (.numberPad, _, .hymnChanged): complete(step)
        // 2 · Swipe.
        case (.swipe, _, .hymnChanged): complete(step)
        // 3 · The tray.
        case (.tray, 0, .lectern(.hymn)): go(step, 1)
        case (.tray, 1, .lectern(.collapsed)): complete(step)
        // 4 · The globe.
        case (.globe, 0, .menuOpen(true)): go(step, 1)
        case (.globe, 1, .menuOpen(false)): complete(step)
        // 5 · The piano.
        case (.player, 0, .playing(true)) where context.hasAccompaniment: go(step, 1)
        // 6 · Memorise, in the tray; the sheet is explored, then the tour goes on.
        case (.memorise, 0, .lectern(.hymn)): go(step, 1)
        case (.memorise, 1, .lectern(.collapsed)): go(step, 0)
        case (.memorise, _, .memoriseOpen(true)): go(step, 2)
        case (.memorise, 2, .memoriseOpen(false)): complete(step)
        // 7 · Church mode and its actions.
        case (.church, 0, .lectern(.hymn)): go(step, 1)
        case (.church, 1, .lectern(.collapsed)): go(step, 0)
        case (.church, 0, .churchOpen(true)), (.church, 1, .churchOpen(true)): go(step, 2)
        case (.church, 2, .churchActionsOpen(true)): go(step, 3)
        case (.church, 3, .churchActionsOpen(false)): go(step, 4)
        case (.church, 2, .churchOpen(false)), (.church, 3, .churchOpen(false)), (.church, 4, .churchOpen(false)):
            complete(step)
        // 8 · Pro and Support, in More (and the iPad sidebar).
        case (.pro, 0, .lectern(.hymn)): go(step, 1)
        case (.pro, 1, .lectern(.collapsed)): go(step, 0)
        case (.pro, 0, .moreOpen(true)), (.pro, 1, .moreOpen(true)): go(step, 2)
        case (.pro, 2, .moreOpen(false)), (.pro, 3, .moreOpen(false)):
            if context.sidebarVisible { go(step, 4) } else { complete(step) }
        default: break
        }
    }

    // MARK: Stages

    /// The cards of a step, in order.
    func stages(for step: TourStep) -> [TourStage] {
        switch step {
        case .numberPad:
            return [
                TourStage(area: .root, targets: [.jump], title: "Find a hymn by number",
                          body: "Tap the keypad to open the number pad."),
                TourStage(area: .root, targets: [.numberPad], title: "Type a number, then tap Go",
                          body: "The title appears as you type, so you know you have the right hymn.",
                          isHidden: context.isRegularWidth),
            ]
        case .swipe:
            return [
                TourStage(area: .root, targets: [], title: "Turn the page",
                          body: "Swipe left for the next hymn and right for the one before. The arrow at the edge fills up when you have gone far enough to let go.",
                          showsNext: true, blocksTouches: false),
            ]
        case .tray:
            return [
                TourStage(area: .root, targets: [.title], title: "Everything for this hymn",
                          body: "Tap the number or title on the bar to open the hymn tray."),
                TourStage(area: .root, targets: [.tray], title: "The hymn tray",
                          body: "Church mode, Memorise, playlists and Save are all one tap away. More, at the end, holds the tools and settings.",
                          showsNext: true),
            ]
        case .globe:
            return [
                TourStage(area: .root, targets: [.globe], title: "Translations, theme and text",
                          body: "Tap the globe at the top."),
                TourStage(area: .root, targets: [.menuBar], title: "Read it your way",
                          body: "Switch hymnals and keep your hymn number, pick a reading surface, or set the text size and font. About tells the hymn’s story.",
                          showsNext: true),
            ]
        case .player:
            guard context.hasAccompaniment else {
                return [
                    TourStage(area: .root, targets: [], title: "Hear the piano",
                              body: "Hymns with a piano show Play at the left of the bar, and the verse being sung lights up as it goes. This hymn has no piano yet.",
                              showsNext: true),
                ]
            }
            return [
                TourStage(area: .root, targets: [.play], title: "Hear the piano",
                          body: "Tap Play. Nothing you play on the tour counts toward your free plays."),
                TourStage(area: .root, targets: [.transport], title: "Sing along",
                          body: "The verse being sung lights up as it goes. Restart, scrub, or change the tempo here, and pause whenever you like.",
                          showsNext: true),
            ]
        case .memorise:
            return [
                TourStage(area: .root, targets: [.title], title: "Learn a verse by heart",
                          body: "Open the hymn tray again."),
                TourStage(area: .root, targets: [.memoriseTile], title: "Learn a verse by heart",
                          body: "Tap Memorise and fill in the missing words. Tap Done there to come back to the tour."),
                TourStage(area: .root, targets: [], title: "", body: "", isHidden: true),
            ]
        case .church:
            return [
                TourStage(area: .root, targets: [.title], title: "Sing together",
                          body: "Open the hymn tray."),
                TourStage(area: .root, targets: [.churchTile], title: "Sing together",
                          body: "Tap Church for one verse at a time, big and bright."),
                TourStage(area: .church, targets: [.churchActions], title: "Church mode",
                          body: "Tap the slider for text size, Blank, Announcement and Image."),
                TourStage(area: .church, targets: [], title: "", body: "", isHidden: true),
                TourStage(area: .church, targets: [.churchLeave], title: "Leading the singing",
                          body: "Tap the right side of the screen for the next verse, the left to go back. With Pro, AirPlay puts the words on a TV. Tap X when you are done.",
                          showsNext: true),
            ]
        case .pro:
            var stages = [
                TourStage(area: .root, targets: [.title], title: "Pro and support",
                          body: "Open the hymn tray one last time."),
                TourStage(area: .root, targets: [.moreTile], title: "Pro and support",
                          body: "Tap More."),
                TourStage(area: .more, targets: [.proCard], title: "Advent Praise Pro",
                          body: "Unlimited piano, the worship display on a TV, widgets and more, bought once. Tap this card any time to see what Pro opens.",
                          showsNext: true),
                TourStage(area: .more, targets: [.supportRow], title: "Support Advent Praise",
                          body: "A one-time tip to keep the hymns ringing. It unlocks nothing and is never required.",
                          showsNext: true),
            ]
            if context.sidebarVisible {
                stages.append(TourStage(area: .root, targets: [.sidebarPro, .sidebarSupport], title: "Also in the sidebar",
                                        body: "On iPad, Pro and Support are one tap away here too.",
                                        showsNext: true))
            }
            return stages
        }
    }

    // MARK: Private

    private func go(_ step: TourStep, _ stage: Int) {
        set(.running(step, stage: stage))
        Haptics.play(.selection)
    }

    /// The step is done: on to the next, or the finale.
    private func complete(_ step: TourStep) {
        Analytics.track(.tourStepCompleted(step: step.rawValue))
        if let next = step.next {
            furthestStep = next
            set(.running(next, stage: 0))
        } else {
            set(.finale)
        }
        Haptics.play(.softImpact)
    }

    /// Next on an explaining stage: what to put back before moving on.
    private func leave(_ step: TourStep, stage: Int) {
        switch (step, stage) {
        case (.tray, 1): perform?(.closeLectern)
        case (.globe, 1): perform?(.closeMenu)
        case (.player, 1): perform?(.stopPlayer)
        case (.church, 4): perform?(.leaveChurchMode)
        case (.pro, 3): perform?(.closeMore)
        default: break
        }
    }

    /// Where Next goes from each stage.
    private func moveOn(from step: TourStep, stage: Int) {
        switch (step, stage) {
        case (.church, 4):
            // Leaving church mode reports `churchOpen(false)`, which completes the step.
            break
        case (.pro, 3):
            // Closing More reports `moreOpen(false)`: the sidebar stage or the finale follows.
            break
        case (.pro, 4):
            complete(step)
        default:
            let count = stages(for: step).count
            if stage + 1 < count, !stages(for: step)[stage + 1].isHidden {
                go(step, stage + 1)
            } else {
                complete(step)
            }
        }
    }

    private func set(_ next: Phase) {
        guard phase != next else { return }
        Self.log.debug("tour \(String(describing: self.phase)) -> \(String(describing: next))")
        let animation = DS.Motion.adaptive(.spring(duration: 0.5, bounce: 0.18),
                                           reduceMotion: UIAccessibility.isReduceMotionEnabled)
        withAnimation(animation) { phase = next }
    }
}
