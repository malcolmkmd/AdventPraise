//
//  ScreenMirroringTests.swift
//  AdventPraiseTests
//
//  The Go Pro banner on a mirrored screen: never for Pro, an external
//  display before a capture, and `mirroring_detected` once per session.
//

import Testing
@testable import Advent_Praise

@MainActor
struct ScreenMirroringTests {
    @Test func proNeverSeesTheBanner() {
        for captured in [false, true] {
            for external in [false, true] {
                #expect(ScreenMirroring.bannerRoute(isPro: true, isCaptured: captured, hasExternalDisplay: external) == nil)
            }
        }
    }

    @Test func freeWithNothingMirroredSeesNoBanner() {
        #expect(ScreenMirroring.bannerRoute(isPro: false, isCaptured: false, hasExternalDisplay: false) == nil)
    }

    @Test func freeAndCapturedSeesTheBanner() {
        #expect(ScreenMirroring.bannerRoute(isPro: false, isCaptured: true, hasExternalDisplay: false) == .capture)
    }

    @Test func anExternalDisplayWinsOverACapture() {
        #expect(ScreenMirroring.bannerRoute(isPro: false, isCaptured: false, hasExternalDisplay: true) == .externalDisplay)
        #expect(ScreenMirroring.bannerRoute(isPro: false, isCaptured: true, hasExternalDisplay: true) == .externalDisplay)
    }

    @Test func detectionIsTrackedOncePerSession() {
        var events: [AnalyticsEvent] = []
        let mirroring = ScreenMirroring { events.append($0) }
        mirroring.bannerShown(via: .capture, inChurchMode: false)
        mirroring.bannerShown(via: .externalDisplay, inChurchMode: true)
        mirroring.bannerShown(via: .capture, inChurchMode: true)
        #expect(events.count == 1)
        #expect(events.first?.name == "mirroring_detected")
        #expect(events.first?.properties["via"] as? String == "capture")
        #expect(events.first?.properties["in_church_mode"] as? Bool == false)
    }

    @Test func theMirroringPaywallHasItsOwnSource() {
        #expect(ProFeature.mirroring.analyticsName == "mirroring")
    }
}
