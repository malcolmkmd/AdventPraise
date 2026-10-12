//
//  ProPaywall.swift
//  Advent Praise
//
//  The Advent Praise Pro paywall, in the app's drawer (Liquid Glass on
//  iOS 26, Vesper material before). It opens when a free user taps Play or
//  AirPlay, leads with that feature, lists the ways to buy Pro exactly as
//  the App Store prices them (from the RevenueCat offering; nothing is
//  hard-coded), and offers Restore purchases. Unlocking closes it and
//  carries on with what was asked for.
//

import SwiftUI

extension View {
    /// Presents the paywall while `feature` is set. `isEnabled` false leaves
    /// it to another presenter (church mode covers the root).
    func proPaywall(feature: Binding<ProFeature?>, isEnabled: Bool = true,
                    onUnlocked: @escaping (ProFeature) -> Void = { _ in }) -> some View {
        modifier(ProPaywallPresenter(feature: feature, isEnabled: isEnabled, onUnlocked: onUnlocked))
    }
}

private struct ProPaywallPresenter: ViewModifier {
    @Binding var feature: ProFeature?
    let isEnabled: Bool
    let onUnlocked: (ProFeature) -> Void
    @Environment(PurchaseStore.self) private var store
    @State private var selection: String?
    /// Kept while the drawer closes, so the copy doesn't change under it.
    @State private var shown: ProFeature = .player

    func body(content: Content) -> some View {
        content
            .adventDrawer("Advent Praise Pro", isPresented: isPresented, style: AdventDrawerStyle(detents: [.fitted, .large])) {
                ProPaywall(feature: shown, part: .page, selection: $selection)
            } actions: {
                ProPaywall(feature: shown, part: .actions, selection: $selection)
            }
            .onChange(of: feature) { _, next in if let next { shown = next } }
            .onChange(of: store.isPro) { _, isPro in
                guard isPro, let unlocked = feature, isEnabled else { return }
                feature = nil
                onUnlocked(unlocked)
            }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { isEnabled && feature != nil }, set: { if !$0 { feature = nil } })
    }
}

struct ProPaywall: View {
    /// The drawer hosts the scrolling page and the pinned actions apart.
    enum Part { case whole, page, actions }

    let feature: ProFeature
    var part: Part = .whole
    @Binding var selection: String?
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.openURL) private var openURL

    private var selected: ProOption? {
        store.proOptions.first { $0.id == selection } ?? store.proOptions.first
    }

    var body: some View {
        switch part {
        case .whole:
            ScrollView { page }
                .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        case .page: page
        case .actions: actions
        }
    }

    // MARK: Page

    private var page: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            header
            VStack(alignment: .leading, spacing: DS.Space.m) {
                ForEach(benefits, id: \.image) { benefit in
                    BenefitRow(systemImage: benefit.image, title: benefit.title, detail: benefit.detail)
                }
            }
            options
            finePrint
        }
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.l)
        .padding(.bottom, DS.Space.m)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .task { if store.proOptions.isEmpty { await store.loadProOptions() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("Advent Praise Pro").dsEyebrow(tracking: 1.5).foregroundStyle(surface.brass)
            Text(feature == .airPlay ? "Put the words on the big screen" : "Play along with every hymn")
                .font(DS.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(feature == .airPlay
                 ? "Show the hymn on a church TV or projector, and turn the verses from your phone."
                 : "A piano plays each verse with you, at your tempo, while the words follow along.")
                .font(DS.Typeface.rowBody)
                .foregroundStyle(surface.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: [(image: String, title: LocalizedStringKey, detail: LocalizedStringKey)] {
        let player: (String, LocalizedStringKey, LocalizedStringKey) =
            ("pianokeys", "Piano accompaniment",
             "Every hymn with music: each verse and chorus, slow, medium or fast, and on the lock screen.")
        let follow: (String, LocalizedStringKey, LocalizedStringKey) =
            ("text.line.first.and.arrowtriangle.forward", "Follow along",
             "The line being sung lights up, and the page keeps the verse in view.")
        let airPlay: (String, LocalizedStringKey, LocalizedStringKey) =
            ("airplayvideo", "AirPlay in church",
             "Worship mode, full screen on a TV or projector. Your phone becomes the remote.")
        return feature == .airPlay ? [airPlay, player, follow] : [player, follow, airPlay]
    }

    // MARK: Options

    @ViewBuilder private var options: some View {
        if !store.proOptions.isEmpty {
            VStack(spacing: DS.Space.s) {
                ForEach(store.proOptions) { option in
                    OptionRow(option: option, isSelected: option == selected) {
                        selection = option.id
                        Haptics.play(.selection)
                    }
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
                    Button("Try again") { Task { await store.loadProOptions() } }
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

    @ViewBuilder private var finePrint: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if let selected, selected.renews {
                Text("\(selected.price) \(selected.term), renewing automatically until you cancel. Cancel any time in Settings, at least 24 hours before the renewal date.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.m) {
                Button("Terms of Use") { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
                Button("Privacy Policy") { openURL(AppInfo.privacyPolicyURL) }
            }
            .foregroundStyle(surface.tint)
            .frame(minHeight: DS.Size.hitTarget)
        }
        .font(DS.Typeface.caption)
        .foregroundStyle(surface.secondary)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: DS.Space.xs) {
            // No options (offline, or not set up): nothing to buy, so no buy button.
            if let selected {
                GlassButton(title: "Unlock Pro · \(selected.price)", tint: surface.brass,
                            isLoading: store.purchasing != nil, fullWidth: true) {
                    Task { await store.purchase(selected) }
                }
                .disabled(store.purchasing != nil || store.isRestoring)
            }
            GlassButton(title: "Restore purchases", kind: .secondary, isLoading: store.isRestoring, fullWidth: true) {
                Task { await store.restore() }
            }
            .disabled(store.purchasing != nil || store.isRestoring)
            .accessibilityHint("Unlocks Pro if this Apple Account has bought it before")
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.s)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pieces

private struct BenefitRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Environment(\.dsSurface) private var surface
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.panel) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(surface.brass)
                .frame(width: iconSize, height: iconSize)
                .background(RoundedRectangle.ds(DS.Radius.key).fill(surface.brass.opacity(DS.Fill.tintOn)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title).font(DS.Typeface.rowTitle)
                Text(detail).font(DS.Typeface.detail).foregroundStyle(surface.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One way to buy: a radio row. Content inside the drawer's glass, so an
/// opaque fill and outline, never glass.
private struct OptionRow: View {
    let option: ProOption
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.tile)
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? surface.tint : surface.controlBorder)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text(option.title).font(DS.Typeface.rowTitle)
                    Text(option.term).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                }
                Spacer(minLength: DS.Space.s)
                Text(option.price)
                    .font(DS.Typeface.label).monospacedDigit()
                    .foregroundStyle(surface.brass)
            }
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row + 8)
            .background(shape.fill(isSelected ? surface.tint.opacity(DS.Fill.tintSelected) : .primary.opacity(DS.Fill.row)))
            .overlay(shape.strokeBorder(isSelected ? surface.tint : surface.controlBorder.opacity(0.5),
                                        lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(DSPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.title), \(option.price), \(option.term)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
