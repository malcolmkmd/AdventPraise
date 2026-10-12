//
//  HymnHeaderMorph.swift
//  Advent Praise
//
//  The reader's scroll-driven header. At rest the number and title sit large
//  at the top of the text; as the text scrolls they shrink, lift and fade
//  into a compact capsule pinned in the navigation bar, number and title
//  side by side, whose glass fades in behind them. Scrolling back reverses
//  it exactly: everything is a function of the scroll offset.
//
//  Only two small views read the progress — the large header's effect
//  modifier and the compact header — so scrolling never re-renders the
//  reader. Both move by scale, offset and opacity (no layout); the compact
//  header's weight steps are the one text change, and it sits in a
//  fixed-size slot, so nothing else re-lays out.
//

import SwiftUI
import UIKit

/// How far the header has collapsed: 0 at rest, 1 once the large title has
/// scrolled away. A class, so the reader itself never observes it.
@MainActor @Observable
final class HeaderMorph {
    private(set) var progress: CGFloat = 0
    /// Faded out while the hymn is paged away, so the old title doesn't
    /// linger over the incoming hymn.
    var isHidden = false
    /// The scroll distance over which the header collapses: the large
    /// header's height, so the compact one lands as the title leaves.
    @ObservationIgnored var range: CGFloat = 120

    /// Past this, Reduce Motion shows the compact header (a crossfade, not a morph).
    var isCollapsed: Bool { progress > 0.6 }

    /// `distance` is how far the text has scrolled from the top.
    func update(distance: CGFloat) {
        let p = min(max(distance / max(range, 1), 0), 1)
        // Inside the text, scrolling leaves this at 1 and nothing updates.
        guard abs(p - progress) > 0.002 || (p != progress && (p == 0 || p == 1)) else { return }
        progress = p
    }
}

// MARK: - Tracking the scroll

extension View {
    /// On the ScrollView, iOS 18+: feeds the distance scrolled into `morph`
    /// from the scroll geometry.
    func trackingHeaderMorph(_ morph: HeaderMorph) -> some View {
        modifier(HeaderMorphTracking(morph: morph))
    }

    /// On the scroll content (before any offset), iOS 17: the content's top
    /// in the scroll view's coordinates, which is 0 at rest (insets already
    /// applied) and minus the distance scrolled after.
    func headerMorphContentProbe(_ morph: HeaderMorph) -> some View {
        modifier(HeaderMorphContentProbe(morph: morph))
    }
}

private var usesScrollGeometry: Bool {
    if #available(iOS 18, *) { !HeaderMorphDebug.forcesLegacyTracking } else { false }
}

private struct HeaderMorphTracking: ViewModifier {
    let morph: HeaderMorph

    func body(content: Content) -> some View {
        if #available(iOS 18, *), usesScrollGeometry {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, distance in
                morph.update(distance: distance)
            }
        } else {
            content
        }
    }
}

private struct HeaderMorphContentProbe: ViewModifier {
    let morph: HeaderMorph

    func body(content: Content) -> some View {
        if usesScrollGeometry {
            content
        } else {
            content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { y in
                morph.update(distance: -y)
            }
        }
    }
}

enum HeaderMorphDebug {
    /// DEBUG `-uiDebugLegacyHeader YES`: the iOS 17 tracking path on any OS.
    static var forcesLegacyTracking: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "uiDebugLegacyHeader")
        #else
        false
        #endif
    }
}

extension View {
    /// A custom title view switches the iOS 26 bar to its hard edge (an
    /// opaque band and hairline). The reader keeps the soft fade; the compact
    /// header's own glass is the only backdrop.
    @ViewBuilder func softTopScrollEdge() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

#if DEBUG
extension View {
    /// DEBUG `-uiDebugScroll 80`: opens the reader scrolled this far, for
    /// screenshots of the header part-way and fully collapsed.
    @ViewBuilder func debugScrollOffset() -> some View {
        if #available(iOS 18, *), let y = DebugLaunch.scrollY {
            modifier(DebugScrollOffset(y: y))
        } else {
            self
        }
    }
}

@available(iOS 18, *)
private struct DebugScrollOffset: ViewModifier {
    let y: CGFloat
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .task {
                try? await Task.sleep(for: .milliseconds(800))
                position.scrollTo(y: y)
            }
    }
}
#endif

// MARK: - The large header

/// Shrinks, lifts and fades the large header toward the bar as it collapses.
/// Only this modifier's body reads the progress; the header inside it isn't
/// re-evaluated while scrolling.
struct HeaderCollapseEffect: ViewModifier {
    let morph: HeaderMorph
    let centered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // It scrolls away as it is; the compact header crossfades in.
            content
        } else {
            let p = morph.progress
            content
                .scaleEffect(1 - 0.14 * ease(p), anchor: centered ? .top : .topLeading)
                // Moves up a little faster than the text, toward the bar.
                .offset(y: -10 * ease(p))
                // Mostly gone by the time the title passes under the bar,
                // where the compact header is arriving.
                .opacity(1 - smoothstep(0.15, 0.75, p))
        }
    }
}

// MARK: - The compact header

/// Number and title side by side in one line, pinned in the navigation bar.
/// Left-aligned text puts it at the leading edge, centred text centres it.
struct CompactHymnHeader: View {
    let morph: HeaderMorph
    let number: Int
    let title: String
    let centered: Bool
    var onTap: () -> Void = {}

    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Reduce Motion: on or off past the midpoint, crossfaded.
        let t = reduceMotion ? (morph.isCollapsed ? 1 : 0) : smoothstep(0.45, 0.95, morph.progress)
        let shown = morph.isHidden ? 0 : t
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            Text(verbatim: String(number))
                .font(font(weight: t))
                .monospacedDigit()
                .foregroundStyle(surface.brass)
            Text(title)
                .font(font(weight: t))
                .foregroundStyle(surface.foreground)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.vertical, DS.Space.xs)
        .frame(minHeight: 36)
        .background {
            Capsule().fill(.clear)
                .dsGlass(Capsule(), depth: .capsule)
                .opacity(smoothstep(0.7, 1, t))
        }
        .scaleEffect(reduceMotion ? 1 : 1.08 - 0.08 * t, anchor: centered ? .center : .leading)
        .offset(y: reduceMotion ? 0 : 8 * (1 - t))
        .opacity(shown)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : nil, value: morph.isCollapsed)
        .animation(.easeOut(duration: 0.16), value: morph.isHidden)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        // The bar's height is fixed; past this size the title would clip.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .allowsHitTesting(shown > 0.5)
        // The large header, still in the text, is the element VoiceOver reads.
        .accessibilityHidden(true)
    }

    /// New York at the headline size, its weight carried from regular (as it
    /// arrives) to semibold (once it has landed). The system face is variable,
    /// so any weight in between is real; the steps are quantised so the line
    /// re-lays out a dozen times per collapse, not every frame.
    private func font(weight t: CGFloat) -> Font {
        let steps: CGFloat = 12
        let q = (t * steps).rounded() / steps
        let regular = UIFont.Weight.regular.rawValue, semibold = UIFont.Weight.semibold.rawValue
        let weight = UIFont.Weight(rawValue: regular + (semibold - regular) * q)
        let category = UIContentSizeCategory(dynamicTypeSize)
        let size = UIFont.preferredFont(forTextStyle: .headline,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}

// MARK: - Curves

/// 0 below `a`, 1 above `b`, an S-curve between.
private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

/// Ease-out: quick at first, settling into place.
private func ease(_ t: CGFloat) -> CGFloat { 1 - (1 - t) * (1 - t) }
