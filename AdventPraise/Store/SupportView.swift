//
//  SupportView.swift
//  Advent Praise
//
//  Support Advent Praise: the three one-off tips (Amen, Hallelujah,
//  Hosanna), a screen of its own under More → About, open to free and Pro
//  users alike. It is a Tools-style sheet on the reading surface (Done goes
//  back to More), with the paywall's logo and a little of its gold light so
//  the two read as one family. Tips are consumables that unlock nothing;
//  the screen says so. A tip that goes through opens the thank-you sheet:
//  "Praise the Lord!" over the light and the crowd of hands.
//

import SwiftUI

struct SupportView: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing: DS.Space.l) {
                header
                tipsList
                Text("Tips are a gift, not a purchase: they unlock nothing and never repeat. Advent Praise Pro is separate.")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Space.m)
            }
            .padding(DS.Space.l)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            // A touch of the paywall's light along the bottom edge.
            PaywallLight(palette: palette, intensity: 0.55).ignoresSafeArea()
        }
        .navigationTitle("Support Advent Praise")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.tips.isEmpty { await store.loadStorefront() }
        }
        .sheet(item: $store.thankYouForTip) { tip in
            TipThankYouSheet(tip: tip) { store.thankYouForTip = nil }
                .dsSurface(surface, paintsBackground: false)
        }
        .analyticsScreen(.support)
    }

    private var header: some View {
        VStack(spacing: DS.Space.m) {
            PaywallLogo(palette: palette, width: 64)
                .padding(.top, DS.Space.s)
            VStack(spacing: DS.Space.s) {
                Text("A one-off thank you")
                    .font(DS.Typeface.sheetTitle)
                    .dsBalancedWrap()
                    .accessibilityAddTraits(.isHeader)
                Text("Advent Praise is built by a few people in their spare time. If the hymns have been a blessing, a tip keeps them ringing.")
                    .font(DS.Typeface.rowBody)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var tipsList: some View {
        if !store.tips.isEmpty {
            VStack(spacing: DS.Space.s) {
                ForEach(store.tips) { tip in
                    TipRow(tip: tip, isLoading: store.tipping == tip.id, palette: palette) {
                        Task { await store.tip(tip) }
                    }
                    .disabled(store.tipping != nil)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tips")
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
                Text(store.isConfigured ? "Tips aren’t available right now. Check your connection and try again."
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
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.row)))
        }
    }
}

// MARK: - Row

/// One tip: its name and a line, with the App Store price as the button.
/// Content on the surface, so a fill and outline, no glass.
private struct TipRow: View {
    let tip: TipOption
    let isLoading: Bool
    let palette: PaywallPalette
    let action: () -> Void
    @Environment(\.dsSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle.ds(DS.Radius.tile)
        Button(action: action) {
            let stacked = typeSize.isAccessibilitySize
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.s))
                                 : AnyLayout(HStackLayout(spacing: DS.Space.m))
            layout {
                Image(systemName: tip.systemImage)
                    .font(.title3)
                    .foregroundStyle(palette.brass)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text(tip.name).font(DS.Typeface.rowTitle)
                    Text(tip.blurb)
                        .font(DS.Typeface.caption)
                        .foregroundStyle(surface.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !stacked { Spacer(minLength: DS.Space.s) }
                Group {
                    if isLoading {
                        ProgressView().controlSize(.small).tint(palette.brass)
                    } else {
                        Text(tip.price).monospacedDigit()
                    }
                }
                .font(DS.Typeface.button)
                .foregroundStyle(palette.brass)
                .frame(minWidth: 64, minHeight: 30)
                .padding(.horizontal, DS.Space.s)
                .background(Capsule().fill(palette.gold.opacity(palette.isDark ? 0.18 : 0.22)))
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row + 8, alignment: .leading)
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

/// After a tip: "Praise the Lord!" over the light and the crowd of hands.
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

#Preview("Support · paper") {
    let store = PurchaseStore()
    return NavigationStack { SupportView() }
        .environment(store)
        .dsSurface(.paper)
}

#Preview("Thank you") {
    TipThankYouSheet(tip: PurchaseConfig.tips[0].option(price: "R19.99")) {}
        .dsSurface(.black, paintsBackground: false)
}
