# AdventPraise 7.0 — build status

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with no warnings in app code (Xcode 27.1, Swift 6 language mode, complete strict concurrency). Checked on the iPhone 17 Pro simulator (What's New, the reader, the number pad, church mode) and on an iPad Pro 11-inch simulator (sidebar hymn list beside the reader).

## Finished

- **New app replaces the TCA one.** `AdventPraisesKit`, the old `AdventPraises` target, its tests and the Composable Architecture dependency are gone. History is kept. The new project is `AdventPraise.xcodeproj`, which uses a folder-synced `AdventPraise/` group: drop files in and they build.
- **Identity:** `com.mDev.Advent-Praise`, version 7.0 build 1, team 4729Z4LTF4, automatic signing, iOS 17.0 minimum, iPhone + iPad.
- **UI:** Vesper, from `design/Components`, lives in `AdventPraise/Design/` and is what the app draws. `ReaderToolbar` is the Lectern. The number pad, hymn rows, hymnal list, What's New, and Appearance are the design-system views (`HymnNumberPad`, `HymnRow`, `LanguagePicker`, `WhatsNewSheet`, `AppearanceControls`), with `GlassCard` / `GlassButton` inside them. Lyrics use `ChapterVerseBlock` and `ChorusBlock`. Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`) is the iOS 26 path; iOS 17–25 uses `dsGlass` materials, and church-mode controls stay opaque on that path. On iPad a `NavigationSplitView` (both columns visible) puts search, hymn rows, favourites and playlists beside the reader; the Lectern stays centred at 560 pt, the number pad opens as a popover, and `LanguageMenuButton` sits in the detail toolbar. The library button reveals the sidebar.
- **Translations: the nine hymnals 6.3 listed ship** (English, Chichewa, Tswana, Xhosa, Sotho, Shona, Venda, Zulu, Ndebele; see `LANGS_STATUS.md`). The other 16 the betas carried are out of the bundle; `convert_hymnals.py --all` still builds them. They live in `AdventPraise/Resources/Hymnals/<key>.json`, one minified file per language, decoded only when opened. The format is `{number,title,refs,blocks:[{t:"v"|"c",n,l:[lines]}]}`. Each chorus is stored once and there is no markup.
  - `Tools/convert_hymnals.py` rebuilds them: `python3 Tools/convert_hymnals.py ../handoff AdventPraise/Resources/Hymnals`.
  - English, Zulu and Ndebele start from the legacy text (`convert_legacy.py` output). Where a legacy line or title closely matches the cis-v2 version but differs, the cis-v2 version is used. That changed 23 + 51 titles and a handful of lines ("Evry" → "Every", punctuation).
  - The other six come from cis-v2. Stray HTML entities and `<br>` fragments are cleaned out.
  - Each language's own chorus label (cis-v2 `refrain_label`) is used; all nine bundled ones say "Chorus".
- **Purchases (RevenueCat 5.x):** buy a hymnal, Restore purchases (in the Hymnals panel and in More), and ownership taken from CustomerInfo. If a hymnal is refunded, the reader falls back to English. Every product ID and the language→product mapping are in **one file**: `AdventPraise/Store/PurchaseConfig.swift`.
- **PostHog (3.x):** anonymous only. No identify, `personProfiles = .never`, autocapture, swizzling, screen views, session replay, surveys and error autocapture all off. Events never include prices or amounts. The event list is in `Services/Analytics.swift`.
- **MIDI accompaniment:** 245 Cyber Hymnal files for Christ In Song (English), with a player in the Lectern. It has play/pause, restart, a scrub bar, tempo, loop, verse- and line-following in the reader, the lock screen, Siri "Play hymn", and playlist auto-advance. The audio session and engine are only claimed on the first play. Add files with `Tools/sync_midi.py`; no code change needed. See `MIDIPLAYER_STATUS.md`.
- **What's New:** "Welcome to Advent Praise 7" appears once (keyed on version 7.0, same UserDefaults key as before). It's the Stage sheet from the design system: serif title, four glass feature tiles, "Try Worship Mode" (opens church mode) and Continue.
- **Church mode:** reached from the Church tile, More, What's New, or Siri. The overlay is `WorshipModeControls`: a hymn chip (tap for a number pad), a globe (switch translation, same number) and leave at the top; previous, text size and next at the bottom. Text size is persisted and works with Dynamic Type and large print. Controls hide after about four seconds; a tap brings them back. See `CHURCH_STATUS.md`.
  - Black, high-contrast ground. One verse or chorus at a time, with the chorus repeated after each verse. A verse too long for the chosen size scrolls. Pinch to size the text; double-tap resets it.
  - Tap the right of the screen or the next control to go forward; tap the left or the back control to go back; swipe either way. At the end, next opens the following hymn.
  - The screen stays awake. The status bar and home indicator are hidden.
- **Haptics:** one engine (`Services/Haptics.swift`) with semantic events, Core Haptics where the hardware has it and UIKit otherwise, rate limiting, and a Haptics switch in More. See `HAPTICS_STATUS.md`.
- **Large print:** Appearance’s Print control, and the toggle in More, use the design scale (26–40 pt). “Chorus after every verse” stays in More.
- **Send a correction / Request a hymnal or feature** (in More): opens Mail with the hymnal, hymn, current text and app/iOS version filled in. If Mail isn't set up, it opens a `mailto:` link instead.
- **Siri / Shortcuts (App Intents):** Open Hymn N, Play Hymn N (opens the hymn and plays it when it has accompaniment), Next Hymn (follows the active playlist), and Start Church Mode, each with App Shortcut phrases.
- **Features carried over from the legacy app:**
  - Number pad with live title preview and a Go button. It won't accept numbers past the end of the hymnal, and it shows recent hymns.
  - Word search across titles and lyrics that ignores accents, case and apostrophe style, and handles bare numbers.
  - Language/hymnal picker.
  - Favourites, which are now per hymnal.
  - Playlists, saved per hymnal: name, rename, delete, add / remove / reorder hymns. See `PLAYLISTS_STATUS.md`.
- **Privacy manifest** (`Resources/PrivacyInfo.xcprivacy`): no tracking. It declares product interaction and other usage data (analytics), and purchase history and device ID (app functionality; the IDFV is sent by RevenueCat). None of these are linked to the user. UserDefaults is declared with reason CA92.1. PostHog GeoIP is off.
- **App Store release prep** is in `docs/appstore/`: listing copy, privacy label, review notes, screenshot plan, URL checklist and readiness status. Start with `docs/appstore/STATUS.md`.
- **Accessibility:**
  - Labels and hints on every control; verses read as "Verse N" plus their text; extra accessibility actions (next/previous hymn, church mode, next/previous verse).
  - Dynamic Type everywhere through `scaledFont`/`@ScaledMetric`. The Lectern is capped at accessibility1 so it still fits on screen.

## Stubbed / deliberately left out

- **No `Piano.sf2`:** accompaniment uses Apple's General MIDI bank, or the sampler's default voice if the OS has no bank. The sound on a real device hasn't been checked yet.
- **App icon:** a placeholder 1024×1024 PNG is in `Resources/Assets.xcassets/AppIcon.appiconset` (Evergreen field, brass ring, “AP”). Replace it with the finished mark before release.
- **No attribution screen** (as briefed). More → About has one credit line for the Cyber Hymnal MIDI files. The FAQ link from the design was removed because there is no URL for it.
- No tests, as briefed.

## Malcolm / Rolo must do before TestFlight

1. **IAP product IDs (Rolo).** Replace the placeholder IDs in `Store/PurchaseConfig.swift` with the **exact live 6.3 non-consumable IDs**, or existing buyers won't get their hymnals back.
   - Every hymnal is free from 7.0 (`PurchaseConfig.swift`); the 6.x hymnal IDs only matter for Restore purchases.
   - Set `allHymnalsProductID` / `allHymnalsEntitlement` if a bundle exists.
   - Make sure any hymnal without a live product exists in App Store Connect.
2. **RevenueCat:** create or confirm the project for app id1015021132, add the products, and paste the public `appl_…` key into `PurchaseConfig.revenueCatAPIKey`. Until then purchases are off; DEBUG builds unlock everything and Release builds keep paid hymnals locked.
3. **PostHog:** paste the project token into `Analytics.projectToken`, and check the host (currently EU: `https://eu.i.posthog.com`). Analytics stays off until the token is set.
4. **Support email and privacy policy:** confirm `AppInfo.supportEmail` (currently `support@adventpraise.app`, a placeholder) and `AppInfo.privacyPolicyURL` (currently `https://adventpraise.app/privacy`, a placeholder, linked from More → Privacy policy). See `docs/appstore/urls-checklist.md`.
5. **App icon:** replace the placeholder in `Resources/Assets.xcassets/AppIcon.appiconset` with the finished 1024×1024 mark.
6. **Signing:** open the project in Xcode while signed into team 4729Z4LTF4. Automatic signing creates the profiles for `com.mDev.Advent-Praise`. No extra capabilities are needed (In-App Purchase is implicit; Siri isn't needed for App Shortcuts).
7. **TestFlight:**
   - Archive (Release) and upload as 7.0 (1).
   - Fill in App Privacy using `docs/appstore/privacy-label.md`: Product Interaction, Other Usage Data, Purchase History and Device ID, none linked and none used for tracking.
   - Test purchases and restore with a sandbox account that owns 6.x hymnals.
   - Try Siri: "Open hymn in Advent Praise".
8. **Content:** review a few English/Ndebele hymns in the reader. 7 English and 6 Ndebele hymns have a different verse/chorus structure in cis-v2, so they kept the legacy text unchanged. `Tools/convert_hymnals.py` prints those counts.
