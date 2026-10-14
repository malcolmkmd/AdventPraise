# Screenshot states: status (branch `shotstate`)

`-screenshotState 1…7` (DEBUG only) opens the app in a fixed state for each App Store screenshot. How to use it and capture all seven: `SCREENSHOTS.md`.

The Debug build succeeds with **no warnings** (Xcode 27.1, iPhone 17 Pro simulator, iOS 27). A Release build succeeds too, and its binary has no `screenshotState` or `uiDebug` strings; the Debug binary does.

## How it works

- `ScreenshotState` (in `App/DebugLaunch.swift`) maps each state to a preset of launch arguments:
  - existing `-uiDebug…` flags;
  - plain defaults (`reader.hymnal`, `reader.lastHymn`, an unreadable `reading.settings.v1` so the style starts from defaults).
- `DebugLaunch.applyScreenshotState()` swaps the preset into the volatile argument domain, dropping any other `uiDebug` arguments. `AppServices.shared` calls it first, before any model reads UserDefaults.
- **What's New** never shows with a screenshot state, whatever version was last seen.
- **Pro** is on, so there are no paywall or free-play prompts.
- **New generic flags:** `-uiDebugPlay YES` (start the accompaniment) and `-uiDebugDigits 100` (the number pad with digits typed).

## Verified

All seven were captured on the iPhone 17 Pro simulator into `build/shots/shotstate/` (not committed), with the status bar at 9:41:

1. reader
2. player playing
3. pad "100" (What A Friend…)
4. service planner with sample plans
5. hymnal tiles
6. Theme panel
7. Black reader

## Notes

- The clock showed "09:41" until the simulator's region was set to en_US: the status bar follows the simulator's 24-hour setting. `SCREENSHOTS.md` has the commands.
- `docs/appstore/screenshots.md` still says "no play button or piano text". State 2 shows the player, so update that plan if state 2 goes in the listing.
- Service plan dates and the playback position depend on when you capture (see `SCREENSHOTS.md`).
