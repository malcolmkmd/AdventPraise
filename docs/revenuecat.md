# RevenueCat — Advent Praise

Purchases on iOS (7.1+) and Android go through RevenueCat. This file is the
dashboard set-up the code expects. Code: `AdventPraise/Store/PurchaseConfig.swift`,
`PurchasesClient.swift`, `PurchaseStore.swift` (iOS) and `android/app/.../billing/` (Android).

## Project

**Advent Praise** in RevenueCat, with two apps:

| App | Store | Identifier | Public SDK key goes in |
|---|---|---|---|
| Advent Praise (iOS) | App Store | `com.mDev.Advent-Praise` (id1015021132) | `PurchaseConfig.revenueCatAPIKey` (`appl_…`) |
| Advent Praise (Android) | Google Play | `com.mDev.AdventPraise` | `android/local.properties` → `revenuecat.androidKey` (`goog_…`) |

## Entitlement

`pro` (display name "Advent Praise Pro"). Attached products:

| Product | Store | Type | Notes |
|---|---|---|---|
| `ap_pro_lifetime` | App Store | Non-consumable | Pro, R199.99 tier. On sale. |
| `ap_midi_unlock` | App Store | Non-consumable | MIDI Piano, sold in 7.0.1 only. Attached so its buyers have all of Pro. Not offered from 7.1. |
| `ap_pro_lifetime` | Google Play | One-time product (non-consumable) | Same ID as iOS. |

The tips (`ap_tip_amen`, `ap_tip_hallelujah`, `ap_tip_hosanna`) are consumables. They
are imported as products but attached to **no** entitlement and are in **no** offering:
the Support screen loads them by product ID.

The 6.x hymnal products are not in RevenueCat. Every hymnal is free; Restore purchases
still re-syncs them with the App Store.

## Offering

`default`, marked **Current**. One package:

| Package | Type | App Store product | Play product |
|---|---|---|---|
| `$rc_lifetime` | Lifetime | `ap_pro_lifetime` | `ap_pro_lifetime` |

That is exactly what the paywall shows: one "Unlock Pro · price" button. The app takes
the package that sells `ap_pro_lifetime` (Lifetime first) and ignores anything else in
the offering, so a stray MIDI package would never be sold.

## What still has to be done by hand

- **App Store Connect In-App Purchase key (.p8)** → RevenueCat → iOS app → *In-app
  purchase key configuration*. RevenueCat needs it to validate StoreKit 2 transactions.
  Without it purchases and Restore fail.
- **App Store Connect API key** (optional) → RevenueCat iOS app, to import products and
  prices automatically.
- **App Store Server Notifications** (recommended): paste RevenueCat's URL into App Store
  Connect → App Information → Production (and Sandbox) Server URL, so refunds reach
  RevenueCat at once.
- **Local StoreKit testing**: Xcode's StoreKit configuration (`StoreKit/Products.storekit`)
  signs test transactions with its own certificate. Upload it (Xcode → Editor → Save
  Public Certificate) to the RevenueCat iOS app, or test with a Sandbox account instead.
- **MIDI Piano off sale**: when 7.1 is live, App Store Connect → In-App Purchases →
  MIDI Piano → remove from sale. 7.0.1 already shows Pro alone when the product doesn't
  load, and owners can still restore it.
- **App Privacy label**: tick Purchases → Purchase History and Identifiers → Device ID
  (not linked, App Functionality). See `docs/appstore/privacy-label.md`.
- **Google Play** (Android): create the app, then the products listed in
  `android/README.md`, and give RevenueCat a service-account JSON with access to the
  Play Console (RevenueCat → Android app → *Service account credentials JSON*).
