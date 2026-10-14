//
//  AdventDrawer.swift
//  Advent Praise
//
//  The app's modal drawer: a floating glass card that rises from the bottom
//  edge and sizes itself to its content (`.fitted`) or to fixed detents.
//
//  One number drives the whole presentation: `extent`, the height of the
//  card's top edge above its resting line. Between detents it is the card's
//  height; below the smallest detent the card keeps that height and slides
//  down instead; above the largest it rubber-bands. The backdrop dim and a
//  small scale follow the same value, so nothing can drift out of step.
//
//  Drags write `extent` directly and releases hand it to a spring carrying
//  the finger's velocity. The animated value is read back every frame
//  (`DrawerProbe`), so the card can be caught mid-flight without a jump.
//
//  Bottom actions sit in a pinned slot under the content. They start hidden
//  and slide in as the content scrolls (or straight away when there is
//  nothing to scroll, or VoiceOver is running). The slot's height is always
//  reserved, so revealing it never moves the content.
//
//  Pages: given a `path`, the drawer pushes and pops pages inside the same
//  card, like the Family wallet. Each page has its own scroller (the root
//  keeps its place underneath), the new one slides in over a cross-fade,
//  and the card springs to the new page's height. Pages sit under a bar the
//  drawer owns (back button and title, a fixed height), so every page starts
//  at the same line and only the card moves. A page that scrolls itself (a
//  board with its own list) `fillsDrawer`: the card goes to its largest.
//  Only the root has the close button; a drag down or a backdrop tap closes
//  from any page, and the path resets.
//
//  The keyboard lifts the card above it, and the card shrinks to fit.
//
//  iOS 26: Liquid Glass. iOS 17–25: Vesper sheet material (`dsGlass`).
//  Reduce Motion: open, close and page changes cross-fade; drags still track the finger.
//

import SwiftUI
import UIKit

// MARK: - API

enum AdventDrawerDetent: Hashable, Sendable {
    /// The content's own height, capped at `.large`.
    case fitted
    /// A fraction of the screen height.
    case fraction(CGFloat)
    /// As tall as the screen allows, below the status bar.
    case large
}

struct AdventDrawerStyle {
    /// The drawer opens at the smallest; drags and VoiceOver can reach the rest.
    var detents: [AdventDrawerDetent] = [.fitted]
    /// Backdrop opacity when fully open. Keep it low where the page behind is a live preview.
    var dimming: Double = 0.36
    /// Forces a reading surface for the drawer (What's New is always the Stage).
    var surface: DSSurface? = nil
    /// Painted over the glass, under the content.
    var background: AnyView? = nil
    /// The colour the action slot fades content into. Defaults to the surface ground.
    var actionScrim: Color? = nil
}

extension View {
    /// Presents a drawer with a pinned bottom action slot.
    func adventDrawer<Content: View, Actions: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        style: AdventDrawerStyle = AdventDrawerStyle(),
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(AdventDrawerPresenter(title: Text(title), isPresented: isPresented,
                                       path: .constant([NoDrawerPage]()), style: style, onDismiss: onDismiss,
                                       drawerContent: content, destination: { _ in EmptyView() }, actions: actions))
    }

    /// Presents a drawer whose pages push and pop inside it. `content` is the
    /// root; `destination` draws each page in `path`, under the drawer's bar
    /// with the page's `drawerTitle`. Pages scroll in the drawer, so screens
    /// shared with a sheet use `DrawerAwareScrollView`.
    func adventDrawer<Page: AdventDrawerPage, Content: View, Destination: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        path: Binding<[Page]>,
        style: AdventDrawerStyle = AdventDrawerStyle(),
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder destination: @escaping (Page) -> Destination
    ) -> some View {
        modifier(AdventDrawerPresenter(title: Text(title), isPresented: isPresented, path: path,
                                       style: style, onDismiss: onDismiss, drawerContent: content,
                                       destination: destination, actions: { EmptyView() }))
    }

    /// Presents a drawer without bottom actions.
    func adventDrawer<Content: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        style: AdventDrawerStyle = AdventDrawerStyle(),
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        adventDrawer(title, isPresented: isPresented, style: style, onDismiss: onDismiss,
                     content: content) { EmptyView() }
    }
}

/// A page pushed inside an AdventDrawer.
protocol AdventDrawerPage: Hashable {
    /// Shown in the drawer's bar, beside the back button.
    var drawerTitle: Text { get }
    /// The page scrolls itself and wants the whole card (`.large`). False by default.
    var fillsDrawer: Bool { get }
}

extension AdventDrawerPage {
    var fillsDrawer: Bool { false }
}

/// The page type of a drawer without pages.
private struct NoDrawerPage: AdventDrawerPage {
    var drawerTitle: Text { Text(verbatim: "") }
}

/// A page's own scroll view, except as a drawer page, where the drawer scrolls it.
struct DrawerAwareScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.drawerScrollsContent) private var drawerScrolls

    var body: some View {
        if drawerScrolls { content } else { ScrollView { content } }
    }
}

extension EnvironmentValues {
    /// True inside an AdventDrawer's scroller.
    @Entry var drawerScrollsContent = false
}

/// Keeps the drawer mounted until its closing animation has finished.
private struct AdventDrawerPresenter<Page: AdventDrawerPage, DrawerContent: View, Destination: View, Actions: View>: ViewModifier {
    let title: Text
    @Binding var isPresented: Bool
    @Binding var path: [Page]
    let style: AdventDrawerStyle
    let onDismiss: (() -> Void)?
    let drawerContent: () -> DrawerContent
    let destination: (Page) -> Destination
    let actions: () -> Actions
    @State private var isMounted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isMounted {
                    AdventDrawer(title: title, isPresented: $isPresented, path: $path, style: style,
                                 onDismissed: {
                                     isMounted = false
                                     // The next opening starts at the root.
                                     if !path.isEmpty { path = [] }
                                     onDismiss?()
                                 },
                                 content: drawerContent, destination: destination, actions: actions)
                        .transition(.identity)
                }
            }
            .onChange(of: isPresented, initial: true) { _, presented in
                if presented { isMounted = true }
            }
    }
}

// MARK: - Drawer

/// The root, or the page at `depth` (1-based) of the path.
private enum DrawerLevel<Page: Hashable>: Hashable {
    case root
    case page(depth: Int, Page)

    var depth: Int {
        switch self {
        case .root: 0
        case .page(let depth, _): depth
        }
    }
}

private struct AdventDrawer<Page: AdventDrawerPage, Content: View, Destination: View, Actions: View>: View {
    let title: Text
    @Binding var isPresented: Bool
    @Binding var path: [Page]
    let style: AdventDrawerStyle
    let onDismissed: () -> Void
    let content: () -> Content
    let destination: (Page) -> Destination
    let actions: () -> Actions

    init(title: Text, isPresented: Binding<Bool>, path: Binding<[Page]>, style: AdventDrawerStyle,
         onDismissed: @escaping () -> Void, content: @escaping () -> Content,
         destination: @escaping (Page) -> Destination, actions: @escaping () -> Actions) {
        self.title = title
        _isPresented = isPresented
        _path = path
        self.style = style
        self.onDismissed = onDismissed
        self.content = content
        self.destination = destination
        self.actions = actions
        _pages = State(initialValue: path.wrappedValue)
    }

    @Environment(\.dsSurface) private var inheritedSurface
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private enum Phase { case measuring, open, closing }

    /// Where `extent` rests when the card is fully off screen (below the bottom edge and its shadow).
    private static var hiddenExtent: CGFloat { -96 }

    @State private var phase = Phase.measuring
    @State private var extent = Self.hiddenExtent
    @State private var fade: Double = 0
    @State private var probe = DrawerProbe()
    @State private var dragStart: CGFloat?
    @State private var detentIndex = 0
    /// Bumped by every animation; a completion only acts if nothing has replaced it.
    @State private var generation = 0
    @State private var container = DrawerContainer()
    /// Per level, so the root keeps its place while a page is on top.
    @State private var scrolls: [DrawerLevel<Page>: DrawerScrollMetrics] = [:]
    @State private var actionHeight: CGFloat = 0
    @State private var actionsLatched = false
    /// The path as shown: follows `path` inside the page animation.
    @State private var pages: [Page]
    /// The card's minimum height on screen. Moves in the same animation as
    /// `extent` when the content changes height, so the two never part.
    @State private var stageFloor: CGFloat = 120
    /// How far the docked keyboard reaches above the bottom of the screen; 0 when it's down.
    @State private var keyboard: CGFloat = 0

    /// The root's actions only; pages have none.
    private var hasActions: Bool { Actions.self != EmptyView.self && pages.isEmpty }
    private var surface: DSSurface { style.surface ?? inheritedSurface }
    private var isOnPage: Bool { !pages.isEmpty }
    /// The top page scrolls itself and takes the whole card.
    private var topFills: Bool { pages.last?.fillsDrawer ?? false }
    private var topLevel: DrawerLevel<Page> {
        pages.last.map { .page(depth: pages.count, $0) } ?? .root
    }
    private var scroll: DrawerScrollMetrics { scrolls[topLevel] ?? DrawerScrollMetrics() }

    var body: some View {
        DrawerStage(extent: extent, fade: fade, floor: stageFloor, cardWidth: cardWidth, bottomInset: bottomGap,
                    dimming: style.dimming, scales: !reduceMotion, probe: probe,
                    onBackdropTap: dismiss, card: card)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: DrawerContainer.self) { proxy in
                DrawerContainer(size: proxy.size, insets: proxy.safeAreaInsets)
            } action: { container = $0 }
            // The screen's own size and insets; the keyboard is `keyboard`.
            .ignoresSafeArea(.keyboard)
            .onChange(of: isPresented) { _, presented in
                presented ? open() : close(velocity: probe.takeCloseVelocity())
            }
            .onChange(of: isMeasured) { _, measured in
                if measured, phase == .measuring, isPresented { open() }
            }
            .task {
                // Content that never reports a size still opens.
                try? await Task.sleep(for: .milliseconds(150))
                if phase == .measuring, isPresented { open() }
            }
            .onChange(of: detentHeights) { _, heights in resnap(to: heights) }
            .onChange(of: actionReveal >= 1) { _, revealed in if revealed { actionsLatched = true } }
            .onChange(of: path) { _, new in show(new) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
                keyboardChanged($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                if keyboard > 0 { withAnimation(.smooth(duration: 0.3)) { keyboard = 0 } }
            }
    }

    // MARK: Card

    private var card: some View {
        let shape = RoundedRectangle.ds(cornerRadius)
        let levels = pages.indices.map { DrawerLevel.page(depth: $0 + 1, pages[$0]) }
        return ZStack(alignment: .top) {
            scroller(.root)
            ForEach(levels, id: \.self) { level in
                scroller(level)
                    .transition(pageTransition)
            }
            chrome
        }
        .background { style.background }
        .clipShape(shape)
        .dsGlass(shape, depth: .sheet)
        .modifier(DrawerSurface(surface: style.surface))
        .allowsHitTesting(phase != .closing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { isOnPage ? back() : dismiss() }
    }

    /// How far a page travels as it comes and goes. The level under it moves the other way.
    private static var pageShift: CGFloat { 44 }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .offset(x: Self.pageShift).combined(with: .opacity)
    }

    @ViewBuilder
    private func levelContent(_ level: DrawerLevel<Page>) -> some View {
        switch level {
        case .root: content()
        case .page(_, let page): destination(page)
        }
    }

    /// A level's view: its scroller, or a page that scrolls itself.
    @ViewBuilder
    private func scroller(_ level: DrawerLevel<Page>) -> some View {
        if case .page(_, let page) = level, page.fillsDrawer {
            levelContent(level)
                .padding(.top, Self.pageBarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .modifier(DrawerLevelPlacement(isTop: level == topLevel, reduceMotion: reduceMotion,
                                               shift: Self.pageShift, depth: level.depth))
        } else {
            scrollingLevel(level)
        }
    }

    private func scrollingLevel(_ level: DrawerLevel<Page>) -> some View {
        let isRoot = level == .root
        return ScrollView {
            levelContent(level)
                .environment(\.drawerScrollsContent, true)
                // Pages start below the bar, all on the same line.
                .padding(.top, isRoot ? 0 : Self.pageBarHeight)
                .frame(maxWidth: .infinity)
                .background {
                    if #available(iOS 18, *) {
                        Color.clear
                    } else {
                        GeometryReader { proxy in
                            Color.clear.preference(key: DrawerContentFrameKey.self,
                                                   value: proxy.frame(in: .named(DrawerContentFrameKey.space)))
                        }
                    }
                }
        }
        .contentMargins(.bottom, bottomPadding(hasActions: isRoot && hasActions), for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isRoot && hasActions { actionSlot }
        }
        .modifier(DrawerScrollTracking(metrics: Binding(get: { scrolls[level] ?? DrawerScrollMetrics() },
                                                        set: { scrolls[level] = $0 })))
        .modifier(DrawerContentPanModifier(shouldBegin: contentPanShouldBegin,
                                           onChanged: dragChanged, onEnded: dragEnded))
        .modifier(DrawerLevelPlacement(isTop: level == topLevel, reduceMotion: reduceMotion,
                                       shift: Self.pageShift, depth: level.depth))
    }

    /// The root: grabber and close button over its content. Pages: a bar of
    /// fixed height with the back button and the page's title, the same for
    /// every page, so nothing under it moves when one replaces another.
    /// The top band (the whole bar, on a page) is a drag handle on every iOS version.
    private var chrome: some View {
        ZStack(alignment: .top) {
            if isOnPage {
                barScrim
            }
            Color.clear
                .frame(height: isOnPage ? Self.pageBarHeight : Self.handleBand)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.primary.opacity(0.28))
                        .frame(width: 36, height: 5)
                        .padding(.top, DS.Space.xs)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { dragChanged($0.translation.height) }
                        .onEnded { dragEnded($0.translation.height, velocity: $0.velocity.height) }
                )
                .accessibilityHidden(true)
            HStack {
                if isOnPage {
                    GlassButton(title: "Back", systemImage: "chevron.left", kind: .icon, action: back)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if !isOnPage {
                    GlassButton(title: "Close", systemImage: "xmark", kind: .icon, action: dismiss)
                        .transition(.opacity)
                }
            }
            .padding(.top, Self.barButtonTop)
            .padding(.horizontal, DS.Space.m)
            if let page = pages.last {
                page.drawerTitle
                    .font(DS.Typeface.rowTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: DS.Size.hitTarget)
                    // Clear of the back button on both sides, so it stays centred.
                    .padding(.horizontal, DS.Size.hitTarget + DS.Space.m + DS.Space.xs)
                    .padding(.top, Self.barButtonTop)
                    .accessibilityAddTraits(.isHeader)
                    .allowsHitTesting(false)
                    .id(topLevel)
                    .transition(.opacity)
            }
        }
        .zIndex(Double(pages.count + 1))
    }

    /// Fades in behind the bar once the page scrolls under it.
    private var barScrim: some View {
        let scrim = style.actionScrim ?? surface.background
        let shown = topFills ? 0 : min(1, max(0, scroll.offset / DS.Space.m))
        return LinearGradient(stops: [.init(color: scrim.opacity(0.92), location: 0),
                                      .init(color: scrim.opacity(0.92), location: 0.6),
                                      .init(color: scrim.opacity(0), location: 1)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: Self.pageBarHeight + DS.Space.m)
            .opacity(shown)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var actionSlot: some View {
        let reveal = actionReveal
        let scrim = style.actionScrim ?? surface.background
        return actions()
            .padding(.bottom, homePadding)
            .background {
                LinearGradient(stops: [.init(color: scrim.opacity(0), location: 0),
                                       .init(color: scrim.opacity(0.88), location: 0.45)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.top, -DS.Space.l)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionHeight = $0 }
            .opacity(reveal)
            .offset(y: reduceMotion ? 0 : (1 - reveal) * 32)
            .allowsHitTesting(reveal > 0.6)
            .accessibilityHidden(reveal < 0.6)
            .animation(DS.Motion.adaptive(DS.Motion.select, reduceMotion: reduceMotion), value: isScrollable)
    }

    // MARK: Geometry

    private static var handleBand: CGFloat { 28 }
    /// The close and back buttons' distance from the card's top edge.
    private static var barButtonTop: CGFloat { DS.Space.s }
    /// A page's bar: the back button and the title. Every page starts under it.
    private static var pageBarHeight: CGFloat { barButtonTop + DS.Size.hitTarget + DS.Space.xs }

    private var isRegular: Bool { sizeClass == .regular }
    private var insets: EdgeInsets { container.insets }
    private var fullHeight: CGFloat { container.size.height + insets.top + insets.bottom }
    private var fullWidth: CGFloat { container.size.width + insets.leading + insets.trailing }
    private var hasHomeIndicator: Bool { insets.bottom > 0 }

    private var bottomInset: CGFloat { isRegular ? max(DS.Space.l, insets.bottom) : DS.Space.s }
    /// The card's distance from the bottom of the screen: above the keyboard while it's up.
    private var bottomGap: CGFloat { keyboard > 0 ? keyboard + DS.Space.s : bottomInset }
    private var sideInset: CGFloat { isRegular ? 24 : max(DS.Space.s, insets.leading, insets.trailing) }
    private var cardWidth: CGFloat { max(0, min(fullWidth - sideInset * 2, isRegular ? 540 : 600)) }
    private var cornerRadius: CGFloat { isRegular ? 34 : (hasHomeIndicator ? 44 : 28) }
    /// Keeps the last line and the buttons clear of the home indicator.
    private var homePadding: CGFloat {
        keyboard > 0 ? DS.Space.l : max(DS.Space.l, insets.bottom - bottomInset + DS.Space.s)
    }
    private func bottomPadding(hasActions: Bool) -> CGFloat { hasActions ? DS.Space.m : homePadding }
    private var maxHeight: CGFloat {
        max(160, fullHeight - insets.top - (isRegular ? 24 : 10) - bottomGap)
    }

    /// Everything the content needs to show without scrolling. A page that
    /// scrolls itself needs the whole card.
    private var requiredHeight: CGFloat {
        if topFills { return maxHeight }
        return scroll.contentHeight + bottomPadding(hasActions: hasActions) + (hasActions ? actionHeight : 0)
    }

    /// The top level's height is known (a filling page needs no measuring).
    private var isMeasured: Bool { topFills || scroll.contentHeight > 0 }

    private func height(of detent: AdventDrawerDetent) -> CGFloat {
        switch detent {
        case .fitted: min(maxHeight, requiredHeight)
        case .fraction(let f): min(maxHeight, fullHeight * f)
        case .large: maxHeight
        }
    }

    /// Detent heights, smallest first, near-duplicates merged.
    private var detentHeights: [CGFloat] {
        let sorted = (style.detents.isEmpty ? [.fitted] : style.detents)
            .map { max(120, height(of: $0)) }
            .sorted()
        return sorted.reduce(into: []) { result, h in
            if let last = result.last, h - last < 2 { return }
            result.append(h)
        }
    }

    private var floor: CGFloat { detentHeights.first ?? 120 }
    private var restingHeight: CGFloat {
        let heights = detentHeights
        return heights[min(detentIndex, heights.count - 1)]
    }

    /// True when some content is out of sight. Overflow that is only the
    /// reserved action slot doesn't count: there would be nothing to scroll to.
    private var isScrollable: Bool {
        requiredHeight - (hasActions ? actionHeight : 0) > restingHeight + 0.5
    }

    /// 0 = hidden, 1 = shown. Driven by how far the content has scrolled.
    private var actionReveal: Double {
        if voiceOver || actionsLatched || !isScrollable { return 1 }
        let distance = min(56, requiredHeight - restingHeight)
        guard distance > 0 else { return 1 }
        return Double(min(1, max(0, scroll.offset / distance)))
    }

    // MARK: Presentation

    private func open() {
        let heights = detentHeights
        if phase == .measuring {
            detentIndex = voiceOver ? heights.count - 1 : 0
        }
        let target = heights[min(detentIndex, heights.count - 1)]
        let wasMeasuring = phase == .measuring
        phase = .open
        generation += 1
        setWithoutAnimation { stageFloor = heights.first ?? target }
        if reduceMotion {
            if wasMeasuring { setWithoutAnimation { extent = target } }
            withAnimation(.easeInOut(duration: 0.25)) { fade = 1 }
        } else {
            if wasMeasuring { setWithoutAnimation { fade = 1 } }
            withAnimation(spring(to: target, velocity: 0, bounce: 0.18)) { extent = target }
        }
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    private func close(velocity: CGFloat = 0) {
        guard phase != .closing else { return }
        if phase == .measuring {
            onDismissed()
            return
        }
        phase = .closing
        dragStart = nil
        generation += 1
        let token = generation
        let finish = {
            guard token == generation, phase == .closing else { return }
            onDismissed()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2), completionCriteria: .removed) { fade = 0 } completion: { finish() }
        } else {
            withAnimation(spring(to: Self.hiddenExtent, velocity: velocity, bounce: 0),
                          completionCriteria: .removed) {
                extent = Self.hiddenExtent
            } completion: { finish() }
        }
    }

    private func dismiss() {
        isPresented = false
    }

    /// Content, page or screen size changed: follow the detent we're resting on.
    /// A page not yet measured keeps the card where it is until it is.
    private func resnap(to heights: [CGFloat]) {
        guard phase == .open, dragStart == nil, isMeasured else { return }
        detentIndex = min(detentIndex, heights.count - 1)
        let target = heights[detentIndex]
        let floor = heights.first ?? target
        guard abs(target - extent) > 0.5 || abs(floor - stageFloor) > 0.5 else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : spring(to: target, velocity: 0, bounce: 0.1)) {
            extent = target
            stageFloor = floor
        }
    }

    // MARK: Pages

    /// Shows `newPath`: the arriving page slides in, the card follows its height.
    private func show(_ newPath: [Page]) {
        guard newPath != pages else { return }
        // Measurements of levels that are leaving; a page pushed again is measured afresh.
        let kept = zip(pages, newPath).prefix { $0 == $1 }.count
        for index in pages.indices.dropFirst(kept) {
            scrolls[.page(depth: index + 1, pages[index])] = nil
        }
        if phase == .open { Haptics.play(.selection) }
        // The height follows through `detentHeights`: at once for a level
        // already measured, as soon as it is for a new page.
        withAnimation(DS.Motion.adaptive(.smooth(duration: 0.36), reduceMotion: reduceMotion)) {
            pages = newPath
        }
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    /// One page back, toward the root.
    private func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    // MARK: Keyboard

    /// A docked keyboard lifts the card; a floating or split one (iPad) doesn't.
    private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let docked = frame.maxY >= fullHeight - 1 && frame.width >= fullWidth - 1
        let overlap = docked ? max(0, fullHeight - frame.minY) : 0
        guard abs(overlap - keyboard) > 0.5 else { return }
        withAnimation(.smooth(duration: 0.3)) { keyboard = overlap }
    }

    // MARK: Dragging

    /// `translation` is downward-positive, in screen points.
    private func dragChanged(_ translation: CGFloat) {
        guard phase == .open else { return }
        if dragStart == nil {
            // Catch the card where it is on screen, not where its animation was heading.
            dragStart = probe.extent
            generation += 1
            Haptics.prepare(.softImpact)
        }
        let raw = (dragStart ?? extent) - translation
        let top = detentHeights.last ?? floor
        let next: CGFloat = if raw > top {
            top + rubberBand(raw - top)
        } else {
            max(Self.hiddenExtent, raw)
        }
        setWithoutAnimation { extent = next }
    }

    private func dragEnded(_ translation: CGFloat, velocity: CGFloat) {
        guard dragStart != nil, phase == .open else { return }
        dragChanged(translation)
        dragStart = nil
        let heights = detentHeights
        let current = extent
        // A flick moves one stop in its direction; a slow release settles on the nearest stop.
        let stops = [Self.hiddenExtent] + heights
        let target: CGFloat
        if velocity > 350 {
            target = stops.filter { $0 < current - 1 }.max() ?? Self.hiddenExtent
        } else if velocity < -350 {
            target = stops.filter { $0 > current + 1 }.min() ?? heights.last ?? floor
        } else if current < floor * 0.55 {
            target = Self.hiddenExtent
        } else {
            target = heights.min { abs($0 - current) < abs($1 - current) } ?? floor
        }

        // A drag ending on a new detent, or dismissing, is felt; the close
        // button and backdrop tap aren't (a tap needs no confirmation).
        guard target != Self.hiddenExtent, let index = heights.firstIndex(of: target) else {
            probe.closeVelocity = velocity
            Haptics.play(.softImpact)
            isPresented = false
            return
        }
        if index != detentIndex { Haptics.play(.softImpact) }
        detentIndex = index
        generation += 1
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : spring(to: target, velocity: velocity, bounce: 0.14)) {
            extent = target
            stageFloor = heights.first ?? target
        }
    }

    /// Content drags (iOS 18+) only take over at the top of the scroll:
    /// down to shrink or dismiss, up while a taller detent remains.
    private func contentPanShouldBegin(_ velocity: CGFloat) -> Bool {
        guard phase == .open, scroll.offset <= 0.5 else { return false }
        return velocity > 0 || detentIndex < detentHeights.count - 1
    }

    /// UIScrollView's rubber band: resistance grows with distance, never past `limit`.
    private func rubberBand(_ distance: CGFloat, limit: CGFloat = 90) -> CGFloat {
        (1 - 1 / (distance * 0.55 / limit + 1)) * limit
    }

    /// A spring that starts at the finger's speed. `velocity` is downward-positive points per second.
    private func spring(to target: CGFloat, velocity: CGFloat, bounce: Double) -> Animation {
        let distance = target - probe.extent
        let relative = abs(distance) < 1 ? 0 : min(20, max(-20, -velocity / distance))
        return .interpolatingSpring(duration: 0.46, bounce: bounce, initialVelocity: relative)
    }

    private func setWithoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}

// MARK: - Stage

/// Draws the backdrop and places the card from the animated `extent` and `floor`.
/// Animatable, so its body runs every frame and can report the on-screen value.
private struct DrawerStage<Card: View>: View, Animatable {
    var extent: CGFloat
    var fade: Double
    var floor: CGFloat
    let cardWidth: CGFloat
    let bottomInset: CGFloat
    let dimming: Double
    let scales: Bool
    let probe: DrawerProbe
    let onBackdropTap: () -> Void
    let card: Card

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
        get { AnimatablePair(AnimatablePair(extent, floor), fade) }
        set { extent = newValue.first.first; floor = newValue.first.second; fade = newValue.second }
    }

    var body: some View {
        let _ = probe.record(extent)
        let progress = floor > 0 ? min(1, max(0, extent / floor)) : 0
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(dimming * progress * fade)
                .contentShape(Rectangle())
                .onTapGesture(perform: onBackdropTap)
                .accessibilityHidden(true)
            card
                .frame(width: cardWidth, height: max(floor, extent))
                .scaleEffect(scales ? 0.94 + 0.06 * progress : 1, anchor: .bottom)
                .offset(y: max(0, floor - extent))
                .opacity(fade)
                .padding(.bottom, bottomInset)
        }
        .ignoresSafeArea()
    }
}

/// The value the card is actually showing, written each frame by `DrawerStage`.
@MainActor
private final class DrawerProbe {
    private(set) var extent: CGFloat = 0
    /// The release velocity of a dismissing swipe, handed to the close spring.
    var closeVelocity: CGFloat = 0
    func record(_ value: CGFloat) { extent = value }
    func takeCloseVelocity() -> CGFloat {
        defer { closeVelocity = 0 }
        return closeVelocity
    }
}

private struct DrawerContainer: Equatable {
    var size: CGSize = .zero
    var insets = EdgeInsets()
}

/// Levels under the top one step aside and wait, keeping their scroll.
private struct DrawerLevelPlacement: ViewModifier {
    let isTop: Bool
    let reduceMotion: Bool
    let shift: CGFloat
    let depth: Int

    func body(content: Content) -> some View {
        content
            .opacity(isTop ? 1 : 0)
            .offset(x: isTop || reduceMotion ? 0 : -shift)
            .allowsHitTesting(isTop)
            .accessibilityHidden(!isTop)
            .zIndex(Double(depth))
    }
}

/// Applies a forced surface to the drawer chrome and content.
private struct DrawerSurface: ViewModifier {
    let surface: DSSurface?
    func body(content: Content) -> some View {
        if let surface {
            content.dsSurface(surface, paintsBackground: false)
        } else {
            content
        }
    }
}

// MARK: - Scroll tracking

private struct DrawerScrollMetrics: Equatable {
    /// Distance scrolled from the top; 0 at rest.
    var offset: CGFloat = 0
    /// Height of the content alone, without margins or the action slot.
    var contentHeight: CGFloat = 0
}

/// iOS 17 fallback: the content's frame in the scroll view's coordinate space.
private struct DrawerContentFrameKey: PreferenceKey {
    static let space = "AdventDrawer.scroll"
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

private struct DrawerScrollTracking: ViewModifier {
    @Binding var metrics: DrawerScrollMetrics

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: DrawerScrollMetrics.self) { geometry in
                DrawerScrollMetrics(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                                    contentHeight: geometry.contentSize.height)
            } action: { _, new in                metrics = new
            }
        } else {
            content
                .coordinateSpace(.named(DrawerContentFrameKey.space))
                .onPreferenceChange(DrawerContentFrameKey.self) { frame in
                    metrics = DrawerScrollMetrics(offset: -frame.minY, contentHeight: frame.height)
                }
        }
    }
}

// MARK: - Content pan (iOS 18+)

/// Lets a drag on the scrolling content move the drawer when the content is at
/// its top. iOS 17 drags by the handle band only.
private struct DrawerContentPanModifier: ViewModifier {
    let shouldBegin: (CGFloat) -> Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.gesture(DrawerContentPan(shouldBegin: shouldBegin, onChanged: onChanged, onEnded: onEnded))
        } else {
            content
        }
    }
}

@available(iOS 18, *)
private struct DrawerContentPan: UIGestureRecognizerRepresentable {
    let shouldBegin: (CGFloat) -> Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.shouldBegin = shouldBegin
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let space = recognizer.view?.window
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: space)
            onChanged(0)
        case .changed:
            onChanged(recognizer.translation(in: space).y)
        case .ended:
            onEnded(recognizer.translation(in: space).y, recognizer.velocity(in: space).y)
        case .cancelled, .failed:
            onEnded(recognizer.translation(in: space).y, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var shouldBegin: (CGFloat) -> Bool = { _ in false }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.y) > abs(velocity.x) && shouldBegin(velocity.y)
        }

        /// The scroll view waits for this pan to decline, so the two never move together.
        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other is UIPanGestureRecognizer && other.view is UIScrollView
        }
    }
}
