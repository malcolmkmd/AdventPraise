# Haptics — status

Branch `haptics`. One engine, `AdventPraise/Services/Haptics.swift`. Every haptic in the app goes through it. There are no `sensoryFeedback`, `UIFeedbackGenerator` or Core Haptics calls anywhere else.

## The engine

- **`Haptics`**: an `@Observable @MainActor` class with `Haptics.shared`. Call sites use `Haptics.play(.event)` and `Haptics.prepare(.event)`. Views can use `.haptic(.event, trigger:)` in place of `.sensoryFeedback`, so the user's switch applies to them too.
- **Events (`HapticEvent`)**: selection, lightImpact, mediumImpact, softImpact, thresholdCrossed, success, warning, error, purchaseComplete, pageTurn, keyPress, toggleOn / toggleOff (`.toggle(isOn)`). There is one more, **limit**, for "you hit an end": no further hymn, smallest or largest text, pinch range, pad full or number past the end. The app already used a rigid tap for this in several places.
- **Two back ends:**
  - Selection, impacts, and success / warning / error use **prepared UIKit generators**. These are kept alive and re-prepared after each use, and they follow iPhone's System Haptics switch.
  - Key press, page turn, threshold, limit, toggle and purchase complete have their own shapes, played with **Core Haptics** where `supportsHaptics` is true. Elsewhere (iPad, simulator, or if the engine won't start) they fall back to the nearest UIKit generator.
- **Core Haptics engine settings:** `playsHapticsOnly` and auto-shutdown are on. It restarts after its stopped or reset handlers fire. Those handlers are built in a `nonisolated` factory as `@Sendable` closures that hop back to the main actor, so Swift 6 doesn't insert a main-actor check that would trap when Core Haptics calls them on its own queue.
- **Rate limiting:** each event has a minimum interval, from 35 ms (key press) to 1 s (purchase). Any non-outcome haptic within 25 ms of the previous one is also dropped. Outcomes (success, warning, error, purchase) are never dropped by the 25 ms floor.
- **Off when:**
  - the user's switch is off, or
  - the app is in the background (lock screen controls, Siri).
- **Reduce Motion:** the two-pulse page turn becomes one tap, and the purchase flourish becomes the plain success notification. Nothing else changes; a single tap isn't motion.
- **Preparing ahead:** the number pad warms key presses when it appears, a horizontal page swipe warms the threshold tap when it locks its axis, and a drawer drag warms the soft tap.

## User switch

More → Reading → **Haptics**. It's on by default and saved in UserDefaults as `haptics.enabled`. Checked in the simulator: the row draws on, and launching with `-haptics.enabled NO` draws it off. That check found and fixed a bug: a launch-argument string wasn't read as a Bool.

## Where haptics play

| Where | Event |
|---|---|
| Number pad digit / delete (Lectern, iPad popover, church mode) | keyPress |
| Digit refused (pad full, or past the end of the hymnal) | limit |
| Recent hymn chip on the pad | selection |
| Go (either pad) | pageTurn, from the hymn opening |
| Any hymn change you make: swipe, next / previous, Go, search, favourite and sidebar rows, playlist Play, church mode's next hymn, keyboard commands | pageTurn (in `ReaderModel.show`, only when the hymn really changes) |
| Siri / Shortcuts, lock screen next track, playlist auto-advance, refund fallback to English | none (`feedback: nil`) |
| Hymnal / translation switch | mediumImpact (no page turn as well) |
| Page swipe passes its threshold | thresholdCrossed (was a raw `UIImpactFeedbackGenerator`) |
| Page swipe past the last / first hymn | limit |
| Pinch reaches either end (reader, church mode) | limit |
| Double-tap to reset text size | softImpact |
| Lectern panels open / close | softImpact |
| Drawer settles on a new detent, or is dragged / flicked closed | softImpact (close button and backdrop tap: none) |
| Favourite on / off | toggleOn / toggleOff |
| Playlist: hymn added / removed (tray menu, picker, swipe, VoiceOver) | toggleOn / toggleOff |
| Playlist reorder (drop, VoiceOver move) | selection |
| Playlist deleted (after its confirmation) | mediumImpact |
| Church mode verse next / previous (taps, swipes, buttons, page-turner keys) | lightImpact |
| Church mode previous on the first verse | limit |
| Church mode text size ± / at its limit | selection / limit |
| Player play / pause | toggleOn / toggleOff |
| Player restart, tempo, loop | lightImpact, selection, toggle |
| Purchase completed | purchaseComplete |
| Purchase failed / restore failed | error |
| Restore found nothing; purchases unavailable; product not loaded | warning |
| Restore found hymnals | success |
| Purchase cancelled | none |
| What's New "Try Worship Mode" | mediumImpact (Continue: none) |
| Appearance changes (size, spacing, font, surface…) | selection |
| Memorise: right word / wrong word / verse finished | lightImpact / error / success |
| Pitch pipe, service planner, collections | as before, through the engine |

Scrolling never plays a haptic. System switches (Large print, Chorus, Haptics) get no extra haptic on top of the system's own.

## Behaviour changes from before

- **Church mode verse steps:** they used to play two haptics, a `sensoryFeedback` on the controls plus the view's own. Now they play one.
- **Memorise:** it played a success notification for every right word, plus a heavy impact at the finish. Now a right word is a light tap, and success is kept for finishing the verse.
- **Bookmarks:** the app has none apart from favourites, so nothing was added for them.

## Checked

- `xcodebuild … -destination 'generic/platform=iOS Simulator' build` succeeds with **no warnings** after every commit (Swift 6, complete concurrency).
- On a new "AP Haptics 17 Pro" simulator (iOS 27.0):
  - the More drawer shows the switch, and its saved value is read back;
  - Memorise auto-play (`-uiDebugMemoryMoves 99`) drives right picks, wrong picks and the finish through the engine without a crash.

## Not checked

- **How any of it feels.** The simulator has no Taptic Engine, so pattern strength, the page-turn shape, the purchase flourish and the rate-limit timings need a pass on a real iPhone. All of them are tunable in `Haptics.swift` alone.
- **System Haptics switch with Core Haptics.** UIKit generators follow iPhone's System Haptics switch. Whether Core Haptics patterns (key press, page turn, threshold, limit, toggle, purchase) also stop when that switch is off wasn't verified, because there's no public API to read the setting. Test this on a device. If they don't stop, the fix is a one-line change in `play(_:)` to route those events to UIKit. The in-app switch silences everything either way.
- **Real purchases and restores** (RevenueCat isn't configured in this build).
