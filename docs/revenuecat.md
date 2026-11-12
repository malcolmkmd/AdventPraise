# RevenueCat — Advent Praise

Purchases on iOS (7.1+) and Android go through RevenueCat. This file is the
dashboard set-up the code expects. Code: `AdventPraise/Store/PurchaseConfig.swift`,
`PurchasesClient.swift`, `PurchaseStore.swift` (iOS) and `app/.../billing/` in the Android repo, [malcolmkmd/AdventPraise-Android](https://github.com/malcolmkmd/AdventPraise-Android).

## Project

**Advent Praise** in RevenueCat, with two apps:

| App | Store | Identifier | Public SDK key goes in |
|---|---|---|---|
| Advent Praise (iOS) | App Store | `com.mDev.Advent-Praise` (id1015021132) | `PurchaseConfig.revenueCatAPIKey` (`appl_…`) |
| Advent Praise (Android) | Google Play | `com.mDev.AdventPraise` | `local.properties` (Android repo) → `revenuecat.androidKey` (`goog_…`) |

## Entitlement

`pro` (display name "Advent Praise Pro"). Attached products:

| Product | Store | Type | Notes |
|---|---|---|---|
| `ap_pro_annual` | App Store | Auto-renewable subscription | Annual Pro, subscription group "Advent Praise Pro". 3-day free trial. On sale. |
| `ap_pro_monthly` | App Store | Auto-renewable subscription | Monthly Pro, same group. No trial. On sale. |
| `ap_pro_lifetime` | App Store | Non-consumable | Pro bought once in 7.0.x. Not offered. Buyers keep Pro for life. |
| `ap_midi_unlock` | App Store | Non-consumable | MIDI Piano, sold in 7.0.1 only. Attached so its buyers have all of Pro. Not offered from 7.1. |
| `ap_pro_lifetime` | Google Play | One-time product (non-consumable) | Same ID as iOS. Not offered. |

The tips (`ap_tip_amen`, `ap_tip_hallelujah`, `ap_tip_hosanna`) are consumables. They
are imported as products but attached to **no** entitlement and are in **no** offering:
the Support screen loads them by product ID.

The 6.x hymnal products are not in RevenueCat. Every hymnal is free; Restore purchases
still re-syncs them with the App Store.

## Offering

`default`, marked **Current**. The paywall sells two packages. Both unlock `pro`.
Prices are whatever the stores charge; the app reads them from the offering and
never writes them down.

| Package | Type | Store product | Trial |
|---|---|---|---|
| `$rc_annual` | Annual | `ap_pro_annual` | 3-day free trial for new subscribers |
| `$rc_monthly` | Monthly | `ap_pro_monthly` | none |

The paywall chooses those two by product id (`ap_pro_annual`, then the
`$rc_annual` package; `ap_pro_monthly`, then `$rc_monthly`). Annual is the
main plan when the offering doesn't say otherwise. A saving is shown only
when both store prices can be compared and a year of monthly costs more.
Lifetime, MIDI and any other package in the offering are not sold. If monthly
is missing, annual is still sold on its own.

### Experiments

RevenueCat Experiments assigns an offering and serves it as the current one.
The paywall reads three metadata strings from that offering. A missing or
unrecognised value falls back as below, which is variant A (today's paywall).

| Key | Values | When missing or unknown |
|---|---|---|
| `paywall_variant` | `a`, `b` | `a` |
| `first_package` | `$rc_annual`, `$rc_monthly` | `$rc_annual` (shown first and selected) |
| `cta` | `default`, `try_for_zero` | `default` (the existing subscribe button) |

`try_for_zero` changes the button only when the selected plan has a free trial
this Apple Account can still start: "Try for R0.00", with zero from the
product's price formatter, and a line under it such as "3 days free, then
R29.99/month" from that product's introductory offer and price. No eligible
trial: the ordinary Subscribe button, and the price stays on the plan. Trial
length and eligibility are never written in the app.

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
  the Android repo's `README.md`, and give RevenueCat a service-account JSON with access to the
  Play Console (RevenueCat → Android app → *Service account credentials JSON*).
