//
//  SheetMusicView.swift
//  Advent Praise
//
//  The open hymn's sheet music, from the Sheet music tile in the Lectern's
//  tray, in a full sheet like Memorise. The page is vector (SheetMusicCatalog):
//  the phone width on an iPhone or a narrow iPad split, the pad width when
//  there's room. It is inked in the reading surface's text colour, so Paper
//  and Parchment read dark on light and Muted and Black light on dark, and it
//  pinches to zoom.
//
//  Sheet music is Pro. Hymn of the Day's is free for everyone, every day.
//  Anyone else sees the top of the page and a Pro button; the paywall opens
//  over this sheet (ProFeature.sheetMusic) and, once Pro is bought, the
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

struct SheetMusicView: View {
    let hymnal: Hymnal
    let hymn: Hymn

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @State private var paywall: ProFeature?
    @State private var pages: [SheetMusicLayout: SheetMusicPage] = [:]
    @State private var tracked = false

    /// Pad width once the sheet is this wide.
    static let padWidth: CGFloat = 700

    private var isHymnOfTheDay: Bool {
        HymnOfTheDayFeed.hymn(on: .now, in: hymnal)?.id == hymn.id
    }

    private var access: SheetMusicAccess {
        SheetMusicAccess.resolve(isPro: store.unlocks(.sheetMusic), isHymnOfTheDay: isHymnOfTheDay)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout: SheetMusicLayout = geometry.size.width >= Self.padWidth ? .pad : .phone
            VStack(spacing: 0) {
                if access == .hymnOfTheDay { freeTodayNote }
                if let page = pages[layout] {
                    SheetMusicPageView(page: page, ink: surface.sheetMusicInk, preview: !access.showsWholePage)
                        .accessibilityLabel(Text("Sheet music for hymn \(hymn.id, format: .hymnNumber), \(hymn.title)"))
                        .overlay(alignment: .bottom) { if !access.showsWholePage { previewFade } }
                } else {
                    ContentUnavailableView("No sheet music", systemImage: "music.note",
                                           description: Text("This hymn’s sheet music couldn’t be opened."))
                        .frame(maxHeight: .infinity)
                }
                if !access.showsWholePage { proBar }
            }
            .task(id: layout) {
                if pages[layout] == nil {
                    let hymnalID = hymnal.id, number = hymn.id
                    pages[layout] = await Task.detached(priority: .userInitiated) {
                        SheetMusicCatalog.page(hymnal: hymnalID, number: number, layout: layout)
                    }.value
                }
            }
        }
        .navigationTitle(hymn.title)
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen(.sheetMusic)
        .onAppear {
            guard !tracked else { return }
            tracked = true
            Analytics.track(.sheetMusicOpened(number: hymn.id, access: access))
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

    private var freeTodayNote: some View {
        Label("Hymn of the Day: free for everyone today", systemImage: "sun.max")
            .font(DS.Typeface.caption)
            .foregroundStyle(surface.secondary)
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The preview fades out into the surface above the Pro button.
    private var previewFade: some View {
        LinearGradient(colors: [surface.background.opacity(0), surface.background],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 120)
            .allowsHitTesting(false)
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

/// The SVG in a transparent web view: inked with CSS `color`, pinch to zoom.
/// A preview shows the top of the page and doesn't scroll or zoom.
private struct SheetMusicPageView: UIViewRepresentable {
    let page: SheetMusicPage
    let ink: String
    let preview: Bool

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
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let html = Self.html(svg: page.svg, ink: ink, preview: preview, aspect: page.height / max(page.width, 1))
        guard context.coordinator.html != html else { return }
        context.coordinator.html = html
        view.scrollView.isScrollEnabled = !preview
        view.scrollView.pinchGestureRecognizer?.isEnabled = !preview
        view.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var html = ""
    }

    static func html(svg: String, ink: String, preview: Bool, aspect: Double) -> String {
        // A preview: the top of the page, about one system on a phone, no more than 45% of it.
        let clip = preview ? "max-height: min(\(Int(aspect * 45))vw, 70vh); overflow: hidden;" : ""
        let zoom = preview ? "maximum-scale=1, user-scalable=no" : "maximum-scale=5, user-scalable=yes"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, \(zoom)">
        <style>
        html, body { margin: 0; padding: 0; background: transparent; color: \(ink); -webkit-user-select: none; -webkit-touch-callout: none; }
        .page { padding: 8px 4px 24px; \(clip) }
        svg { display: block; width: 100%; height: auto; }
        </style></head><body><div class="page">\(svg)</div></body></html>
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
}
