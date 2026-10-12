//
//  BalancedText.swift
//  Advent Praise 7 — Vesper design system
//
//  Centered text that wraps into lines of even length, like CSS
//  `text-wrap: balance`. A wrapped title or lyric line takes the narrowest
//  width that still needs no more lines than the full width does, so
//  "Come, Thou Fount Of / Every Blessing" becomes "Come, Thou Fount /
//  Of Every Blessing" and a lyric never leaves one word alone on a line.
//

import SwiftUI

/// Lays out one child (a `Text`) at its balanced width. Text that fits on one
/// line is left alone.
struct BalancedWrap: Layout {
    /// Measured widths keyed by the width offered, so scrolling doesn't re-measure.
    struct Cache { var widths: [CGFloat: CGFloat] = [:] }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache.widths = [:] }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard let text = subviews.first else { return .zero }
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return text.sizeThatFits(proposal)
        }
        let balanced = balancedWidth(text, in: width, cache: &cache)
        return text.sizeThatFits(ProposedViewSize(width: balanced, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let text = subviews.first else { return }
        let width = balancedWidth(text, in: bounds.width, cache: &cache)
        text.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                   proposal: ProposedViewSize(width: width, height: bounds.height))
    }

    /// The narrowest width (to a point) that keeps the height the full width gives.
    private func balancedWidth(_ text: LayoutSubview, in width: CGFloat, cache: inout Cache) -> CGFloat {
        if let known = cache.widths[width] { return known }
        let natural = text.sizeThatFits(.unspecified).width
        guard natural > width else {
            cache.widths[width] = min(natural, width)
            return min(natural, width)
        }
        let height = text.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        // Balanced lines are never under half the width for two lines, less for more.
        var low = width * 0.35, high = width
        while high - low > 1 {
            let mid = (low + high) / 2
            if text.sizeThatFits(ProposedViewSize(width: mid, height: nil)).height > height + 0.5 {
                low = mid
            } else {
                high = mid
            }
        }
        cache.widths[width] = high.rounded(.up)
        return high.rounded(.up)
    }
}

extension View {
    /// Balanced line lengths when `isOn`; otherwise the view as it is.
    @ViewBuilder
    func dsBalancedWrap(_ isOn: Bool = true) -> some View {
        if isOn {
            BalancedWrap { self.multilineTextAlignment(.center) }
        } else {
            self
        }
    }
}

#Preview("Balanced wrap") {
    VStack(spacing: DS.Space.l) {
        Text("Come, Thou Fount Of Every Blessing").font(DS.Typeface.hymnTitle)
            .multilineTextAlignment(.center)
        Text("Come, Thou Fount Of Every Blessing").font(DS.Typeface.hymnTitle)
            .dsBalancedWrap()
    }
    .frame(width: 340)
    .padding()
}
