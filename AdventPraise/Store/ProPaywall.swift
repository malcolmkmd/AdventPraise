//
//  ProPaywall.swift
//  Advent Praise
//
//  The Advent Praise Pro paywall: a full sheet (Liquid Glass on iOS 26,
//  Vesper material before) over warm gold light and a crowd of raised hands
//  (PaywallScenery). It opens when a free user taps Play with the free
//  plays used up, or AirPlay, or from More. It shows the church logo and "Sing without limits", short
//  lines on what Pro opens, one buy button with the price exactly as the
//  App Store gives it (the RevenueCat offering's package; nothing is
//  hard-coded, and if it can't be loaded the sheet says so and offers Try
//  again), and Restore purchases, Terms and Privacy. Pro is the annual
//  subscription alone (`$rc_annual`): "3 days free, then R199.99/year.
//  Cancel anytime." with the trial and price from the App Store, "Start
//  3-Day Free Trial" (or "Subscribe" once the trial has been had), and
//  Apple's renewal terms. The Lifetime package is never offered. It never
//  shows for anyone who has Pro (subscribers, and 7.0.x buyers of Pro or
//  MIDI Piano, who keep it for life). Every gate sells Pro alone. Unlocking what the
//  gate asked for closes the sheet and carries on with what was asked for.
//  The tips live on Support Advent Praise (SupportView), opened from More in
//  the same chrome (PaywallChrome).
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

/// When the paywall may show: a gate asked for it, this presenter is the one
/// in charge, and the customer doesn't have Pro (however it was bought).
enum ProPaywallRule {
    static func presents(_ feature: ProFeature?, isEnabled: Bool, entitlements: Entitlements) -> Bool {
        isEnabled && feature != nil && !entitlements.isPro
    }
}

private struct ProPaywallPresenter: ViewModifier {
    @Binding var feature: ProFeature?
    let isEnabled: Bool
    let context: PaywallContext
    let onUnlocked: (ProFeature) -> Void
    @Environment(PurchaseStore.self) private var store
    /// Kept while the sheet closes, so the copy doesn't change under it.
    @State private var shown: ProFeature = .player
    /// The feature `paywall_viewed` was sent for, until `paywall_dismissed`.
    @State private var viewed: ProFeature?

    func body(content: Content) -> some View {
        content
            .paywallSheet(isPresented: isPresented) {
                ProPaywallView(feature: shown) { feature = nil }
            }
            .onChange(of: feature) { _, next in if let next { shown = next } }
            // Pro closes any gate.
            .onChange(of: store.entitlements) { _, entitlements in
                guard let unlocked = feature, isEnabled, unlocked != .support,
                      entitlements.unlocks(unlocked) else { return }
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
                                              outcome: store.unlocks(shownFeature) ? .unlocked : .closed))
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { ProPaywallRule.presents(feature, isEnabled: isEnabled, entitlements: store.entitlements) },
                set: { if !$0 { feature = nil } })
    }
}

// MARK: - Chrome

extension View {
    /// Presents `sheet` the way the paywall opens: a full sheet on the
    /// paywall's ground, no grabber. The Pro paywall and Support Advent Praise.
    func paywallSheet<Sheet: View>(isPresented: Binding<Bool>,
                                   @ViewBuilder sheet: @escaping () -> Sheet) -> some View {
        modifier(PaywallSheet(isPresented: isPresented, sheet: sheet))
    }
}

private struct PaywallSheet<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheet: () -> Sheet
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheet()
                .modifier(PaywallSheetSizing())
                .presentationBackground(PaywallPalette(surface: surface).ground)
                .presentationDragIndicator(.hidden)
                .dsSurface(surface, paintsBackground: false)
        }
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

/// The paywall's frame, for a sheet opened with `paywallSheet`: the light
/// and the hands behind a page that scrolls, Close at the top and the call
/// to action floating at the bottom. It runs the opening (`opened`: the
/// hands lift, the page and the action rise); pieces of the page can rise
/// after it with PaywallRise.
struct PaywallChrome<Page: View, Actions: View>: View {
    @Binding var opened: Bool
    let onClose: () -> Void
    @ViewBuilder let page: () -> Page
    /// Empty when there is nothing to buy.
    @ViewBuilder let actions: () -> Actions

    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var handHeight: CGFloat { 184 }

    var body: some View {
        ZStack(alignment: .bottom) {
            PaywallBackdrop(palette: PaywallPalette(surface: surface), lifted: opened, handHeight: Self.handHeight)
            ScrollView {
                page()
                    .padding(.horizontal, DS.Space.l + DS.Space.xxs)
                    .padding(.top, DS.Space.l)
                    // Scrolled to the end, the words rest above the hands.
                    .padding(.bottom, Self.handHeight * 0.55)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion))
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions()
                    .frame(maxWidth: 560)
                    .padding(.horizontal, DS.Space.l + DS.Space.xxs)
                    .padding(.top, DS.Space.s)
                    .padding(.bottom, DS.Space.m)
                    .frame(maxWidth: .infinity)
                    .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.45))
            }
        }
        .overlay(alignment: .topTrailing) {
            GlassButton(title: "Close", systemImage: "xmark", kind: .icon, action: onClose)
                .padding(.top, DS.Space.m)
                .padding(.trailing, DS.Space.m)
        }
        .onAppear {
            // A beat after the sheet lands, so the lift is seen.
            withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .spring(duration: 0.9, bounce: 0).delay(0.15)) {
                opened = true
            }
        }
        .accessibilityAction(.escape, onClose)
    }
}

/// The paywall's header: the church logo, a brass eyebrow, the title and a
/// line or two under it.
struct PaywallHeader: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let lead: LocalizedStringKey
    @Environment(\.dsSurface) private var surface

    var body: some View {
        let palette = PaywallPalette(surface: surface)
        VStack(spacing: DS.Space.m) {
            PaywallLogo(palette: palette)
                .padding(.top, DS.Space.l)
            VStack(spacing: DS.Space.s) {
                Text(eyebrow).dsEyebrow(tracking: 1.6).foregroundStyle(palette.brass)
                Text(title)
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
}

// MARK: - View

struct ProPaywallView: View {
    let feature: ProFeature
    let onClose: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Drives the opening: the hands lift, the words rise.
    @State private var opened = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        PaywallChrome(opened: $opened, onClose: onClose) {
            VStack(spacing: DS.Space.l + DS.Space.xxs) {
                PaywallHeader(eyebrow: "Advent Praise Pro", title: "Sing without limits", lead: lead)
                features
                offer
                PaywallLegal(restoreHint: "Unlocks Pro if this Apple Account has subscribed or bought it before")
            }
        } actions: {
            actions
        }
        .task {
            if store.proOption == nil { await store.loadStorefront() }
        }
    }

    private var lead: LocalizedStringKey {
        switch feature {
        case .player: "You’ve had your free plays of the piano. Pro keeps it playing with you, and opens everything below."
        case .airPlay: "A clean worship display on any TV or projector, with your phone as the remote. Pro opens it, and everything below."
        case .mirroring: "Your screen is being mirrored. Pro shows a clean worship display on any TV or projector instead: big words, no phone, and your phone as the remote."
        case .sheetMusic: "Sheet music to read and play from, on phone and iPad. Hymn of the Day’s is free every day. Pro opens the rest, and everything below."
        case .support: "Everything below, on every device signed in with your Apple Account."
        }
    }

    // MARK: Features

    /// Also listed on the Pro card at the top of More.
    static let lines: [(image: String, text: LocalizedStringKey)] = [
        ("pianokeys", "Unlimited MIDI sing-along player"),
        ("music.note.list", "Sheet music to read and play from"),
        ("airplayvideo", "Clean worship display on any TV or projector"),
        ("platter.filled.top.iphone", "Live Activity & Dynamic Island controls"),
        ("widget.small", "Presenter widgets for the Lock & Home Screens"),
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

    /// The offer in words: "3 days free, then R199.99/year. Cancel
    /// anytime.", with Apple's renewal terms under it. Pro active (it closes
    /// at once): the thank-you card. No annual package: Try again.
    @ViewBuilder private var offer: some View {
        if store.isPro {
            ProActiveCard(palette: palette)
        } else if let option = store.proOption {
            VStack(spacing: DS.Space.xs) {
                Text(option.offerLine)
                    .font(DS.Typeface.rowTitle)
                    .accessibilityIdentifier("paywall.offer")
                Text(option.renewalTerms)
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            PaywallPriceStatus(failure: "Couldn’t reach the App Store for Pro’s price. Check your connection and try again.")
        }
    }

    // MARK: Actions

    /// "Start 3-Day Free Trial", or "Subscribe" without a trial.
    @ViewBuilder private var actions: some View {
        // No price (offline, or not set up), or Pro already: nothing to buy.
        if !store.isPro, let option = store.proOption {
            GlassButton(title: LocalizedStringKey(option.callToAction), tint: palette.brass,
                        isLoading: store.purchasingID == option.id, fullWidth: true) {
                Task { await store.purchase(option, feature: feature) }
            }
            .accessibilityHint(option.offerLine)
            .accessibilityIdentifier("paywall.unlockPro")
            .disabled(store.purchasing || store.isRestoring)
        }
    }
}

// MARK: - Pieces

/// Fades up a little as the paywall opens (fade only under Reduce Motion).
/// Shared with Support Advent Praise and the tip thank-you.
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

/// Restore purchases, Terms of Use and the Privacy Policy, under the offer.
/// Restore re-syncs every purchase; `restoreHint` says what it opens here,
/// for VoiceOver.
struct PaywallLegal: View {
    let restoreHint: LocalizedStringKey

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.openURL) private var openURL
    /// The in-app privacy policy and terms of use, over the paywall.
    @State private var showsPrivacy = false
    @State private var showsTerms = false

    var body: some View {
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
            .accessibilityHint(restoreHint)
            dot
            Button("Terms of Use") { showsTerms = true }
            dot
            Button("Privacy Policy") { showsPrivacy = true }
        }
        .font(DS.Typeface.caption.weight(.medium))
        .foregroundStyle(surface.secondary)
        .frame(minHeight: DS.Size.hitTarget)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showsPrivacy) {
            PrivacyPolicySheet(surface: surface) { showsPrivacy = false }
        }
        .sheet(isPresented: $showsTerms) {
            TermsOfUseSheet(surface: surface) { showsTerms = false }
        }
    }

    private var dot: some View {
        Text("·").accessibilityHidden(true)
    }
}

/// In place of the offer while a price loads, or when it couldn't be:
/// `failure` and Try again. Each product is judged on its own; the screen
/// decides which one it is waiting for.
struct PaywallPriceStatus: View {
    let failure: LocalizedStringKey

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface

    var body: some View {
        if store.isLoadingOptions {
            HStack(spacing: DS.Space.s) {
                ProgressView()
                Text("Getting prices from the App Store…").font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: DS.Size.row)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: DS.Space.xs) {
                Text(failure)
                    .font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await store.loadStorefront() } }
                    .font(DS.Typeface.button)
                    .foregroundStyle(surface.tint)
                    .frame(minHeight: DS.Size.hitTarget)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Space.m)
            .background(RoundedRectangle.ds(DS.Radius.card).fill(.primary.opacity(DS.Fill.row)))
        }
    }
}

/// One line of what an unlock opens: a brass symbol in a soft disc, and the words.
struct FeatureLine: View {
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
