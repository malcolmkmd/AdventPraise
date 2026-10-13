# Pro paywall (paywall2) — status

Branch `paywall2`, merged into `main`, not pushed. Every build was
`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build`,
run in the foreground, with **no warnings**. Screenshots and the video are in `build/shots/paywall2/` (gitignored),
taken on two new simulators, "AP Paywall2 iPhone" (iPhone 17 Pro, iOS 27.0) and "AP Paywall2 iPad" (iPad Pro 11-inch M5, iOS 27.0).

## What it is

The RevenueCat drawer paywall is replaced by a full sheet (`Store/ProPaywall.swift`), over a drawn picture (`Store/PaywallScenery.swift`):

- **Gold light** rises from the bottom edge and breathes (a 4.6 s ease in and out, forever): a steady warm floor, a pool of light at the bottom centre, and two soft columns through it, like window light on a floor. Gradients only, no images.
- **Raised hands** on the bottom edge, two `PraiseHandShape` vectors (forearm, palm and five finger capsules, unioned into one outline so the translucent fill shows no seams). They lift into view when the sheet lands (a 1.5 s critically damped spring, the second hand 0.12 s behind the first) and then sway about 1.6° each way, in opposite directions, every 3.4 s. Fingertips catch the gold; wrists sit in Evergreen. Their tips fade into the light so words scrolled over them stay readable.
- **The church logo** (`SDALogoShape`, the existing asset) in a gold gradient with a soft glow behind it that breathes with the light.
- **"Sing without limits"** under an "Advent Praise Pro" eyebrow, with one lead line that depends on what opened the paywall (Play, AirPlay, or More).
- **Six lines** on what Pro opens: MIDI sing-along player · Church mode with AirPlay casting · Service planner and unlimited playlists · Pitch pipe · Unlimited Memorise · Side-by-side translations. One column on iPhone, two on iPad.
- **Plans** from the RevenueCat offering (entitlement `pro`): **Yearly** is the primary row (bigger, with a "1 week free" pill when the App Store says this Apple Account can take the trial), **Lifetime** the quiet second. The selected plan's terms sit under the rows, and the pinned glass button reads "Start 1-week free trial" or "Unlock Pro · price". Nothing is hard-coded: title, price, term and trial length come from the product.
- **Restore purchases · Terms of Use · Privacy Policy** as one small row.
- **Support Advent Praise**: three one-off tips, Amen ("A quiet thank you"), Hallelujah ("Keeps the hymns ringing"), Hosanna ("Carries Advent Praise further"), each a card with the App Store price as its button. The caption says tips unlock nothing. A tip that goes through opens the thank-you sheet: the same light and hands, the logo, "Praise the Lord!" and "Thank you for supporting Advent Praise.", with an Amen button.
- **Pro already active** (opened from More): the plans become a "Pro is yours" card and there is no buy button; the tips stay.
- Liquid Glass on iOS 26 (the close button and the buy button are `.glass` / `.glassProminent`, bending the gold light); iOS 17–25 draws the Vesper fallback. Content on the sheet (plan rows, tip cards) is fill and outline, never glass.

### Where it opens from

- A locked Play or AirPlay, as before (`model.paywall = .player / .airPlay`); unlocking carries on with what was asked for.
- **New:** More → About → **Advent Praise Pro** (detail "Sing without limits", or "Yours" once Pro is active). This is how a Pro user reaches the tips. It sets `ProFeature.support`; unlocking from there does nothing extra.

### Store

- `Store/PurchaseConfig.swift` is still the one file with every product ID. Placeholders for Rolo: `ap_pro_yearly`, `ap_pro_lifetime`, `ap_tip_amen`, `ap_tip_hallelujah`, `ap_tip_hosanna`. Tips are consumables and belong to no entitlement.
- `Store/PurchaseStore.swift`: the paywall only sees plain values (`ProOption` with its `ProPlan` and optional `ProTrial`, `TipOption`); the RevenueCat packages and products stay inside the store. `loadStorefront()` loads the offering (or the products straight from the App Store when there is no offering), the trial eligibility (`checkTrialOrIntroDiscountEligibility`), and the tip prices. The trial is shown when the account is eligible or eligibility is unknown, and hidden when the App Store says ineligible or there is no intro offer. Plans are ordered Yearly, Lifetime, then anything else the offering carries.
- `tip(_:)` buys a consumable and sets `thankYouForTip`; it never touches `isPro`.
- **Mock offering (DEBUG, no RevenueCat key):** `PurchaseConfig.Mock` gives the Simulator two plans ($19.99 a year with a 1-week trial, $49.99 lifetime) and three tip prices ($0.99, $2.99, $9.99). Purchases in this mode wait 0.9 s and pretend to succeed (Pro unlocks; tips show the thank-you), so the whole flow can be exercised. Release builds without a key still say purchases aren't available.
- Analytics: the existing paywall and purchase events stay; tips add `tip_started`, `tip_completed`, `tip_cancelled`, `tip_failed` (product ID only, never an amount). `ProFeature.support` reports as `support`.

### Accessibility and motion

- Reduce Motion: no lift and no sway (the hands fade in), the light and the logo glow breathe in opacity only and more slowly, the words fade without rising.
- Dynamic Type: every font is a text style. At accessibility sizes the feature grid is one column and the tip cards stack.
- VoiceOver: the logo, light and hands are decoration (hidden, except the logo's label); plan rows read "Yearly, $19.99 per year, 1 week free trial" and carry the selected trait; tips read as "Amen tip, $0.99" with the blurb as the hint; Escape closes either sheet.
- Light and dark follow the reading surface: Paper / Parchment / Sepia keep their own ground with a brass picture; Muted and Black use the Stage near-black with a brighter gold.

### DEBUG launch arguments

- `-uiDebugPaywall YES` (or `player`, `airplay`, `support`) with `-uiDebugFree YES` opens the paywall at launch.
- `-uiDebugTipThanks YES` opens the thank-you sheet over it.
- `-uiDebugPaywallDelay 3.2` opens it that many seconds after launch, so a recording can start on the reader.
- `-uiDebugSurface black` / `paper` for dark and light.

## Verified (iOS 27.0 simulators, DEBUG build, mock offering)

Screenshots in `build/shots/paywall2/`:

| File | What |
| --- | --- |
| `iphone-dark.png`, `iphone-light.png` | iPhone 17 Pro, Black and Paper surfaces: logo, headline, six lines, Yearly (1 week free) selected, Lifetime, terms, the glass "Start 1-week free trial" over the hands. |
| `ipad-dark.png`, `ipad-light.png` | iPad Pro 11, page sheet: two-column feature grid, the plans, Restore · Terms · Privacy, the three tip cards in a row, the hands at the bottom. |
| `iphone-thankyou-dark.png` | The "Praise the Lord!" sheet over the paywall (`-uiDebugTipThanks`). |
| `iphone-pro-active-light.png` | Opened from More with Pro active: "Pro is yours" in place of the plans, no buy button, tips still offered. |
| `iphone-ax-dark.png` | Dynamic Type AX3 (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`): everything wraps, the pinned button stays. |
| `iphone-reduce-motion-dark.png` | Reduce Motion (set through the simulator's accessibility defaults): the hands are in place without a lift, the words only fade. |
| `open.mov` | 7 s, iPhone 17 Pro, dark: the reader, then the sheet rises, the words fade up in order, the hands lift and settle, the light breathes. Recorded with `xcrun simctl io recordVideo`; frames checked at half-second steps (`frames/`). |

Also checked:

- Build has no warnings (an unused-binding warning from the first pass was fixed).
- Plan selection: the terms line and the button follow the selected plan ("Start 1-week free trial" ↔ "Unlock Pro · $49.99").
- The mock purchase unlocks Pro and the paywall closes through the existing `onUnlocked` path; a mock tip opens the thank-you and leaves Pro alone.
- Only one simulator was booted at a time for the screenshots (the first attempt with two new simulators beside three others exhausted the Mac's process table and had to be cleared by hand).

Not checked here: a real RevenueCat offering (no key yet), VoiceOver by ear, iOS 17–25 rendering (no older runtime installed; the fallback is the existing `GlassButton` / material path).

## Not done / to decide

- The six feature lines are copy, as briefed. Gating hasn't changed: Pro still only locks the accompaniment player and AirPlay. Service planner, playlists, pitch pipe, Memorise and translations are not gated by this branch.
- Side-by-side translations isn't a feature in the app yet; the line is there because the brief lists it.
- `PaywallUnlockAllButton` (the old hymnal-bundle button in `LanguagePicker`) is untouched; it isn't shown since every hymnal is free.
