# UI2 — status

Branch `ui2` has five changes, in small commits. After each commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with no warnings in app code. Screenshots were taken on an iPhone 17 Pro simulator (iOS 27).

## 1. Memorise: fresh hidden words on every start

- Rounds already shuffled their hidden words. On short verses, though, Play again often dealt the same set again (for example 2 of 8 words: 1 in 28).
- `MemoryRound.pickTargets(from:count:avoiding:)` now takes the previous round's hidden words. If the shuffle repeats them, one hidden word is swapped for a shown one.
- Applies to:
  - Play again on the same verse: always a different set.
  - A level change: the count changes, so the set differs anyway.
  - Another verse: starts with no constraint.
- "All" hides every word, so it can't vary.

## 2. Centered alignment: balanced title, number and lyrics

- **Root cause:** in the reader header, the title had no `multilineTextAlignment`. A wrapped title was left-aligned inside a centered frame ("Come, Thou Fount Of / Every Blessing" hugging the left).
- **`BalancedWrap`** (`Design/BalancedText.swift`), like CSS `text-wrap: balance`:
  - Centered text wraps at the narrowest width that needs no extra lines (a binary search on `sizeThatFits`, cached per width).
  - Text that fits on one line is left alone.
  - Use it as `.dsBalancedWrap()`.
- **Centered header, laid out like a title page:**
  - Hymnal and number as a brass eyebrow above ("CHRIST IN SONG · 52").
  - The balanced title.
  - The other hymnals' numbers below ("AH 197 · SDAH 334"), only when there are any.
- **Centered lyrics:** each hymn line wraps on its own, balanced, so a long line no longer leaves one word ("grace;") alone. Line spacing is unchanged.
- Left alignment is unchanged.
- **Checked by screenshot:** hymn 52 before and after.
- **Not checked:** accessibility text sizes with centered text. The layout only narrows lines that already wrap, so it can't add lines.
- **Data issue spotted, not fixed:** English hymn 52, verse 1 reads "blessing,Tune" (missing space) in `english.json`.

## 3. All hymnals free

- **`PurchaseStore`:** no hymnal products, ownership checks or "unlock all". **Restore purchases still works**: it re-syncs with RevenueCat and reports whether Pro came back.
- **Globe switcher:** lists every hymnal with no "More hymnals" locked section.
- **Hymnals panel:** no Unlock all, no price pills, no Restore button (Restore stays in More), and no "Owned" label.
- **`RootView`:** no longer falls back to English after a refund.
- **`PurchaseConfig`:** the 6.x hymnal product IDs are removed.
- **What's New:** the tile now reads "Every hymnal, free".
- `LanguagePicker`, `PaywallLanguageRow` and `PricePill` keep their locked and purchasing states for previews. The app no longer produces those states.

## 4. Pro: the accompaniment player (RevenueCat entitlement `pro`)

- **`PurchaseConfig`:**
  - `proEntitlement = "pro"`.
  - `proOfferingID = nil` means the current offering.
  - `proProductIDs` are **placeholders** (`com.mDev.Advent_Praise.pro.annual` / `.pro.lifetime`), marked TODO for Rolo.
  - The product IDs are only used if no offering loads. Normally everything comes from the RevenueCat offering.
- **No prices in the app.** The paywall shows `localizedPriceString` from RevenueCat or the App Store. The title (Lifetime / Yearly / Monthly…) and the term ("per year", "One-time purchase") come from the package type and the subscription period.
- **The gate is in `HymnMIDIEngine.play()`:** while `isLocked()` is true, it calls `onLocked` (the paywall) instead of playing. That covers:
  - the Lectern's Play button (which skips the play haptic);
  - playlist Play;
  - lock-screen and headphone play;
  - the Play Hymn Siri intent, which opens the hymn and says "Playing along needs Advent Praise Pro".
- **Paywall** (`Store/ProPaywall.swift`), in the app's own drawer (`AdventDrawer`): Liquid Glass on iOS 26, Vesper material before. It reads the current reading surface.
  - Leads with the feature that asked for it: Player, or AirPlay.
  - Three benefit rows.
  - Radio rows for each option, with the App Store price in brass.
  - The renewal terms appear only when the selected option auto-renews.
  - Terms of Use (Apple's standard EULA) and Privacy Policy links.
  - "Unlock Pro · $price" (hidden when there is nothing to buy) and Restore purchases.
  - Close is the drawer's own ✕, plus drag down.
  - Unlocking closes the paywall and starts the hymn.
  - States: loading ("Getting prices from the App Store…"), unavailable (with Try again), and "Purchases aren't available in this build" when there's no API key.
- **Accessibility:**
  - Each option reads as "Yearly, $X, per year" with the selected trait.
  - Benefits are combined into one element each.
  - Restore has a hint.
  - Buttons are `GlassButton` (the system glass styles on iOS 26).
- **Checked by screenshot:** the paywall on Paper and Black, and over church mode.
- **Not checked:** the option rows and a real purchase. There is no RevenueCat key in this repo, and fake prices weren't allowed. This needs a key, the offering set up in RevenueCat, and a sandbox purchase.
- **Analytics:** `purchase_completed` now carries `product` (the package or product ID) instead of `hymnal`.

## 5. Church mode on a TV or projector (AirPlay / external display, Pro)

- **External screen:**
  - An `AppDelegate` (`@UIApplicationDelegateAdaptor`) gives `.windowExternalDisplayNonInteractive` sessions an `ExternalDisplaySceneDelegate`. All other roles keep SwiftUI's default.
  - That scene hosts **`ExternalHymnView`** on black:
    - Hymn number (brass) and title at the top.
    - The verse being sung, centered, at the phone's worship size scaled by screen height. A long verse shrinks to fit and never scrolls.
    - The position ("Verse 2 of 3") at the bottom.
    - The chorus uses the chorus face with its label.
  - Verse and hymn changes cross-fade.
  - When church mode is closed, it shows a title page: hymnal, big number, balanced title.
- **Shared state:** `ChurchPresentation` (in `AppServices`) holds the verse index, whether church mode is open, and whether a screen is connected. The phone moves the verse and the screen follows, so the phone is the remote.
- **AirPlay button in church mode:** `AirPlayRouteButton` wraps `AVRoutePickerView` (video devices first) in a 60 pt worship circle: interactive glass on iOS 26, the opaque raised circle before. A small picker draws the glyph and a clear full-size one takes the tap.
  - While the hymn is on a screen, the hymn chip shows a TV glyph, and VoiceOver adds "Also on the big screen".
- **Gating:**
  - Without Pro, the AirPlay button opens the paywall, leading with AirPlay.
  - If a screen connects (or is already connected) while church mode is open, the paywall shows.
  - The external screen itself shows a Pro card instead of the words. It updates live once Pro unlocks.
- Church mode now presents its own paywall, on its black surface. The root's paywall is disabled while the cover is up.
- **Checked:**
  - Church mode with the AirPlay button, by screenshot.
  - The external view's verse and title states, drawn on the phone with `-uiDebugExternal`.
  - The main window still launches with the app delegate in place.
- **Not checked:** a real external display. The simulator's I/O ▸ External Displays can't be driven from the command line, and there's no AirPlay receiver here. Please test with an Apple TV or HDMI adapter: connect and disconnect mid-hymn, and turn verses from the phone.
- **Decision for you:** with Pro locked, the app still owns the external scene, so a free user's AirPlay mirroring shows the Pro card instead of a mirror of the phone. If plain mirroring should work for free users, the delegate could decline the scene when Pro is off. That behaviour needs checking on a device.

## Merge into main

See the end of this file.

## DEBUG-only launch arguments (added in this branch)

`-uiDebugCentered YES`, `-uiDebugHymn 52`, `-uiDebugFree YES` (Pro locked; without a RevenueCat key, DEBUG builds otherwise unlock Pro), `-uiDebugPaywall YES`, `-uiDebugChurch YES`, `-uiDebugExternal verse|title`.

## Open items

- Rolo: the Pro product IDs, the `pro` entitlement and the current offering in RevenueCat, and the RevenueCat API key.
- Do 6.x hymnal buyers get Pro? Nothing grants it now. If they should, add their product IDs to the `pro` entitlement in RevenueCat; no code change is needed.
- Confirm the Privacy Policy URL (`AppInfo.privacyPolicyURL`, an existing TODO).
