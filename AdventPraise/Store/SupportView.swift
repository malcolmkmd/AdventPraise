//
//  SupportView.swift
//  Advent Praise
//
//  Support Advent Praise: the three one-off tips (Amen, Hallelujah,
//  Hosanna), open to free and Pro users alike. It opens from More exactly
//  like the Pro paywall (`paywallSheet`, PaywallChrome): the full sheet over
//  the light and the crowd of hands, Close at the top, the header, and one
//  floating button that gives the tip chosen above it. It opens over More,
//  which stays open under it; closing it leaves More where it was. Tips
//  are consumables that unlock nothing; the screen says so. A tip that
//  goes through opens the thank-you sheet: "Praise the Lord!" over the
//  light and the hands.
//

import SwiftUI

extension View {
    /// Presents Support Advent Praise while `isPresented` is true.
    func supportSheet(isPresented: Binding<Bool>) -> some View {
        paywallSheet(isPresented: isPresented) {
            SupportView { isPresented.wrappedValue = false }
        }
    }
}

struct SupportView: View {
    let onClose: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the opening: the hands lift, the words rise.
    @State private var opened = false
    /// The tip the button gives. Nil: the middle one, Hallelujah.
    @State private var chosenID: String?

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    private var chosen: TipOption? {
        store.tips.first { $0.id == chosenID } ?? store.tips.dropFirst(store.tips.count / 2).first
    }

    var body: some View {
        @Bindable var store = store
        PaywallChrome(opened: $opened, onClose: onClose) {
            VStack(spacing: DS.Space.l + DS.Space.xxs) {
                PaywallHeader(
                    eyebrow: "SUPPORT THE MINISTRY",
                    title: "A Note from the Developer",
                    lead: "Hi, I’m Malcolm. I built Advent Praise in my spare time to keep sacred hymns accessible and uplift hearts in worship. If this music has been a blessing to your devotional life or home, a one-time tip helps cover ongoing costs and sustains this independent ministry.")
                tipsList
                Text("Tips are a one-time gift to support the app; they do not recur or unlock digital features. Advent Praise Pro is separate.")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Space.m)
            }
        } actions: {
            actions
        }
        .task {
            if store.tips.isEmpty { await store.loadStorefront() }
        }
        .sheet(item: $store.thankYouForTip) { tip in
            TipThankYouSheet(tip: tip) { store.thankYouForTip = nil }
                .dsSurface(surface, paintsBackground: false)
        }
        .analyticsScreen(.support)
    }

    @ViewBuilder private var tipsList: some View {
        if !store.tips.isEmpty {
            VStack(spacing: DS.Space.s) {
                ForEach(Array(store.tips.enumerated()), id: \.element.id) { index, tip in
                    TipRow(tip: tip, isChosen: tip == chosen, palette: palette) {
                        Haptics.play(.selection)
                        chosenID = tip.id
                    }
                    .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.25 + Double(index) * 0.05))
                }
            }
            .disabled(store.tipping != nil)
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
                Text("Couldn’t reach the App Store for the tips. Check your connection and try again.")
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

    /// The one button: the chosen tip, with the App Store's price on it.
    @ViewBuilder private var actions: some View {
        if let tip = chosen {
            GlassButton(title: "Support the Ministry · \(tip.price)", tint: palette.brass,
                        isLoading: store.tipping != nil, fullWidth: true) {
                Task { await store.tip(tip) }
            }
            .disabled(store.tipping != nil)
            .accessibilityHint("A one-off tip. It unlocks nothing.")
        }
    }
}

// MARK: - Row

/// One tip: its name and a line, with the App Store price. Tapping it
/// chooses it for the button below. Content on the surface, so a fill and
/// outline, no glass; the chosen one is brass.
private struct TipRow: View {
    let tip: TipOption
    let isChosen: Bool
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
                HStack(spacing: DS.Space.s) {
                    Text(tip.price)
                        .font(DS.Typeface.button)
                        .monospacedDigit()
                        .foregroundStyle(isChosen ? palette.brass : surface.secondary)
                    Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isChosen ? palette.brass : surface.secondary.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row + 8, alignment: .leading)
            .background(shape.fill(isChosen ? palette.gold.opacity(palette.isDark ? 0.14 : 0.18)
                                            : .primary.opacity(DS.Fill.row)))
            .overlay(shape.strokeBorder(isChosen ? palette.brass.opacity(0.7) : surface.controlBorder.opacity(0.3),
                                        lineWidth: isChosen ? 1.5 : 1))
            .contentShape(shape)
            .animation(.snappy(duration: 0.2), value: isChosen)
        }
        .buttonStyle(DSPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(localized: tip.name)) tip, \(tip.price)")
        .accessibilityHint(Text(tip.blurb))
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
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

#Preview("Support · dark") {
    let store = PurchaseStore()
    return SupportView {}
        .environment(store)
        .dsSurface(.black, paintsBackground: false)
}

#Preview("Support · paper") {
    let store = PurchaseStore()
    return SupportView {}
        .environment(store)
        .dsSurface(.paper, paintsBackground: false)
}

#Preview("Thank you") {
    TipThankYouSheet(tip: PurchaseConfig.tips[0].option(price: "R19.99")) {}
        .dsSurface(.black, paintsBackground: false)
}
