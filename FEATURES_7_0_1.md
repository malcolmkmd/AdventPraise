# 7.0.1: MIDI Piano unlock and the onboarding tour

Work log for the headless run of 2026-10-16. Decisions were taken without
Malcolm; the ones that need his eye are listed at the end.

## A. MIDI Piano, a second one-time unlock

- `ap_midi_unlock` ("MIDI Piano") is a non-consumable beside Pro:
  `PurchaseConfig.midiProductID`, in both StoreKit files (Products.storekit
  R79.99, AdventPraise-USD.storekit $3.99, family sharing off, display name
  "MIDI Piano", description "One-time unlock for the MIDI piano player.").
- Entitlement rules are a value type, `Entitlements` (PurchaseConfig.swift):
  `unlocksPlayer` is Pro or MIDI; `unlocks(.airPlay / .mirroring / .support)`
  is Pro only. `PurchaseStore` publishes `entitlements`, with `isPro`,
  `ownsMIDI`, `isPlayerUnlocked` and `unlocks(_:)` on top. Every Pro-only
  consumer (church mode, AirPlay, widgets, Live Activity, presenter actions,
  the mirroring banner) still reads `isPro`; only the player gate and the
  free-play counter read `isPlayerUnlocked`.
- A purchase trusts the verified transaction `purchase()` returns and
  `Transaction.updates`, for both products (the lagging
  `currentEntitlements` fix from 4509510 is kept). Restore covers both; its
  message names the MIDI piano when that is what came back.
- Storefront loads are judged per product: `Storefront.from(prices:)` gives
  `proOption`, `midiOption` and `tips` separately, and `PurchaseStore` exposes
  `proOptionFailed`, `midiOptionFailed` and `tipsFailed`. Products already
  loaded are kept, so Try again only fetches what is missing. The old
  `optionsFailed` is gone.
- Paywall: the player gate (`ProFeature.player`) shows Pro as the brass
  primary button and "Just the MIDI piano · price" as a secondary button
  under it, both from `displayPrice`. Other gates show Pro alone. Someone
  who owns MIDI never hits the player gate; opening the paywall from More
  then says "The MIDI piano is already yours. Pro adds the rest." The More
  card's subtitle says the same. The gate closes when what it asked for is
  owned (`Entitlements.unlocks(feature)`), so a MIDI purchase closes the
  player gate but an AirPlay gate waits for Pro.
- Debug: `-uiDebugMIDI YES` (MIDI owned), `-uiDebugFree YES` is documented
  again, and `-uiDebugPaywall player` opens the gate with both buttons.
  When any of `-uiDebugPro / -uiDebugMIDI / -uiDebugFree` is set the store
  no longer asks StoreKit at all: on a simulator with no StoreKit
  configuration the sandbox put "Sign in to Apple Account" over every
  screenshot.
- Analytics: the super property `owns_midi` beside `is_pro`
  (`Analytics.setEntitlements`); `purchase_*` events carry
  `ap_midi_unlock` as the product.
- Tests: `EntitlementsTests` (rules, product IDs, per-product storefront
  failures), `PurchaseStoreTests` (MIDI loads with its price, buying it
  opens the player and nothing else, every screen fails and recovers
  together, Restore finds it).

## B. Onboarding tour

New folder `AdventPraise/Tour/`:

- `TourModel.swift`: the state machine. Eight `TourStep`s, each a list of
  `TourStage`s (which area draws it, which real controls it lights, the
  copy, whether it offers Next). Hosts report `TourSignal`s (the tray, a
  new hymn, the globe, Play, Memorise, church mode, its actions popover,
  More) and the model moves on when the asked-for thing happened. A Next
  may ask the host to `perform` a side effect (close the tray or menu,
  stop the piano, leave church mode, close More). Completion is
  `UserDefaults["tour.completed"]`, set by Done and by Skip tour alike.
- `TourOverlay.swift`: `.tourAnchor(_:)` (an anchor preference, merged with
  `transformAnchorPreference` so a tile inside the tray keeps its own
  anchor) and `.tourHost(_:)` (reads the anchors of its hierarchy and draws
  the spotlight while the current stage belongs to it). The spotlight is a
  dim with a rounded cut-out, a brass ring that breathes, four clear panes
  that swallow taps outside the cut-out, and an opaque card (step counter,
  title, a line or two, Skip tour, and Next where the stage explains).
  Reduce Motion: cross-fades, no breathing, no bouncing symbol. VoiceOver:
  focus lands on the card's title at every stage, Next is on every card,
  Skip tour has a hint.
- `TourRootHost.swift`: attaches the root overlay in RootView, observes the
  reader model and the player, keeps `TourContext` current (piano on this
  hymn, iPad sidebar, regular width), runs the side effects, and starts a
  pending tour once nothing covers the reader.
- Three hosts, because a full-screen cover and a sheet sit above the root:
  RootView (`.tourRoot`), ChurchModeView (`.tourHost(.church)`, and its
  controls no longer auto-hide while the tour runs) and More's content
  (`.tourHost(.more)`).
- Anchors: the Lectern's keypad, title, Play, number pad, tray and transport;
  the tray's Church, Memorise and More tiles; the globe and the menu bar;
  church mode's slider and Leave buttons; More's Pro card and Support row;
  the iPad sidebar's two new rows.
- Steps: (1) keypad then a number and Go, advances when the hymn changes;
  (2) swipe, with Next, advances on a swipe too; (3) the title opens the
  tray, then the tray explained; (4) the globe, then the bar explained and
  closed; (5) Play (never counted), then the transport explained and the
  piano stopped; (6) the tray and Memorise, the sheet is explored, the tour
  resumes when it closes; (7) the tray and Church, then the slider in church
  mode, the popover is explored, then Leave; (8) the tray and More, then the
  Pro card and the Support row, then on iPad with the sidebar out, its rows;
  finally "You're all set" with Done.
- Firing: `WhatsNewPresenter.onDismiss` calls `tour.offerAfterWhatsNew()`.
  The root host starts it 0.8 s after the screen is clear, so Try Worship
  Mode runs church mode first and the tour follows when it closes. It never
  fires when `-uiDebugTour` or `-screenshotState` is set, or when
  `tour.completed` is already true (`-tour.completed YES` for test runs).
  The verify harness already passes `-whatsNew.lastSeenVersion 7.0`, so no
  journey sees it.
- Free plays: `FreePlays.isTourActive` (set from `TourModel.onActiveChanged`
  in AppServices). `spend()` counts nothing while it is on and
  `locksNewPlay` is false, so Play during the tour never opens the paywall;
  the "1 free play left" status is also quiet. Tests in `FreePlaysTests`.
- More: a "Replay tour" row under Church mode in the Reading group.
- iPad: `HymnSidebar` has an "Advent Praise" section with "Advent Praise
  Pro" (`model.paywall = .support`) and "Support Advent Praise"
  (`model.showSupport = true`). RootView now also presents the support
  sheet when More is not up, so the sidebar row works outside More.
- Debug: `-uiDebugTour step-N` (1–8) opens the tour at step N with the
  reader set up for that step's screenshot (tray open for 6, church mode
  for 7, More for 8); `-uiDebugTour sidebar` is step 8's iPad stage.
- Analytics: `tour_started`, `tour_step_completed`, `tour_finished`
  (ANALYTICS_PLAN.md updated).

## Build, tests, screenshots

- Built with the default Xcode (Xcode-27.0.0 is `xcode-select`'s current
  developer dir, so a plain `xcodebuild` satisfies the DEVELOPER_DIR ask;
  an `env`-prefixed command needs approval in this sandbox).
- Unit tests: all passed on "AP Verify iPhone" (iPhone 17 Pro, iOS 27.0),
  one skipped (the screenshot helper, which runs only with its marker).
- The verify-adventpraise XCUITest harness was not run: each journey takes
  several minutes and none covers the tour or the paywall; nothing in the
  Lectern, More or About-this-hymn labels it taps was changed.
- Screenshots in ../review-shots: tour-01 … tour-08 (iPhone 17 Pro),
  tour-ipad-sidebar (iPad), paywall-player and midi-review (the player gate
  with both prices from StoreKit/Products.storekit, captured through the
  `paywallFromPlayForTheScreenshot` test, which is the only way the app can
  load a .storekit file outside Xcode; its hold was lengthened to 25 s).
- DerivedData used: build/dd-701 (deleted afterwards).

## Commits

Grouped by feature rather than kept bisect-clean: the two code commits
depend on each other (DebugLaunch and the Lectern read both the store's
`isPlayerUnlocked` and the tour's `locksNewPlay`), so the first does not
build on its own.

- `7d5810b` MIDI Piano: ap_midi_unlock beside Pro, Entitlements rules,
  per-product storefront, second button on the player gate. Files:
  Store/PurchaseConfig, Store/PurchaseStore, Store/ProPaywall,
  Store/ProMoreCard, Services/Analytics, StoreKit/Products.storekit,
  StoreKit/AdventPraise-USD.storekit, AdventPraiseTests/EntitlementsTests
  (new), AdventPraiseTests/PurchaseStoreTests.
- `5bec116` Onboarding tour. Files: Tour/TourModel, Tour/TourOverlay,
  Tour/TourRootHost (new); App/RootView, App/AdventPraiseApp,
  App/DebugLaunch, Design/ReaderToolbar, Design/WhatsNewSheet,
  Design/WorshipModeControls, Features/ChurchModeView,
  Reader/LecternPanels, Reader/LecternView, Reader/MoreSheet,
  Reader/ReaderMenu, Services/AnalyticsEvent, Store/FreePlays,
  AdventPraiseTests/FreePlaysTests.
- The third commit is this file and ANALYTICS_PLAN.md.

The build number stays at 11; nothing was uploaded.

## Decisions for Malcolm

- App Store Connect needs the new product: `ap_midi_unlock`, non-consumable,
  reference name "MIDI Piano", not family shareable, R79.99 / $3.99 tier,
  display name "MIDI Piano", description "One-time unlock for the MIDI piano
  player." Nothing here touched App Store Connect. Until it exists, the
  player gate shows Pro alone (the MIDI option simply doesn't load) and
  nothing else breaks.
- The tour fires only after the 7.0 What's New. People who already
  dismissed What's New on 7.0 never see it unless they tap Replay tour in
  More. Firing it for them on a later launch was left out on purpose: it
  would also fire in every UI test run that skips What's New.
- Step 1 on iPad: the keypad opens a popover the tour can't see into, so
  that stage's card is hidden and the step completes when the hymn changes.
- Memorise and church mode's actions are presented above the overlay, so
  the tour pauses while they are open and resumes when they close rather
  than coaching inside them.
- "Unlimited Memorise" is still a paywall line, but nothing in the code
  gates Memorise on Pro (it wasn't gated before this work either).
- The sandbox sign-in prompt on a fresh simulator: forced-entitlement debug
  arguments now skip StoreKit entirely. Real builds are unchanged.
- The Xcode project file reorders `CODE_SIGN_ENTITLEMENTS` on every build;
  that churn was reverted and not committed.
