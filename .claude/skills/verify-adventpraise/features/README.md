# Advent Praise verification map

This directory is the maintained source for verifying Advent Praise's user-facing behaviour in the iOS Simulator. Read `../SKILL.md` for launch, doctor and cleanup, then use the matching feature file as the recipe.

## Baseline preconditions

- Only `AP Verify iPhone` is booted. Another session's simulator means wait.
- A DEBUG build from `build/verify-dd` is freshly installed (uninstall first).
- Every journey launches with the harness's base arguments: `-uiDebugPro YES -uiDebugNoSplash YES -whatsNew.lastSeenVersion 7.0 -reader.hymnal english -reader.lastHymn 191`. That means Pro, no splash, no What's New, Christ In Song 191 "Blessed Assurance".

## Driving conventions

- Drive with the APVerify XCUITest harness (`../harness/`), one journey class per feature file.
- Find elements by accessibility label or identifier (what VoiceOver reads), never by coordinates except for drag gestures.
- `-uiDebug…` launch arguments are for looking at a state. They don't prove the user path to it.
- One journey per feature. Add new steps to the feature's journey rather than writing a parallel test.

## Proof and skip reporting

- Each journey writes `../verify-evidence/<run>/<journey>/NN-step.png` and a `journal.txt` with every tap and `PASS`/`FAIL` check.
- Capture the action and the resulting state (before and after shots). For changes that persist, re-read them in a second view (the favourite row, the playlist row, the best-stars chip).
- Report an unreachable step with its journal `FAIL` line and the `FAILED` screenshot. Never report a debug-argument shortcut as a verified user path.

## Feature entry contract

Each feature file has an H1 and one paragraph, then four H2s in order: `Sub-features`, `How to get to it (user POV)`, `Driving it with the APVerify harness`, `Gotchas`.

## Features

- [Library panel](./library-panel.md): Add hymn by number, the missing-number alert, New Playlist, and the first-playlist reveal. Journey `LibraryPanelJourney`.
- [More sheet](./more-sheet.md): a NavigationStack in a sheet; pages push under a native bar, Back pops, Done closes More and resets it, Support opens over it, Church mode waits for it to go. Journey `MoreSheetJourney`.
- [About this hymn](./about-this-hymn.md): the drawer from the reader menu, its pages, passage → hymns, Memorise hand-off. Journey `AboutHymnJourney`.
- [Memorise](./memorise.md): a full round with a wrong pick, a hint, stars and the best kept. Journey `MemoriseJourney`.

## Not yet mapped

These are reachable today only with launch arguments (see SKILL.md and `SCREENSHOTS.md`). Each still needs a journey: reader and page swipe, number pad and word search, accompaniment playback, church mode (and external display), service planner, hymnal and appearance menus, collections, scripture index, paywall and tips, What's New, the iPad sidebar.
