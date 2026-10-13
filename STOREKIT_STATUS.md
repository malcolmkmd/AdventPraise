# StoreKit 2, no RevenueCat (storekit) — status

Branch `storekit`, merged into `main` (after merging `main`, with playfix, into it), not pushed. All builds and tests
were run in the foreground on one simulator (iPhone 17 Pro, iOS 27.0) with **no warnings**:

- `xcodebuild … -configuration Debug -destination 'generic/platform=iOS Simulator' build`: succeeded
- `xcodebuild … -configuration Release -destination 'generic/platform=iOS Simulator' build`: succeeded
- `xcodebuild test …`: **22 tests in 4 suites pass** (FreePlays and PurchaseStore); the screenshot test is skipped
  unless asked for

## 1. Products to create in App Store Connect (app id1015021132)

The IDs must match exactly (`Store/PurchaseConfig.swift`). Nothing else needs configuring: there is no key, no server
and no entitlement setup.

| Type | Product ID | Reference name | Display name | Description | Price (ZAR base) | US price | Family Sharing |
|---|---|---|---|---|---|---|---|
| **Non-consumable** | `ap_pro_lifetime` | Advent Praise Pro | Advent Praise Pro | The unlimited sing-along player, church mode with AirPlay, the pitch pipe and unlimited Memorise. Bought once. | **R199.99** | $9.99 | Off (on is fine too; the app reads `currentEntitlements`, which includes family-shared purchases) |
| Consumable | `ap_tip_amen` | Tip: Amen | Amen | A quiet thank you. Unlocks nothing. | R19.99 | $0.99 | n/a |
| Consumable | `ap_tip_hallelujah` | Tip: Hallelujah | Hallelujah | Keeps the hymns ringing. Unlocks nothing. | R49.99 | $2.99 | n/a |
| Consumable | `ap_tip_hosanna` | Tip: Hosanna | Hosanna | Carries Advent Praise further. Unlocks nothing. | R99.99 | $4.99 | n/a |

In App Store Connect: **Monetization → In-App Purchases → +**. For each product, set the price with **South Africa (ZAR)**
as the base country and let Apple generate the other storefronts. Apple's ZAR price points may land a rand or so off the
USD equivalents above; the app shows whatever the App Store returns. Each product also needs a review screenshot (the
paywall, or the Support screen for the tips). Then:

1. Sign the **Paid Apps agreement** (Business) and fill in banking and tax.
2. Attach all four products to the version and **submit them with the build**. The first IAPs must go with an app
   version.
3. Sandbox test on TestFlight: five plays, then Play shows the paywall at the real price; buy, restore, tip.

## 2. RevenueCat removed

- SPM: the `purchases-ios-spm` package reference, the RevenueCat product dependency and its Frameworks build file are
  gone from `project.pbxproj`. Its pin is gone from `Package.resolved`. The remaining packages are PostHog and
  features-vote-sdk.
- Code: no `import RevenueCat`, no `Purchases.configure`, no API key, entitlement or offering in `PurchaseConfig`, and
  no `PurchaseConfig.Mock` offering.
- Privacy: the RevenueCat-only declarations (**Device ID** and **Purchase History**) are removed from
  `PrivacyInfo.xcprivacy`. ⚠️ Untick them on the live App Privacy label too (`docs/appstore/privacy-label.md`).
- Docs updated: `docs/appstore/{review-notes,STATUS,privacy-label,urls-checklist,screenshots}.md`,
  `ANALYTICS_PLAN.md`, `ANALYTICS_AUDIT.md`. Older `*_STATUS.md` files are history and still mention RevenueCat.

## 3. The StoreKit 2 store (`Store/PurchaseStore.swift`)

- **Launch.** `start()` (from `AdventPraiseApp.init`) starts listening to `Transaction.updates`, which covers Ask to
  Buy approvals, purchases on other devices, refunds and interrupted purchases. It also reads
  `Transaction.currentEntitlements`. **`isPro` = `ap_pro_lifetime` is among the verified, unrevoked entitlements.**
  It is re-read after every purchase, restore and update, so a refund removes Pro.
- **Products.** One `Product.products(for:)` call loads Pro and the three tips; the prices are `displayPrice`. If
  the call fails, or Pro or the tips are missing, `optionsFailed` is set and the paywall shows *"Couldn't reach the App
  Store for Pro's price. Check your connection and try again."* with **Try again**. The Support screen does the same
  for the tips. **"Purchases aren't available in this build" is gone everywhere.** A buy tap with no product loaded
  says so and reloads.
- **Purchase.** `product.purchase()` → `.success(.verified)`: `finish()`, then Pro is re-read (or the tip's thank-you
  shows). Each other outcome is handled:

  | Outcome | Message | Analytics |
  |---|---|---|
  | cancelled (result or `StoreKitError.userCancelled`) | none | `purchase_cancelled` / `tip_cancelled` |
  | `.pending` (Ask to Buy, payment check) | "Your purchase is waiting for approval. Pro unlocks as soon as it's approved." | `…_failed` `pending` |
  | `.success(.unverified)` | "The App Store couldn't confirm this purchase. Try Restore purchases in a moment." (not delivered, not finished) | `unverified` |
  | `StoreKitError.networkError` | "Couldn't reach the App Store. Check your connection and try again. You haven't been charged." | `store_error` |
  | `purchaseNotAllowed` | "Purchases aren't allowed on this device. Check Screen Time in Settings." | `not_allowed` |
  | anything else | "The purchase didn't go through. You haven't been charged." | `store_error` |
  | verified, but Pro not in entitlements | "The purchase went through, but Pro isn't active yet. Try Restore purchases." | `not_activated` |
  | product not loaded | "Pro isn't available right now…" (and reload) | `unavailable` |

  A pending tip approved later arrives through `Transaction.updates` and shows its thank-you.
- **Restore.** `AppStore.sync()`, then the entitlements are re-read. The messages are as before: restored, nothing
  found, or found but not Pro. A cancelled sign-in is quiet.
- **Analytics.** The events are unchanged. `product` is the App Store product ID. `PurchaseFailure` drops
  `not_configured` and adds `unavailable`, `pending`, `unverified` and `not_allowed`.
- **The paywall and Support UI** are unchanged apart from the failure box.
- **DEBUG.** StoreKit decides Pro, so a Debug run from Xcode exercises the real flow against the StoreKit
  configuration. **`-uiDebugPro YES`** unlocks Pro for screenshots. `-uiDebugFree` is gone because free is now the
  default. ⚠️ This changes old screenshot recipes: a plain `simctl launch` of a Debug build is now a free user, and
  without a StoreKit configuration (simctl can't apply one) the paywall shows Try again rather than a price.

## 4. Local testing: the StoreKit configuration

- `StoreKit/AdventPraise.storekit`: the four products, storefront **ZAF**, so the prices read R199.99 / R19.99 /
  R49.99 / R99.99. `StoreKit/AdventPraise-USD.storekit` is the same in **USA** dollars ($9.99 / $0.99 / $2.99 / $4.99).
  Both are plain local files, not synced from App Store Connect: the sync keys made StoreKit look for the real products,
  and nothing loaded.
- They sit outside the synchronized `AdventPraise/` folder, so they never go into the app bundle.
- **The shared scheme's Run action (Debug)** uses `StoreKit/AdventPraise.storekit`. Profile and Archive (Release) use
  none. To try dollars, pick the USD file in Edit Scheme → Run → Options → StoreKit Configuration. If Xcode doesn't show
  the file selected there, re-pick it once (the scheme path is `../../StoreKit/AdventPraise.storekit`; I couldn't check
  it in Xcode's UI from here). Debug → StoreKit → Manage Transactions lets you refund, approve Ask to Buy, and so on.
- **Tests** (`AdventPraiseTests/PurchaseStoreTests.swift`) open an `SKTestSession` on the ZAR file. They check that
  products load with prices, buying Pro gives Pro with no message, a tip only says thank you, Ask to Buy waits with
  its message, a simulated network failure gives `optionsFailed` and Try again then recovers, and Restore finds Pro
  bought elsewhere. Importing StoreKitTest trips a deprecation in Apple's own `SKTestTransaction.h`; that is silenced
  for the test target only (`-Xcc -Wno-deprecated-declarations`).

## 5. Why the TestFlight paywall had no hands

**Cause: the TestFlight build was archived from code older than the hands paywall.** It wasn't a second paywall
view in the app.

- "Play along with every hymn" was the headline of the first paywall (`1432f41`, Oct 12). The paywall3 rewrite
  replaced it with "Sing without limits" over `PaywallBackdrop` (light + crowd of hands) in `a6577f8`, Oct 13 13:59.
  It reached `main` after that.
- The `fastlane` branch (`bda83c2`, Oct 13 05:13, where `scripts/beta.sh` was set up) still has the old
  `ProPaywall.swift` with that headline and no `PaywallBackdrop`. The `beta` lane only checked that the tree was clean,
  not the branch, so a beta archived from there (or from `main` before 14:00) shipped the old paywall.
- In current code there is exactly **one** paywall view. Every entry goes through `.proPaywall` → `ProPaywallView` →
  `PaywallBackdrop`: Play when the free plays are used up (Lectern, playlists, lock screen, Siri, all through
  `player.onLocked`), AirPlay (`ExternalDisplay`, church mode), More → Pro, and `-uiDebugPaywall`. The tip thank-you
  uses the same backdrop.
- **Fix:** `fastlane beta` now also requires branch `main` (`ensure_git_branch`). The next TestFlight from `main` will
  show the hands and StoreKit prices.

**Screenshot** (`build/shots/storekit/`, gitignored):

- `paywall-from-play.png`: the simulator capture.
- `paywall-from-play-window.png`: the app's own window drawing.

Hymn 1 in Christ In Song, free plays used up, Play tapped through the same `player.start` the Lectern uses. The paywall
shows "Sing without limits", the free-plays lead, the four lines, the crowd of hands, and **"Unlock Pro · ZAR 199.99"**
from the StoreKit configuration. The simulator's region is US, so the rand shows as "ZAR"; a South African device
shows "R199.99". To retake: `scripts/storekit-shot.sh "iPhone 17 Pro"`.

## 6. Merging with playfix

`playfix` reached `main` first. It added **Keep playing** to the player's paywall for "a build that can't sell Pro" (no
RevenueCat key). With StoreKit every build can sell Pro, and a failed load offers Try again, so that button,
`PurchaseStore.canPurchase` and `AppServices.keepPlayingWithoutPro()` were dropped in the merge. Otherwise Keep
playing would be an unlimited free bypass whenever the App Store is unreachable. Kept from playfix: plays past the limit
aren't counted (`onNewPlay` guard), and the versioned free-play storage (`freePlays.v2`).

## Not done / to check

- The four products, the Paid Apps agreement and the IAP review submission in App Store Connect (section 1).
- Untick Device ID and Purchase History on the live App Privacy label.
- A sandbox purchase on a real device (TestFlight). Everything here ran in the simulator's StoreKit test environment.
- The disk was full (≈1–2 GB free) during this work. To avoid a fresh 2 GB DerivedData, the builds reused the stale
  `AdventPraise/build/dd` (last touched Oct 12). Nothing of other sessions was deleted.
