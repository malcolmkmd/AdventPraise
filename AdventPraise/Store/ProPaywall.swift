//
//  ProPaywall.swift
//  Advent Praise
//
//  The Advent Praise Pro paywall: a full sheet (Liquid Glass on iOS 26,
//  Vesper material before) over warm gold light and raised hands
//  (PaywallScenery). It opens when a free user taps Play or AirPlay, or from
//  More. It shows the church logo and "Sing without limits", six short lines
//  on what Pro opens, the plans exactly as the App Store prices them (from
//  the RevenueCat offering; nothing is hard-coded, the free trial included),
//  Restore purchases, Terms and Privacy, and three one-off tips that unlock
//  nothing. Unlocking closes it and carries on with what was asked for.
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
    @State private var selection: String?
    /// Drives the opening: the hands lift, the words rise.
    @State private var opened = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }
    private var selected: ProOption? {
        store.proOptions.first { $0.id == selection } ?? store.proOptions.first
    }

    var body: some View {
        @Bindable var store = store
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
            if store.proOptions.isEmpty { await store.loadStorefront() }
        }
        .onAppear {
            // A beat after the sheet lands, so the lift is seen.
            withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .spring(duration: 0.9, bounce: 0).delay(0.15)) {
                opened = true
            }
        }
        .sheet(item: $store.thankYouForTip) { tip in
            TipThankYouSheet(tip: tip) { store.thankYouForTip = nil }
                .dsSurface(surface, paintsBackground: false)
        }
        .accessibilityAction(.escape, onClose)
    }

    // MARK: Page

    private var page: some View {
        VStack(spacing: DS.Space.l + DS.Space.xxs) {
            header
            features
            plans
            legal
            tipsSection
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
        case .support: "Everything Pro opens, and a way to say thank you."
        }
    }

    // MARK: Features

    private static let lines: [(image: String, text: LocalizedStringKey)] = [
        ("pianokeys", "MIDI sing-along player"),
        ("airplayvideo", "Church mode with AirPlay casting"),
        ("list.bullet.clipboard", "Service planner and unlimited playlists"),
        ("tuningfork", "Pitch pipe"),
        ("brain.head.profile", "Unlimited Memorise"),
        ("rectangle.split.2x1", "Side-by-side translations"),
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

    // MARK: Plans

    @ViewBuilder private var plans: some View {
        if store.isPro {
            ProActiveCard(palette: palette)
        } else if !store.proOptions.isEmpty {
            VStack(spacing: DS.Space.s) {
                ForEach(store.proOptions) { option in
                    PlanRow(option: option, isSelected: option == selected, palette: palette) {
                        selection = option.id
                        Haptics.play(.selection)
                    }
                }
                if let selected {
                    Text(renewalNote(for: selected))
                        .font(DS.Typeface.caption)
                        .foregroundStyle(surface.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Space.xxs)
                        .animation(DS.Motion.quick, value: selected.id)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Ways to buy Pro")
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

    private func renewalNote(for option: ProOption) -> String {
        if option.renews {
            if let trial = option.trial {
                return String(localized: "Free for \(trial.length), then \(option.price) \(option.term). Renews automatically until cancelled; cancel any time in Settings, at least a day before it renews.")
            }
            return String(localized: "\(option.price) \(option.term), renewing automatically until cancelled. Cancel any time in Settings, at least a day before it renews.")
        }
        return String(localized: "\(option.price) once. Yours for good, on every device signed in with this Apple Account.")
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
            .disabled(store.isRestoring || store.purchasing != nil)
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

    // MARK: Tips

    @ViewBuilder private var tipsSection: some View {
        if !store.tips.isEmpty {
            VStack(spacing: DS.Space.s) {
                VStack(spacing: DS.Space.xxs) {
                    Text("Support Advent Praise").dsEyebrow(tracking: 1.4).foregroundStyle(palette.brass)
                        .accessibilityAddTraits(.isHeader)
                    Text("A one-off thank you. Tips unlock nothing.")
                        .font(DS.Typeface.caption)
                        .foregroundStyle(surface.secondary)
                }
                .frame(maxWidth: .infinity)
                tipCards
            }
            .padding(.top, DS.Space.xs)
        }
    }

    @ViewBuilder private var tipCards: some View {
        let cards = ForEach(store.tips) { tip in
            TipCard(tip: tip, isLoading: store.tipping == tip.id, palette: palette) {
                Task { await store.tip(tip) }
            }
            .disabled(store.tipping != nil)
        }
        if typeSize.isAccessibilitySize {
            VStack(spacing: DS.Space.s) { cards }
        } else {
            HStack(alignment: .top, spacing: DS.Space.s) { cards }
        }
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        // No options (offline, or not set up), or Pro already: nothing to buy.
        if !store.isPro, let selected {
            GlassButton(title: callToAction(for: selected), tint: palette.brass,
                        isLoading: store.purchasing != nil, fullWidth: true) {
                Task { await store.purchase(selected, feature: feature) }
            }
            .disabled(store.purchasing != nil || store.isRestoring)
            .frame(maxWidth: 560)
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .padding(.top, DS.Space.s)
            .padding(.bottom, DS.Space.m)
            .frame(maxWidth: .infinity)
            .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.45))
        }
    }

    private func callToAction(for option: ProOption) -> LocalizedStringKey {
        if let trial = option.trial { return "Start \(trial.hyphenated) free trial" }
        return "Unlock Pro · \(option.price)"
    }
}

// MARK: - Pieces

/// Fades up a little as the paywall opens (fade only under Reduce Motion).
private struct PaywallRise: ViewModifier {
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

/// One plan. The yearly is the primary (bigger, with its trial); the
/// lifetime a quieter row. Content on the sheet, so a fill and outline, no glass.
private struct PlanRow: View {
    let option: ProOption
    let isSelected: Bool
    let palette: PaywallPalette
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    private var isPrimary: Bool { option.plan == .yearly }

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.tile)
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? palette.brass : surface.controlBorder)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    HStack(spacing: DS.Space.s) {
                        Text(option.title).font(isPrimary ? DS.Typeface.panelTitle : DS.Typeface.rowTitle)
                        if let trial = option.trial {
                            Text("\(trial.length) free")
                                .font(DS.Typeface.eyebrow)
                                .textCase(.uppercase)
                                .foregroundStyle(palette.isDark ? DS.Palette.stage : .white)
                                .padding(.horizontal, DS.Space.s)
                                .padding(.vertical, DS.Space.xxs)
                                .background(Capsule().fill(palette.brass))
                        }
                    }
                    Text(detail).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Space.s)
                Text(option.price)
                    .font(isPrimary ? DS.Typeface.numeral : DS.Typeface.label).monospacedDigit()
                    .foregroundStyle(palette.brass)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, isPrimary ? DS.Space.m : DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: isPrimary ? DS.Size.row + 16 : DS.Size.compactRow)
            .background(shape.fill(isSelected ? palette.gold.opacity(palette.isDark ? 0.14 : 0.18)
                                              : .primary.opacity(DS.Fill.row)))
            .overlay(shape.strokeBorder(isSelected ? palette.brass : surface.controlBorder.opacity(0.4),
                                        lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(DSPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.title), \(option.price) \(option.term)\(option.trial.map { ", \($0.length) free trial" } ?? "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var detail: String {
        if option.trial != nil { return String(localized: "Then \(option.price) \(option.term)") }
        return option.renews ? option.term : String(localized: "One-time purchase")
    }
}

/// Shown in place of the plans once Pro is active (opened from More).
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

/// One tip: its name, a line, and the price as the button.
private struct TipCard: View {
    let tip: TipOption
    let isLoading: Bool
    let palette: PaywallPalette
    let action: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.tile)
        Button(action: action) {
            let wide = typeSize.isAccessibilitySize
            VStack(alignment: wide ? .leading : .center, spacing: DS.Space.xs) {
                Text(tip.name).font(DS.Typeface.rowTitle)
                Text(tip.blurb)
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(wide ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if isLoading {
                        ProgressView().controlSize(.small).tint(palette.brass)
                    } else {
                        Text(tip.price).monospacedDigit()
                    }
                }
                .font(DS.Typeface.button)
                .foregroundStyle(palette.brass)
                .frame(minWidth: 56, minHeight: 28)
                .padding(.horizontal, DS.Space.s)
                .background(Capsule().fill(palette.gold.opacity(palette.isDark ? 0.18 : 0.22)))
                .padding(.top, DS.Space.hair)
            }
            .frame(maxWidth: .infinity, alignment: wide ? .leading : .center)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.m)
            .background(shape.fill(.primary.opacity(DS.Fill.row)))
            .overlay(shape.strokeBorder(surface.controlBorder.opacity(0.3)))
            .contentShape(shape)
        }
        .buttonStyle(DSPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(localized: tip.name)) tip, \(tip.price)")
        .accessibilityHint(Text(tip.blurb))
    }
}

// MARK: - Thank you

/// After a tip: "Praise the Lord!" over the same light and hands.
struct TipThankYouSheet: View {
    let tip: TipOption
    let onDone: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        ZStack(alignment: .bottom) {
            PaywallBackdrop(palette: palette, lifted: opened, handHeight: 150, lightIntensity: 0.9)
            VStack(spacing: DS.Space.m) {
                PaywallLogo(palette: palette, width: 64)
                    .padding(.top, DS.Space.l + DS.Space.m)
                Text("Praise the Lord!")
                    .font(DS.Typeface.display)
                    .dsBalancedWrap()
                    .accessibilityAddTraits(.isHeader)
                Text("Thank you for supporting Advent Praise.")
                    .font(DS.Typeface.rowBody)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Space.l)
                GlassButton(title: "Amen", tint: palette.brass, fullWidth: true, action: onDone)
                    .frame(maxWidth: 400)
                    .padding(.bottom, DS.Space.l)
            }
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .frame(maxWidth: .infinity)
            .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion))
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.ground)
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .spring(duration: 0.8, bounce: 0).delay(0.1)) {
                opened = true
            }
        }
        .accessibilityAction(.escape, onDone)
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

#Preview("Thank you") {
    TipThankYouSheet(tip: TipOption(id: "ap_tip_amen", name: "Amen", blurb: "A quiet thank you", price: "$0.99")) {}
        .dsSurface(.black, paintsBackground: false)
}
