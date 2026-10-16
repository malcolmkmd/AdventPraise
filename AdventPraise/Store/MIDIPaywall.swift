//
//  MIDIPaywall.swift
//  Advent Praise
//
//  The MIDI Piano screen: the MIDI unlock (`PurchaseConfig.midiProductID`)
//  sold on its own, in the Pro paywall's chrome (PaywallChrome, the light
//  and the hands). It opens from More's MIDI Piano card and the iPad
//  sidebar's MIDI Piano row, as ProFeature.midi through the same presenter
//  as Pro. It says what the unlock opens (the MIDI piano sing-along player,
//  with no free-play limit), one buy button with the App Store's price on it
//  (never written here; while it loads, a spinner; if it can't be loaded,
//  the screen says so and offers Try again), Restore purchases, Terms and
//  Privacy, and a note that Advent Praise Pro includes the piano, with See
//  Advent Praise Pro swapping the page for the Pro paywall. Buying the piano
//  (or restoring it, or Pro) closes the sheet; the purchase itself plays
//  the purchase haptic. The player's gate, which sells Pro and the piano
//  side by side, is ProPaywallView; nothing here touches it.
//

import SwiftUI

struct MIDIPaywallView: View {
    let onClose: () -> Void
    /// See Advent Praise Pro: the presenter shows the Pro page in this sheet.
    let onSeePro: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the opening: the hands lift, the words rise.
    @State private var opened = false

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        PaywallChrome(opened: $opened, onClose: onClose) {
            VStack(spacing: DS.Space.l + DS.Space.xxs) {
                PaywallHeader(eyebrow: "Bought once",
                              title: "MIDI Piano",
                              lead: "The MIDI piano sing-along player, with no free-play limit. Every hymn with a piano, as often as you like.")
                FeatureLine(systemImage: "pianokeys", text: "Unlimited MIDI sing-along player", palette: palette)
                    .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.25))
                offer
                proHint
                PaywallLegal(restoreHint: "Unlocks the MIDI piano, or Pro, if this Apple Account has bought it before")
            }
        } actions: {
            actions
        }
        .task {
            if store.midiOption == nil { await store.loadStorefront() }
        }
    }

    // MARK: Offer

    /// What the buy button sells, in words. Owned already (Restore while
    /// this is up, or a debug launch): the owned card instead.
    @ViewBuilder private var offer: some View {
        if store.midiOwnership.isOwned {
            MIDIOwnedCard(ownership: store.midiOwnership, palette: palette)
        } else if store.midiOption != nil {
            Text("One purchase, no subscription. Yours for good, on every device signed in with this Apple Account. It opens the piano alone: the worship display, widgets and the rest stay Pro.")
                .font(DS.Typeface.caption)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            PaywallPriceStatus(failure: "Couldn’t reach the App Store for the MIDI Piano price. Check your connection and try again.")
        }
    }

    // MARK: Pro

    /// Pro includes the piano; a quieter way over to it.
    @ViewBuilder private var proHint: some View {
        if !store.isPro {
            VStack(spacing: DS.Space.xs) {
                Text("Advent Praise Pro includes the MIDI piano, with the worship display, widgets, the pitch pipe and more.")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("See Advent Praise Pro", action: onSeePro)
                    .font(DS.Typeface.button)
                    .foregroundStyle(palette.brass)
                    .frame(minHeight: DS.Size.hitTarget)
                    .accessibilityHint("Shows what Pro opens, in place of this screen")
                    .accessibilityIdentifier("midiPaywall.seePro")
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Space.m)
            .background(RoundedRectangle.ds(DS.Radius.card).fill(.primary.opacity(DS.Fill.row)))
            .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion, delay: 0.3))
        }
    }

    // MARK: Actions

    /// The one buy button, with the App Store's price on it. Nothing while
    /// the price is missing, or once the piano is owned.
    @ViewBuilder private var actions: some View {
        if !store.midiOwnership.isOwned, let midi = store.midiOption {
            GlassButton(title: "Unlock MIDI Piano · \(midi.price)", tint: palette.brass,
                        isLoading: store.purchasingID == midi.id, fullWidth: true) {
                Task { await store.purchase(midi, feature: .midi) }
            }
            .disabled(store.purchasing || store.isRestoring)
            .accessibilityHint("One-time purchase of the MIDI piano player")
            .accessibilityIdentifier("midiPaywall.unlock")
        }
    }
}

// MARK: - Pieces

/// In place of the offer once the piano is owned: on its own, or with Pro.
private struct MIDIOwnedCard: View {
    let ownership: MIDIOwnership
    let palette: PaywallPalette
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(palette.brass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text("The MIDI piano is yours").font(DS.Typeface.panelTitle)
                Text(ownership == .includedWithPro ? "Included with Advent Praise Pro." : "Bought once, yours for good.")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
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

#Preview("MIDI Piano · dark") {
    let store = PurchaseStore()
    return MIDIPaywallView(onClose: {}, onSeePro: {})
        .environment(store)
        .dsSurface(.black, paintsBackground: false)
}

#Preview("MIDI Piano · paper") {
    let store = PurchaseStore()
    return MIDIPaywallView(onClose: {}, onSeePro: {})
        .environment(store)
        .dsSurface(.paper, paintsBackground: false)
}
