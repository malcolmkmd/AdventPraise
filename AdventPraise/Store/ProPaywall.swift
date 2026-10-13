//
//  ProPaywall.swift
//  Advent Praise
//
//  The Advent Praise Pro paywall: a full sheet (Liquid Glass on iOS 26,
//  Vesper material before) over warm gold light and a crowd of raised hands
//  (PaywallScenery). It opens when a free user taps Play or AirPlay, or from
//  More. It shows the church logo and "Sing without limits", five short
//  lines on what Pro opens, one buy button with the price exactly as the
//  App Store gives it (through the RevenueCat offering; nothing is
//  hard-coded), and Restore purchases, Terms and Privacy. Pro is bought
//  once: no plans to choose, no trial. Unlocking closes the sheet and
//  carries on with what was asked for. The tips live on the Support Advent
//  Praise screen in More (SupportView), not here.
//

import SwiftUI

extension View {
    /// Presents the paywall while `feature` is set. `isEnabled` false leaves
    /// it to another presenter (church mode covers the root). `context` is
    /// the screen it covers, for analytics.
    func proPaywall(feature: Binding<ProFeature?>, isEnabled: Bool = true, context: PaywallContext,
                    onUnlocked: @escaping (ProFeature) -> Void = { _ in }) -> some View {
        modifier(ProPaywallPresenter(feature: feature, isEnabled: isEnabled, context: context, onUnlocked: onUnlocked))
    }
}

private struct ProPaywallPresenter: ViewModifier {
    @Binding var feature: ProFeature?
    let isEnabled: Bool
    let context: PaywallContext
    let onUnlocked: (ProFeature) -> Void
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    /// Kept while the sheet closes, so the copy doesn't change under it.
    @State private var shown: ProFeature = .player
    /// The feature `paywall_viewed` was sent for, until `paywall_dismissed`.
    @State private var viewed: ProFeature?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresented) {
                ProPaywallView(feature: shown) { feature = nil }
                    .modifier(PaywallSheetSizing())
                    .presentationBackground(PaywallPalette(surface: surface).ground)
                    .presentationDragIndicator(.hidden)
                    .dsSurface(surface, paintsBackground: false)
            }
            .onChange(of: feature) { _, next in if let next { shown = next } }
            .onChange(of: store.isPro) { _, isPro in
                guard isPro, let unlocked = feature, isEnabled, unlocked != .support else { return }
                feature = nil
                onUnlocked(unlocked)
            }
            .onAppear { trackPresentation(isPresented.wrappedValue) }
            .onChange(of: isPresented.wrappedValue) { _, open in trackPresentation(open) }
            .onDisappear { trackPresentation(false) }
    }

    private func trackPresentation(_ open: Bool) {
        if open, viewed == nil, let feature {
            viewed = feature
            Analytics.track(.paywallViewed(feature: feature, context: context))
            Analytics.screen(.paywall)
        } else if !open, let shownFeature = viewed {
            viewed = nil
            Analytics.track(.paywallDismissed(feature: shownFeature, context: context,
                                              outcome: store.isPro ? .unlocked : .closed))
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { isEnabled && feature != nil }, set: { if !$0 { feature = nil } })
    }
}

/// iPad: a page-sized sheet, so the picture has room. iOS 17: the form sheet.
private struct PaywallSheetSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}

// MARK: - View

struct ProPaywallView: View {
    let feature: ProFeature
    let onClose: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Drives the opening: the hands lift, the words rise.
    @State private var opened = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        ZStack(alignment: .bottom) {
            PaywallBackdrop(palette: palette, lifted: opened, handHeight: Self.handHeight)
            ScrollView {
                page
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        }
        .overlay(alignment: .topTrailing) {
            GlassButton(title: "Close", systemImage: "xmark", kind: .icon, action: onClose)
                .padding(.top, DS.Space.m)
                .padding(.trailing, DS.Space.m)
        }
        .task {
            if store.proOption == nil { await store.loadStorefront() }
        }
        .onAppear {
            // A beat after the sheet lands, so the lift is seen.
            withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .spring(duration: 0.9, bounce: 0).delay(0.15)) {
                opened = true
            }
        }
        .accessibilityAction(.escape, onClose)
    }

    // MARK: Page

    private var page: some View {
        VStack(spacing: DS.Space.l + DS.Space.xxs) {
            header
            features
            offer
            legal
        }
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.l)
        // Scrolled to the end, the words rest above the hands.
        .padding(.bottom, Self.handHeight * 0.55)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion))
    }

    static let handHeight: CGFloat = 184

    private var header: some View {
        VStack(spacing: DS.Space.m) {
            PaywallLogo(palette: palette)
                .padding(.top, DS.Space.l)
            VStack(spacing: DS.Space.s) {
                Text("Advent Praise Pro").dsEyebrow(tracking: 1.6).foregroundStyle(palette.brass)
                Text("Sing without limits")
                    .font(DS.Typeface.display)
                    .dsBalancedWrap()
                    .accessibilityAddTraits(.isHeader)
                Text(lead)
                    .font(DS.Typeface.rowBody)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var lead: LocalizedStringKey {
        switch feature {
        case .player: "The piano is ready to play this hymn with you. Pro opens it, and everything below."
        case .airPlay: "The words are ready for the church screen. Pro opens it, and everything below."
        case .support: "Everything below, bought once and yours for good."
        }
    }

    // MARK: Features

    private static let lines: [(image: String, text: LocalizedStringKey)] = [
        ("pianokeys", "MIDI sing-along player"),
        ("airplayvideo", "Church mode with AirPlay casting"),
        ("list.bullet.clipboard", "Service planner and unlimited playlists"),
        ("tuningfork", "Pitch pipe"),
        ("brain.head.profile", "Unlimited Memorise"),
    ]

    private var features: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 320 : 236), spacing: DS.Space.m, alignment: .leading)],
                  alignment: .leading, spacing: DS.Space.s) {
            ForEach(Array(Self.lines.enumerated()), id: \.offset) { index, line in
                FeatureLine(systemImage: line.image, text: line.text, palette: palette)
                    .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.25 + Double(index) * 0.05))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What Pro opens")
    }

    // MARK: Offer

    /// What the buy button sells, in words: once, and for good. The price
    /// itself is on the button. Pro active: the thank-you card instead.
    @ViewBuilder private var offer: some View {
        if store.isPro {
            ProActiveCard(palette: palette)
        } else if store.proOption != nil {
            Text("One purchase, no subscription. Yours for good, on every device signed in with this Apple Account.")
                .font(DS.Typeface.caption)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else if store.isLoadingOptions {
            HStack(spacing: DS.Space.s) {
                ProgressView()
                Text("Getting prices from the App Store…").font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: DS.Size.row)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: DS.Space.xs) {
                Text(store.isConfigured ? "Pro isn’t available right now. Check your connection and try again."
                                        : "Purchases aren’t available in this build.")
                    .font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if store.isConfigured {
                    Button("Try again") { Task { await store.loadStorefront() } }
                        .font(DS.Typeface.button)
                        .foregroundStyle(surface.tint)
                        .frame(minHeight: DS.Size.hitTarget)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Space.m)
            .background(RoundedRectangle.ds(DS.Radius.card).fill(.primary.opacity(DS.Fill.row)))
        }
    }

    // MARK: Legal

    private var legal: some View {
        HStack(spacing: DS.Space.m) {
            Button {
                Task { await store.restore(source: .paywall) }
            } label: {
                if store.isRestoring {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Restore purchases")
                }
            }
            .disabled(store.isRestoring || store.purchasing)
            .accessibilityHint("Unlocks Pro if this Apple Account has bought it before")
            dot
            Button("Terms of Use") { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
            dot
            Button("Privacy Policy") { openURL(AppInfo.privacyPolicyURL) }
        }
        .font(DS.Typeface.caption.weight(.medium))
        .foregroundStyle(surface.secondary)
        .frame(minHeight: DS.Size.hitTarget)
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        Text("·").accessibilityHidden(true)
    }

    // MARK: Actions

    /// The one buy button, with the App Store's price on it.
    @ViewBuilder private var actions: some View {
        // No price (offline, or not set up), or Pro already: nothing to buy.
        if !store.isPro, let option = store.proOption {
            GlassButton(title: "Unlock Pro · \(option.price)", tint: palette.brass,
                        isLoading: store.purchasing, fullWidth: true) {
                Task { await store.purchase(option, feature: feature) }
            }
            .disabled(store.purchasing || store.isRestoring)
            .accessibilityHint("One-time purchase")
            .frame(maxWidth: 560)
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .padding(.top, DS.Space.s)
            .padding(.bottom, DS.Space.m)
            .frame(maxWidth: .infinity)
            .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.45))
        }
    }
}

// MARK: - Pieces

/// Fades up a little as the paywall opens (fade only under Reduce Motion).
/// Shared with the Support screen's thank-you.
struct PaywallRise: ViewModifier {
    let opened: Bool
    let reduceMotion: Bool
    var delay: Double = 0.1

    func body(content: Content) -> some View {
        content
            .opacity(opened ? 1 : 0)
            .offset(y: opened || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? .easeInOut(duration: 0.45).delay(delay)
                                    : .spring(duration: 0.8, bounce: 0).delay(delay), value: opened)
    }
}

private struct FeatureLine: View {
    let systemImage: String
    let text: LocalizedStringKey
    let palette: PaywallPalette
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .callout) private var iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.brass)
                .frame(width: iconSize, height: iconSize)
                .background(Circle().fill(palette.gold.opacity(palette.isDark ? 0.16 : 0.2)))
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typeface.rowTitle)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown in place of the offer once Pro is active (opened from More).
private struct ProActiveCard: View {
    let palette: PaywallPalette
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(palette.brass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text("Pro is yours").font(DS.Typeface.panelTitle)
                Text("Thank you for singing with us.").font(DS.Typeface.caption).foregroundStyle(surface.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle.ds(DS.Radius.tile).fill(palette.gold.opacity(palette.isDark ? 0.14 : 0.18)))
        .overlay(RoundedRectangle.ds(DS.Radius.tile).strokeBorder(palette.brass.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Paywall · dark") {
    let store = PurchaseStore()
    return ProPaywallView(feature: .player) {}
        .environment(store)
        .dsSurface(.black, paintsBackground: false)
}

#Preview("Paywall · paper") {
    let store = PurchaseStore()
    return ProPaywallView(feature: .airPlay) {}
        .environment(store)
        .dsSurface(.paper, paintsBackground: false)
}
