//
//  WhatsNewSheet.swift
//  Advent Praise 7 — Vesper design system
//
//  "Welcome to Advent Praise 7" — shown once after updating from 6.x (and
//  once on first install). Always dark (the Stage), regardless of the reading
//  surface: a big serif title, four short feature blocks, one primary action
//  and Continue.
//
//  Presentation: `.whatsNewSheet()` on the root view handles show-once.
//

import SwiftUI

struct WhatsNewFeature: Identifiable, Sendable {
    let id = UUID()
    let systemImage: String
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    var usesBrass = false
}

extension WhatsNewFeature {
    /// The 7.0 feature set, in brief order. Copy is final-draft; ≤ 2 lines each at default size.
    static let advent7: [WhatsNewFeature] = [
        .init(systemImage: "music.note.house",
              title: "Worship mode",
              body: "Big, high-contrast words for the pew. The screen stays awake; one tap moves to the next verse."),
        .init(systemImage: "textformat.size",
              title: "Large print",
              body: "Lyrics that grow with your text size, on paper, sepia or a dark page."),
        .init(systemImage: "globe",
              title: "Every hymnal, one place",
              body: "Switch languages and keep your hymn number. Earlier purchases come with you.",
              usesBrass: true),
        .init(systemImage: "waveform",
              title: "Ask Siri",
              body: "“Open hymn 30 in Advent Praise.” Works from Shortcuts and the Action button too."),
    ]
}

struct WhatsNewSheet: View {
    var features: [WhatsNewFeature] = WhatsNewFeature.advent7
    var primaryTitle: LocalizedStringKey = "Try Worship Mode"
    let onPrimary: () -> Void
    let onContinue: () -> Void

    /// The sheet is always on the Stage; components inside read a dark surface.
    private let surface: DSSurface = .black

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                header
                VStack(spacing: DS.Space.s) {
                    ForEach(features) { FeatureTile(feature: $0) }
                }
            }
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .padding(.top, DS.Space.top + DS.Space.m)
            .padding(.bottom, DS.Space.l)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .background { StageBackground() }
        .environment(\.dsSurface, surface)
        .environment(\.colorScheme, .dark)
        .foregroundStyle(surface.highContrastForeground)
        .tint(surface.tint)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("Advent Praise 7").dsEyebrow(tracking: 1.5).foregroundStyle(surface.brass)
            Text("Welcome to\nAdvent Praise 7")
                .font(DS.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Welcome to Advent Praise 7")
            Text("A quieter hymnal, rebuilt for reading and singing together.")
                .font(DS.Typeface.rowBody)
                .foregroundStyle(surface.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: DS.Space.s) {
            GlassButton(title: primaryTitle, fullWidth: true, action: onPrimary)
            GlassButton(title: "Continue", kind: .secondary, fullWidth: true, action: onContinue)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.s)
        .frame(maxWidth: .infinity)
        .background { ActionsScrim() }
    }
}

private struct FeatureTile: View {
    let feature: WhatsNewFeature
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 44

    /// Feature tiles are content, not controls: an opaque raised Stage card
    /// with a hairline, never glass. Only the pinned actions float.
    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.panel) {
            Image(systemName: feature.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(feature.usesBrass ? surface.brass : surface.tint)
                .frame(width: iconSize, height: iconSize)
                .background(RoundedRectangle.ds(DS.Radius.key)
                    .fill((feature.usesBrass ? surface.brass : surface.tint).opacity(DS.Fill.tintOn)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(feature.title).font(DS.Typeface.rowTitle)
                Text(feature.body).font(DS.Typeface.detail).foregroundStyle(surface.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.panel + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle.ds(DS.Radius.card).fill(DS.Palette.stageRaised))
        .overlay(RoundedRectangle.ds(DS.Radius.card).strokeBorder(.white.opacity(DS.Fill.hairline)))
        .accessibilityElement(children: .combine)
    }
}

/// The Stage: near-black with an Evergreen glow, so glass has colour to bend.
private struct StageBackground: View {
    var body: some View {
        ZStack {
            DS.Palette.stage
            RadialGradient(colors: [DS.Palette.evergreenOnDark.opacity(0.35), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [DS.Palette.brassOnDark.opacity(0.18), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

/// Behind the pinned buttons. iOS 26: the system scroll-edge effect does this
/// work, so only a light fade. Fallback and Reduce Transparency: a stronger
/// fade to the Stage colour.
private struct ActionsScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(iOS 26, *), !reduceTransparency {
            LinearGradient(colors: [.clear, DS.Palette.stage.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        } else {
            LinearGradient(colors: [DS.Palette.stage.opacity(0), DS.Palette.stage.opacity(0.92)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Show once

extension View {
    /// Presents WhatsNewSheet once per major version.
    func whatsNewSheet(version: String = "7.0", onPrimary: @escaping () -> Void) -> some View {
        modifier(WhatsNewPresenter(version: version, onPrimary: onPrimary))
    }
}

private struct WhatsNewPresenter: ViewModifier {
    let version: String
    let onPrimary: () -> Void
    @AppStorage("whatsNew.lastSeenVersion") private var lastSeen = ""
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onAppear { if lastSeen != version { isPresented = true } }
            .sheet(isPresented: $isPresented, onDismiss: { lastSeen = version }) {
                WhatsNewSheet(onPrimary: { isPresented = false; onPrimary() },
                              onContinue: { isPresented = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .modifier(StagePresentation())
                    .interactiveDismissDisabled(false)
            }
    }
}

/// iOS 26: let the system glass sheet show through the Stage edges.
/// Fallback, and Reduce Transparency: an opaque Stage so the sheet is dark everywhere.
private struct StagePresentation: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26, *), !reduceTransparency {
            content.presentationBackground { DS.Palette.stage.opacity(0.92) }
        } else {
            content.presentationBackground(DS.Palette.stage)
        }
    }
}

#Preview("WhatsNewSheet") {
    WhatsNewSheet(onPrimary: {}, onContinue: {})
}

#Preview("WhatsNewSheet · presented over reader") {
    DSPreviewBackdrop()
        .dsSurface(.paper)
        .whatsNewSheet {}
}

#Preview("WhatsNewSheet · AX3") {
    WhatsNewSheet(onPrimary: {}, onContinue: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
