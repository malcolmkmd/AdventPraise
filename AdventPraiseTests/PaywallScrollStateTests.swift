import CoreGraphics
import Testing
@testable import Advent_Praise

/// The paywall's "See everything in Pro" hint: only while there's more below,
/// and gone for good once the words have been scrolled.
struct PaywallScrollStateTests {
    @Test func theHintShowsOnlyWhileThereIsMoreBelow() {
        // Small iPhone: the words run past the fold.
        let small = PaywallScrollState.from(offset: 0, visible: 420, content: 900, scrolled: false)
        #expect(small.moreBelow && !small.scrolled && small.showsHint)
        // iPad: everything fits.
        let large = PaywallScrollState.from(offset: 0, visible: 1100, content: 900, scrolled: false)
        #expect(!large.moreBelow && !large.showsHint)
        // At the end.
        #expect(!PaywallScrollState.from(offset: 480, visible: 420, content: 900, scrolled: false).moreBelow)
    }

    @Test func aScrollHidesTheHintForGood() {
        let scrolled = PaywallScrollState.from(offset: 40, visible: 420, content: 900, scrolled: false)
        #expect(scrolled.moreBelow && scrolled.scrolled && !scrolled.showsHint)
        // Back at the top, it stays hidden.
        let back = PaywallScrollState.from(offset: 0, visible: 420, content: 900, scrolled: scrolled.scrolled)
        #expect(!back.showsHint)
        // A bounce of a few points isn't a scroll.
        #expect(PaywallScrollState.from(offset: 6, visible: 420, content: 900, scrolled: false).showsHint)
    }
}
