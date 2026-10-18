//
//  SheetMusicView.swift
//  Advent Praise
//
//  The open hymn's sheet music, from the Music tile in the Lectern's tray,
//  full screen on iPhone and iPad. The page is vector (SheetMusicCatalog):
//  the phone width in portrait, the pad width once the music has 700 pt
//  (iPad, and an iPhone on its side). It is inked in the reading surface's
//  text colour, so Paper and Parchment read dark on light and Muted and Black
//  light on dark. Pinch or double-tap to zoom; a tap hides the controls and
//  the status bar for the music alone, and another brings them back.
//
//  While the accompaniment plays this hymn, the page follows it, as the
//  reader's lyrics do: the measure, the melody note and the syllable of the
//  verse being sung are marked, the page scrolls to keep them in view, and a
//  tap on a measure plays from there (SheetMusicTiming). That needs the
//  player unlocked (Pro or MIDI), as playing does.
//
//  Sheet music is Pro. Hymn of the Day's is free for everyone, every day.
//  Anyone else sees the top of the page and a Pro button; the paywall opens
//  over this screen (ProFeature.sheetMusic) and, once Pro is bought, the
//  whole page shows without leaving.
//

import SwiftUI
import WebKit

/// How the sheet music was opened, for analytics and for what's shown.
enum SheetMusicAccess: String, Sendable {
    case pro
    /// Free for everyone: today's Hymn of the Day.
    case hymnOfTheDay = "hymn_of_the_day"
    /// Not Pro: the top of the page and a way to Pro.
    case preview

    static func resolve(isPro: Bool, isHymnOfTheDay: Bool) -> SheetMusicAccess {
        if isPro { return .pro }
        return isHymnOfTheDay ? .hymnOfTheDay : .preview
    }

    var showsWholePage: Bool { self != .preview }
}

/// What the page marks while the accompaniment plays, in the page's SVG units.
struct SheetMusicHighlight: Equatable, Sendable {
    var measure: SheetMusicTiming.Box?
    /// Centre and radius of the mark on the melody note.
    var note: (x: Double, y: Double, r: Double)?
    var syllable: SheetMusicTiming.Box?

    static let none = SheetMusicHighlight()

    static func == (a: SheetMusicHighlight, b: SheetMusicHighlight) -> Bool {
        a.measure == b.measure && a.syllable == b.syllable
            && a.note?.x == b.note?.x && a.note?.y == b.note?.y && a.note?.r == b.note?.r
    }

    /// The marks for `cue` on a page drawn with `geometry`.
    init(cue: SheetMusicTiming.Cue, geometry: SheetMusicTiming.Geometry) {
        let space = geometry.staffSpace
        if geometry.measures.indices.contains(cue.measure) {
            let box = geometry.measures[cue.measure]
            measure = .init(x: box.x - space * 0.4, y: box.y - space * 1.6,
                            width: box.width + space * 0.8, height: box.height + space * 3.2)
        }
        if let n = cue.note, geometry.notes.indices.contains(n) {
            let head = geometry.notes[n]
            note = (head.x + space * 0.6, head.y, space * 1.05)
        }
        if let n = cue.syllableNote, let line = cue.syllableLine, geometry.notes.indices.contains(n),
           let syllable = geometry.notes[n].syllables.first(where: { $0.line == line }) {
            self.syllable = .init(x: syllable.x - syllable.size * 0.18, y: syllable.y - syllable.size * 0.86,
                                  width: syllable.width + syllable.size * 0.36, height: syllable.size * 1.14)
        }
    }

    init(measure: SheetMusicTiming.Box? = nil, note: (x: Double, y: Double, r: Double)? = nil,
         syllable: SheetMusicTiming.Box? = nil) {
        self.measure = measure
        self.note = note
        self.syllable = syllable
    }

    /// For the page's script: `{"m": {...}, "n": {...}, "s": {...}}`, null for a mark not shown.
    var script: String {
        func rect(_ b: SheetMusicTiming.Box?) -> String {
            guard let b else { return "null" }
            return String(format: "{\"x\":%.1f,\"y\":%.1f,\"width\":%.1f,\"height\":%.1f}", b.x, b.y, b.width, b.height)
        }
        let dot = note.map { String(format: "{\"cx\":%.1f,\"cy\":%.1f,\"r\":%.1f}", $0.x, $0.y, $0.r) } ?? "null"
        return "{\"m\":\(rect(measure)),\"n\":\(dot),\"s\":\(rect(syllable))}"
    }
}

struct SheetMusicView: View {
    let hymnal: Hymnal
    let hymn: Hymn

    @Environment(PurchaseStore.self) private var store
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(\.dsSurface) private var surface
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var paywall: ProFeature?
    @State private var pages: [SheetMusicLayout: SheetMusicPage] = [:]
    @State private var unreadable: Set<SheetMusicLayout> = []
    @State private var timing: SheetMusicTiming?
    @State private var tracked = false
    @State private var controlsVisible = true

    /// A preview shows this much of the page, at most.
    static let previewFraction = 0.45
    /// The close button's row.
    static let barHeight: CGFloat = 56

    private var isHymnOfTheDay: Bool {
        HymnOfTheDayFeed.hymn(on: .now, in: hymnal)?.id == hymn.id
    }

    private var access: SheetMusicAccess {
        SheetMusicAccess.resolve(isPro: store.unlocks(.sheetMusic), isHymnOfTheDay: isHymnOfTheDay)
    }

    /// The controls stay up for a preview (its Pro button) and with VoiceOver.
    private var showsControls: Bool { controlsVisible || !access.showsWholePage || voiceOver }

    /// Playing from here and following along need the player unlocked, like the Lectern's play.
    private var canFollow: Bool {
        access.showsWholePage && store.isPlayerUnlocked && hymn.hasAccompaniment && player.isAvailable && timing != nil
    }

    /// The accompaniment is on this hymn, playing or paused part-way.
    private var following: Bool { canFollow && player.isActive && player.hymn == hymn }

    private var passOffset: Double? {
        SheetMusicTiming.passOffset(elapsed: player.elapsed, duration: player.duration, passes: player.passCount)
    }

    private func highlight(_ layout: SheetMusicLayout) -> SheetMusicHighlight {
        guard following, let timing, let offset = passOffset, let geometry = timing.geometry[layout] else { return .none }
        return SheetMusicHighlight(cue: timing.cue(at: offset, verse: player.position?.verse), geometry: geometry)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = SheetMusicLayout.forWidth(geometry.size.width)
            let insets = geometry.safeAreaInsets
            ZStack(alignment: .top) {
                if let page = pages[layout] {
                    if access.showsWholePage {
                        SheetMusicPageView(page: page, ink: surface.sheetMusicInk, accent: surface.sheetMusicAccent,
                                           preview: false,
                                           topInset: insets.top + Self.barHeight, bottomInset: insets.bottom + DS.Space.l,
                                           highlight: highlight(layout), follows: following && player.isPlaying,
                                           onTap: { point in tapped(point, layout: layout) })
                            .accessibilityLabel(Text("Sheet music for hymn \(hymn.id, format: .hymnNumber), \(hymn.title)"))
                            .ignoresSafeArea(.container, edges: .vertical)
                    } else {
                        // The top of the page fades into the Pro button right under it.
                        VStack(spacing: 0) {
                            Color.clear.frame(height: Self.barHeight)
                            SheetMusicPageView(page: page, ink: surface.sheetMusicInk, accent: surface.sheetMusicAccent,
                                               preview: true, topInset: 0, bottomInset: 0,
                                               highlight: .none, follows: false, onTap: { _ in })
                                .accessibilityLabel(Text("Sheet music for hymn \(hymn.id, format: .hymnNumber), \(hymn.title)"))
                                .frame(height: min(geometry.size.width * page.height / max(page.width, 1) * Self.previewFraction + 32,
                                                   geometry.size.height * 0.7))
                            proBar
                            Spacer(minLength: 0)
                        }
                    }
                } else if unreadable.contains(layout) {
                    ContentUnavailableView("No sheet music", systemImage: "music.note",
                                           description: Text("This hymn’s sheet music couldn’t be opened."))
                        .frame(maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if showsControls {
                    topBar.transition(.opacity)
                }
            }
            .task(id: layout) {
                guard pages[layout] == nil else { return }
                let hymnalID = hymnal.id, number = hymn.id
                let page = await Task.detached(priority: .userInitiated) {
                    SheetMusicCatalog.page(hymnal: hymnalID, number: number, layout: layout)
                }.value
                if let page { pages[layout] = page } else { unreadable.insert(layout) }
            }
        }
        .task {
            let hymnalID = hymnal.id, number = hymn.id
            timing = await Task.detached(priority: .utility) {
                SheetMusicCatalog.timing(hymnal: hymnalID, number: number)
            }.value
        }
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsControls)
        .accessibilityAction(.escape) { dismiss() }
        .analyticsScreen(.sheetMusic)
        .onAppear {
            guard !tracked else { return }
            tracked = true
            Analytics.track(.sheetMusicOpened(number: hymn.id, access: access))
            #if DEBUG
            if DebugLaunch.sheetMusicControlsHidden { controlsVisible = false }
            #endif
        }
        #if DEBUG
        .task {
            guard DebugLaunch.sheetMusicPaywall else { return }
            try? await Task.sleep(for: .seconds(0.8))
            paywall = .sheetMusic
        }
        #endif
        .proPaywall(feature: $paywall, context: .sheetMusic)
    }

    /// A tap on the music: on a measure while the accompaniment is on this
    /// hymn, play from there; anywhere else, hide or show the controls.
    private func tapped(_ point: CGPoint?, layout: SheetMusicLayout) {
        if following, let point, let timing, let offset = passOffset,
           let measure = timing.measure(atX: point.x, y: point.y, layout: layout),
           let target = timing.seekOffset(toMeasure: measure, from: offset) {
            let pass = SheetMusicTiming.passIndex(elapsed: player.elapsed, duration: player.duration, passes: player.passCount)
            player.seek(to: Double(pass) * player.duration / Double(max(player.passCount, 1)) + target)
            return
        }
        controlsVisible.toggle()
    }

    private func togglePlay() {
        if player.hymn == hymn, player.isActive {
            player.toggle()
        } else {
            player.start(hymn, source: hymnal.name)
        }
    }

    private var isPlayingHere: Bool { player.isPlaying && player.hymn == hymn }

    private var topBar: some View {
        HStack(spacing: DS.Space.m) {
            GlassButton(title: "Close", systemImage: "xmark", kind: .icon) { dismiss() }
                .accessibilityIdentifier("sheetMusic.close")
            VStack(alignment: .leading, spacing: 1) {
                Text("\(hymn.id, format: .hymnNumber) · \(hymn.title)")
                    .font(DS.Typeface.detail.weight(.semibold))
                    .lineLimit(1)
                if access == .hymnOfTheDay {
                    Label("Hymn of the Day: free for everyone today", systemImage: "sun.max")
                        .font(DS.Typeface.caption)
                        .foregroundStyle(surface.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if canFollow {
                GlassButton(title: isPlayingHere ? "Pause" : "Play",
                            systemImage: isPlayingHere ? "pause.fill" : "play.fill", kind: .icon) { togglePlay() }
                    .accessibilityIdentifier("sheetMusic.play")
            }
        }
        .padding(.horizontal, DS.Space.l)
        .frame(height: Self.barHeight)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // The music scrolls under the controls, fading out behind them.
            LinearGradient(stops: [.init(color: surface.background, location: 0),
                                   .init(color: surface.background.opacity(0.92), location: 0.7),
                                   .init(color: surface.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -DS.Space.m)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private var proBar: some View {
        VStack(spacing: DS.Space.s) {
            Text("Sheet music for \(SheetMusicCatalog.count(hymnal: hymnal.id)) hymns comes with Pro. Hymn of the Day’s is free every day.")
                .font(DS.Typeface.caption)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            GlassButton(title: "See the whole page with Pro", systemImage: "music.note.list",
                        tint: surface.brass, fullWidth: true) {
                Analytics.track(.sheetMusicPaywallOpened(number: hymn.id))
                paywall = .sheetMusic
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.s)
        .padding(.bottom, DS.Space.l)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page

/// The SVG in a transparent web view: inked with CSS `color`, pinch or
/// double-tap to zoom, a tap reported in page (SVG) units. The whole page
/// runs under the controls, padded so its top clears them. A preview shows
/// the top of the page and doesn't scroll, zoom or take taps.
private struct SheetMusicPageView: UIViewRepresentable {
    let page: SheetMusicPage
    let ink: String
    let accent: String
    let preview: Bool
    /// Space the controls and the safe area take at the top and bottom, in points.
    let topInset: CGFloat
    let bottomInset: CGFloat
    let highlight: SheetMusicHighlight
    /// Keep the marked measure in view.
    let follows: Bool
    /// A single tap, with its point on the page in SVG units (nil off the page).
    let onTap: (CGPoint?) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.allowsLinkPreview = false
        view.isAccessibilityElement = true
        view.navigationDelegate = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        coordinator.taps(enabled: !preview)
        let html = Self.html(svg: page.svg, ink: ink, accent: accent, preview: preview,
                             top: topInset, bottom: bottomInset)
        let key = Self.html(svg: page.svg, ink: ink, accent: accent, preview: preview, top: 0, bottom: 0)
        if coordinator.key != key {
            coordinator.key = key
            coordinator.reset(top: topInset, bottom: bottomInset)
            view.scrollView.isScrollEnabled = !preview
            view.scrollView.pinchGestureRecognizer?.isEnabled = !preview
            view.loadHTMLString(html, baseURL: nil)
        } else if !preview {
            coordinator.pad(top: topInset, bottom: bottomInset)
        }
        guard !preview else { return }
        coordinator.show(highlight, follows: follows)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        var key = ""
        var onTap: (CGPoint?) -> Void = { _ in }
        private weak var view: WKWebView?
        private var loaded = false
        private var top: CGFloat = 0
        private var bottom: CGFloat = 0
        /// Where the page's SVG starts in the document and CSS pixels per SVG unit, measured once loaded.
        private var metrics: (left: CGFloat, top: CGFloat, scale: CGFloat, width: CGFloat)?
        private var measuring = false
        private var shown: SheetMusicHighlight = .none
        private var pending: SheetMusicHighlight?
        private var followedMeasure: SheetMusicTiming.Box?
        /// The person scrolled or zoomed: leave the page where they put it for a while.
        private var touchedAt = Date.distantPast
        private let singleTap = UITapGestureRecognizer()
        private let doubleTap = UITapGestureRecognizer()

        func attach(to view: WKWebView) {
            self.view = view
            doubleTap.numberOfTapsRequired = 2
            doubleTap.addTarget(self, action: #selector(doubleTapped(_:)))
            doubleTap.delegate = self
            singleTap.addTarget(self, action: #selector(singleTapped(_:)))
            singleTap.require(toFail: doubleTap)
            singleTap.delegate = self
            view.addGestureRecognizer(doubleTap)
            view.addGestureRecognizer(singleTap)
            view.scrollView.panGestureRecognizer.addTarget(self, action: #selector(touched))
            view.scrollView.pinchGestureRecognizer?.addTarget(self, action: #selector(touched))
        }

        func taps(enabled: Bool) {
            singleTap.isEnabled = enabled
            doubleTap.isEnabled = enabled
        }

        func reset(top: CGFloat, bottom: CGFloat) {
            loaded = false
            metrics = nil
            shown = .none
            followedMeasure = nil
            self.top = top
            self.bottom = bottom
        }

        func pad(top: CGFloat, bottom: CGFloat) {
            guard top != self.top || bottom != self.bottom else { return }
            self.top = top
            self.bottom = bottom
            guard loaded, let view else { return }
            view.evaluateJavaScript("ap.pad(\(Double(top)), \(Double(bottom)))") { _, _ in }
            metrics = nil
        }

        func show(_ highlight: SheetMusicHighlight, follows: Bool) {
            guard loaded, let view else {
                pending = highlight
                return
            }
            if highlight != shown {
                shown = highlight
                view.evaluateJavaScript("ap.show(\(highlight.script))") { _, _ in }
            }
            if follows, let box = highlight.measure, box != followedMeasure {
                followedMeasure = box
                scroll(to: box)
            } else if !follows {
                followedMeasure = nil
            }
        }

        // MARK: Loading

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            measure()
            if let pending {
                self.pending = nil
                show(pending, follows: false)
            }
        }

        private func measure(then action: (@MainActor () -> Void)? = nil) {
            guard let view, !measuring else { return }
            measuring = true
            let width = view.bounds.width
            view.evaluateJavaScript("ap.metrics()") { [weak self] result, _ in
                guard let self else { return }
                self.measuring = false
                guard let values = result as? [NSNumber], values.count == 3 else { return }
                self.metrics = (CGFloat(values[0].doubleValue), CGFloat(values[1].doubleValue),
                                CGFloat(values[2].doubleValue), width)
                action?()
            }
        }

        /// Metrics for the page as it's laid out now; nil (and a fresh measure) after a resize.
        private var currentMetrics: (left: CGFloat, top: CGFloat, scale: CGFloat, width: CGFloat)? {
            guard let view, let metrics, metrics.width == view.bounds.width else {
                metrics = nil
                return nil
            }
            return metrics
        }

        // MARK: Following

        private func scroll(to box: SheetMusicTiming.Box) {
            guard let view else { return }
            guard let m = currentMetrics else {
                measure { [weak self] in self?.scroll(to: box) }
                return
            }
            let scrollView = view.scrollView
            guard !scrollView.isDragging, !scrollView.isDecelerating, !scrollView.isZooming,
                  Date().timeIntervalSince(touchedAt) > 4 else { return }
            let zoom = scrollView.zoomScale
            let boxTop = (m.top + CGFloat(box.y) * m.scale) * zoom
            let boxBottom = (m.top + CGFloat(box.y + box.height) * m.scale) * zoom
            let boxLeft = (m.left + CGFloat(box.x) * m.scale) * zoom
            let boxRight = (m.left + CGFloat(box.x + box.width) * m.scale) * zoom
            var offset = scrollView.contentOffset
            let height = scrollView.bounds.height, width = scrollView.bounds.width
            let visibleTop = offset.y + top, visibleBottom = offset.y + height - bottom
            if boxTop < visibleTop || boxBottom > visibleBottom {
                // Bring the measure's system up near the top, under the controls.
                offset.y = boxTop - top - (height - top - bottom) * 0.12
            }
            if boxLeft < offset.x || boxRight > offset.x + width {
                offset.x = boxLeft - 16
            }
            let maxY = max(0, scrollView.contentSize.height - height)
            let maxX = max(0, scrollView.contentSize.width - width)
            offset.y = min(max(offset.y, 0), maxY)
            offset.x = min(max(offset.x, 0), maxX)
            guard offset != scrollView.contentOffset else { return }
            scrollView.setContentOffset(offset, animated: true)
        }

        @objc private func touched() {
            touchedAt = Date()
        }

        // MARK: Taps

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        private var contentView: UIView? {
            guard let scrollView = view?.scrollView else { return nil }
            return scrollView.delegate?.viewForZooming?(in: scrollView) ?? scrollView.subviews.first
        }

        @objc private func singleTapped(_ gesture: UITapGestureRecognizer) {
            guard let content = contentView else { onTap(nil); return }
            let point = gesture.location(in: content)
            guard let m = currentMetrics, m.scale > 0 else {
                onTap(nil)
                measure()
                return
            }
            onTap(CGPoint(x: (point.x - m.left) / m.scale, y: (point.y - m.top) / m.scale))
        }

        @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = view?.scrollView, let content = contentView else { return }
            touchedAt = Date()
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: content)
                let factor = min(2.5, scrollView.maximumZoomScale)
                let size = CGSize(width: scrollView.bounds.width / factor, height: scrollView.bounds.height / factor)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                           width: size.width, height: size.height), animated: true)
            }
        }
    }

    static func html(svg: String, ink: String, accent: String, preview: Bool, top: CGFloat, bottom: CGFloat) -> String {
        // A preview: the top of the page, fading out (the web view is sized to it).
        let clip = preview ? "height: 100vh; box-sizing: border-box; overflow: hidden; -webkit-mask-image: linear-gradient(to bottom, #000 55%, transparent);" : ""
        let zoom = preview ? "maximum-scale=1, user-scalable=no" : "maximum-scale=5, user-scalable=yes"
        let padding = preview ? "8px 4px 24px" : "\(Int(top.rounded()))px 4px \(Int(bottom.rounded()))px"
        // The marks sit behind the notes: a tinted measure, a dot on the melody note, the syllable.
        let script = preview ? "" : """
        <script>
        const ap = (() => {
          const NS = 'http://www.w3.org/2000/svg';
          const page = document.querySelector('.page');
          const svg = page.querySelector('svg');
          const layer = document.createElementNS(NS, 'g');
          svg.insertBefore(layer, svg.querySelector('svg'));
          const make = (tag, attrs) => {
            const e = document.createElementNS(NS, tag);
            for (const k in attrs) e.setAttribute(k, attrs[k]);
            e.style.display = 'none';
            layer.appendChild(e);
            return e;
          };
          const m = make('rect', { rx: 8, fill: '\(accent)', 'fill-opacity': 0.13 });
          const s = make('rect', { rx: 4, fill: '\(accent)', 'fill-opacity': 0.30 });
          const n = make('circle', { fill: '\(accent)', 'fill-opacity': 0.42 });
          const place = (e, a) => {
            if (!a) { e.style.display = 'none'; return; }
            for (const k in a) e.setAttribute(k, a[k]);
            e.style.display = '';
          };
          return {
            show(h) { place(m, h.m); place(s, h.s); place(n, h.n); },
            pad(top, bottom) { page.style.paddingTop = top + 'px'; page.style.paddingBottom = bottom + 'px'; },
            metrics() {
              const r = svg.getBoundingClientRect();
              return [r.left + window.scrollX, r.top + window.scrollY, r.width / svg.viewBox.baseVal.width];
            }
          };
        })();
        </script>
        """
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, \(zoom)">
        <style>
        html, body { margin: 0; padding: 0; background: transparent; color: \(ink); -webkit-user-select: none; -webkit-touch-callout: none; -webkit-tap-highlight-color: transparent; }
        .page { padding: \(padding); \(clip) }
        svg { display: block; width: 100%; height: auto; }
        </style></head><body><div class="page">\(svg)</div>\(script)</body></html>
        """
    }
}

extension DSSurface {
    /// The reading surface's text colour, for the sheet music's CSS.
    var sheetMusicInk: String {
        switch self {
        case .paper: "#1C1F1E"
        case .parchment: "#3B2F1E"
        case .sepia: "#3E2F1D"
        case .muted: "#D9DBD8"
        case .black: "#E8E6E0"
        }
    }

    /// The surface's tint (Evergreen), for marking what the accompaniment is playing.
    var sheetMusicAccent: String {
        switch self {
        case .sepia: "#19604F"
        case .muted, .black: "#5FB8A6"
        default: "#1F7466"
        }
    }
}
