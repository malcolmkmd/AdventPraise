//
//  ChurchLiveActivity.swift
//  Advent Praise
//
//  Runs church mode's Live Activity while presenting (Pro): follows the
//  hymn and verse, and carries out its Previous / Next / End buttons
//  directly on ChurchPresentation and ReaderModel, so they work with the
//  phone locked (the TV follows the same state). End asks ChurchModeView
//  to close (ChurchPresentation.endRequested).
//

import ActivityKit
import Foundation
import Observation
import os

@MainActor
final class ChurchLiveActivity {
    static let shared = ChurchLiveActivity()
    private static let log = Logger(subsystem: "com.mDev.Advent-Praise", category: "LiveActivity")

    private var activity: Activity<ChurchActivityAttributes>?
    private var isRunning = false
    private var lastState: ChurchActivityAttributes.ContentState?

    func start() {
        guard !isRunning else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.log.notice("Live Activities are off")
            return
        }
        isRunning = true
        ChurchRemoteBridge.handler = { action in ChurchLiveActivity.perform(action) }
        // One from a previous run (the app was quit while presenting).
        for old in Activity<ChurchActivityAttributes>.activities {
            nonisolated(unsafe) let old = old   // ActivityKit's Activity isn't Sendable
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        follow()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        ChurchRemoteBridge.handler = nil
        lastState = nil
        if let current = activity {
            nonisolated(unsafe) let ending = current
            Task { await ending.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }

    private func follow() {
        guard isRunning else { return }
        let services = AppServices.shared
        let state = withObservationTracking { Self.state(services) } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        guard state != lastState else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            nonisolated(unsafe) let current = activity
            Task { await current.update(content) }
        } else {
            do {
                activity = try Activity.request(
                    attributes: ChurchActivityAttributes(hymnal: services.reader.hymnal.name),
                    content: content, pushType: nil)
                Self.log.notice("live activity started")
            } catch {
                Self.log.error("request failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private static func state(_ s: AppServices) -> ChurchActivityAttributes.ContentState {
        let hymn = s.reader.hymn, church = s.church
        let sequence = hymn.sungSequence
        let index = min(church.index, max(sequence.count - 1, 0))
        let position: String
        if church.isBlanked {
            position = String(localized: "Screen blank")
        } else if sequence.indices.contains(index) {
            switch sequence[index] {
            case let .verse(number, _): position = String(localized: "Verse \(number) of \(hymn.verseCount)")
            case .chorus: position = s.reader.hymnal.chorusLabel
            }
        } else {
            position = ""
        }
        return .init(hymnNumber: hymn.id, title: hymn.title, position: position,
                     step: index + 1, stepCount: sequence.count, canGoBack: index > 0,
                     isOnTV: church.isExternalScreenConnected)
    }

    /// The buttons, the same moves as church mode's arrows.
    private static func perform(_ action: ChurchRemoteAction) {
        let s = AppServices.shared, church = s.church, reader = s.reader
        let count = reader.hymn.sungSequence.count
        switch action {
        case .next:
            church.isBlanked = false
            if church.index < count - 1 {
                church.index += 1
            } else if reader.goToNextHymn(source: .churchMode) != nil {
                church.index = 0
            }
        case .previous:
            church.isBlanked = false
            if church.index > 0 { church.index -= 1 }
        case .end:
            church.endRequested = true
        }
        log.notice("button \(action.rawValue, privacy: .public)")
    }
}
