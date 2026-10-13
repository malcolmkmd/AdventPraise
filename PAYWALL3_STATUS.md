# Pro paywall, round three (paywall3) — status

Branch `paywall3`, on top of paywall2 (`PAYWALL2_STATUS.md`), merged into `main`, not pushed. Every build was
`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build`,
run in the foreground, with **no warnings**. Screenshots and the video are in `build/shots/paywall3/` (gitignored),
taken on the paywall2 simulators, "AP Paywall2 iPhone" (iPhone 17 Pro, iOS 27.0) and "AP Paywall2 iPad"
(iPad Pro 11-inch M5, iOS 27.0), one booted at a time and shut down after.

## What changed

### 1. Pro is a one-time purchase

- **One product.** `PurchaseConfig.proProductID = "ap_pro_lifetime"` (non-consumable, placeholder for Rolo). The
  yearly product, its ID, `ProPlan`, `ProTrial`, the trial-eligibility check, the plan ordering and the renewal
  copy are all gone.
- **`PurchaseStore.proOption`** is one `ProOption` (`id`, `price`), or nil until loaded / when it can't be.
  `loadStorefront()` takes, from the RevenueCat offering, the package whose product is `proProductID`, else the
  Lifetime package, else any non-consumable; auto-renewing packages are ignored even if someone leaves one in the
  offering. With no offering it loads the product straight from the App Store. `purchasing` is now a Bool.
- **The paywall** shows the logo, "Sing without limits", the lead line, five feature lines, one caption
  ("One purchase, no subscription. Yours for good, on every device signed in with this Apple Account."),
  Restore purchases · Terms of Use · Privacy Policy, and one pinned glass button, **"Unlock Pro · R199.99"**, the
  price exactly as the App Store gives it. No plan rows, no selection, no trial pill. Pro active (from More): the
  "Pro is yours" card and no button, as before.
- **"Side-by-side translations"** is removed from the feature list (the feature doesn't exist). Five lines: MIDI
  sing-along player · Church mode with AirPlay casting · Service planner and unlimited playlists · Pitch pipe ·
  Unlimited Memorise. Two columns on iPad (3 + 2).
- **Mock offering (DEBUG, no key):** one option at **R199.99**; tips at R19.99 / R49.99 / R99.99. Stand-ins only.
- The More → About → **Advent Praise Pro** row still opens the paywall (`ProFeature.support`); its lead now reads
  "Everything below, bought once and yours for good."

### 2. Tips are their own screen in More

- **More → About → Support Advent Praise** ("Leave a tip"), right under the Pro row, for free and Pro users alike.
  It is `Store/SupportView.swift`, presented as a Tools-style sheet through `ExtraSheet.support` (Extras.swift), so
  it has the reading surface, the inline title, a Done button, and **Done or a swipe goes back to More** at that row
  (`model.leaveMore` / `returnToMore`, like the Tools). `-uiDebugSheet support` opens it at launch.
- **Content:** the paywall's logo (64 pt, glowing), "A one-off thank you", a lead line, the three tips as rows
  (icon · name · blurb · price capsule as the button: Amen ♥ · Hallelujah ♪ · Hosanna ✦), and a caption that tips
  unlock nothing and never repeat. A touch of the paywall's gold light along the bottom (`PaywallLight` at 0.55).
  Loading, offline and not-configured states match the paywall's. `TipDefinition` now carries the SF Symbol, and
  `TipDefinition.option(price:)` builds the `TipOption`.
- **The thank-you sheet** (`TipThankYouSheet`, "Praise the Lord!" over the light and the crowd) moved with the tips
  and is presented from SupportView (`store.thankYouForTip`). `-uiDebugTipThanks YES` now goes with
  `-uiDebugSheet support`.
- The paywall no longer has a tips section or the thank-you sheet. `PaywallRise` is shared (internal) for the
  thank-you's fade-up.
- Analytics: a new screen `support`; the tip events are unchanged.

### 3. A crowd of raised hands

`PaywallScenery.swift`: `PaywallHands` is now a crowd, built by `PraiseCrowd.layout(width:height:)`:

- **Three rows**, back to front. Front row: full height, full opacity, the gold-to-green gradient. Middle: 0.74
  scale, wrists 0.26 of a hand up, 62 % opacity, greener. Back: 0.52 scale, 0.48 up, 40 %, greener still. Rows
  behind are offset half a step so they show between the hands in front. Each hand varies ±13 % in size, leans
  4–14° either way, is flipped or not, and sits a little higher or lower; a fixed sine hash decides, so the crowd
  is identical every opening. The count comes from the width: about 17 hands on the iPhone, about 36 on the iPad.
- **Lift-in:** each hand rises on its own beat (a 1.5 s spring, delays 0.12–0.6 s, front row first, then the rows
  behind), so the crowd fills in rather than snapping up.
- **Sway:** each hand has its own period (2.9–4.4 s), amplitude (1.1–2.3°), phase (0.9–2.7 s) and a 1.5–4 pt bob.
  Every hand is a `CrowdHand` with its own `@State`, driven by `repeatForever` animations, so all motion is Core
  Animation on separate layers; nothing is evaluated per frame in SwiftUI. ~36 layers on iPad is well within 60 fps
  (the simulator shows no dropped frames in the recording; not measured on a device).
- **Legibility:** a top fade on the whole crowd (12 % → 50 % at 0.3 → 100 % at 0.62) plus the row opacities keep
  the terms line readable where it rests over the fingertips; the pinned button is glass over it.
- **Reduce Motion:** no lift and no sway, the hands fade in; the light breathes in opacity only (unchanged).
- The thank-you sheet gets the same crowd at a smaller front-row height (150).

## Verified (iOS 27.0 simulators, DEBUG build, mock offering)

| File | What |
| --- | --- |
| `iphone-dark.png`, `iphone-light.png` | iPhone 17 Pro, Black and Paper: logo, headline, five lines, the one-purchase caption, Restore · Terms · Privacy, the crowd, "Unlock Pro · R199.99". |
| `ipad-dark.png` | iPad Pro 11, page sheet: two-column features, the crowd across the full width (three rows, ~36 hands). |
| `more-dark.png` | The More drawer: About → Advent Praise Pro, then **Support Advent Praise · Leave a tip**. |
| `more-support-light.png`, `ipad-support-light.png` | The Support screen on Paper (iPhone and iPad): logo, title, three tip rows, caption. |
| `iphone-thankyou-dark.png` | "Praise the Lord!" over the Support screen after a tip (`-uiDebugTipThanks`). |
| `open.mov` | 6.0 s, iPhone 17 Pro, dark: the reader, the sheet rises, the words fade up, the crowd lifts in row by row and settles into its sway. `xcrun simctl io recordVideo`, h264. |
| `frames/t*.png` | A screenshot burst through the opening (every ~0.45 s) used to check the lift: nothing at 3.3 s, half up at 3.8 s, settled by 4.3 s, swaying after. |

Also checked:

- Both builds had no warnings.
- Not tapped through this round (no touch driver from the shell): the mock purchase and a mock tip. The purchase
  path is paywall2's with the option singular; the tip path is unchanged and its thank-you presentation from the
  Support screen was verified with `-uiDebugTipThanks`.
- Only one simulator was booted at a time; each was shut down afterwards (none booted at the end).
- A simulator whose recorder is killed (not interrupted) is left saying "Host recording is already in progress";
  shutting it down and booting again clears it.

Not checked here: a real RevenueCat offering (no key yet); frame rate on a device; VoiceOver by ear; iOS 17–25
rendering (no older runtime installed).

## For Rolo (RevenueCat / App Store Connect)

- One non-consumable, `ap_pro_lifetime` (placeholder ID in `PurchaseConfig.swift`), attached to the `pro`
  entitlement and in the current offering as the **Lifetime** package. Price tier for R199.99.
- Three consumables for the tips (`ap_tip_amen`, `ap_tip_hallelujah`, `ap_tip_hosanna`), no entitlement.
- No subscription products. If one is left in the offering the app ignores it.

## Not done / to decide

- Gating is unchanged: Pro still only locks the accompaniment player and AirPlay; the other four lines are copy.
- `PaywallUnlockAllButton` (the old hymnal-bundle button) is still untouched and unused.
