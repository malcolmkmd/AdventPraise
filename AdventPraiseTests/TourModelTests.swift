//
//  TourModelTests.swift
//  AdventPraiseTests
//
//  Skip tour must leave nothing of the tour live: no area's overlay may
//  keep a stage (and so its touch panes) once the tour has ended.
//

import Foundation
import Testing
@testable import Advent_Praise

@MainActor
@Suite(.serialized)
struct TourModelTests {
    private func cleanDefaults() {
        UserDefaults.standard.removeObject(forKey: TourModel.completedKey)
        UserDefaults.standard.removeObject(forKey: TourModel.legacyCompletedKey)
    }

    @Test func startLightsOnlyTheRoot() {
        cleanDefaults(); defer { cleanDefaults() }
        let tour = TourModel()
        tour.start(from: .whatsNew)
        #expect(tour.isActive)
        #expect(tour.liveStage(in: .root) != nil)
        #expect(tour.liveStage(in: .church) == nil)
        #expect(tour.liveStage(in: .more) == nil)
    }

    @Test func skipRightAfterStartLeavesNothingLive() {
        cleanDefaults(); defer { cleanDefaults() }
        let tour = TourModel()
        var active: [Bool] = []
        tour.onActiveChanged = { active.append($0) }
        tour.start(from: .whatsNew)
        tour.skip()
        #expect(!tour.isActive)
        #expect(tour.phase == .idle)
        for area in [TourArea.root, .church, .more] {
            #expect(tour.liveStage(in: area) == nil)
        }
        #expect(active == [true, false])
        #expect(tour.hasCompleted)
    }

    @Test func skipThenChurchModeSignalsDoNothing() {
        cleanDefaults(); defer { cleanDefaults() }
        let tour = TourModel()
        tour.start(from: .whatsNew)
        tour.skip()
        tour.observe(.churchOpen(true))
        tour.observe(.churchOpen(false))
        #expect(tour.phase == .idle)
        #expect(tour.liveStage(in: .church) == nil)
        #expect(tour.liveStage(in: .root) == nil)
    }
}
