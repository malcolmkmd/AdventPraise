---
name: verify-adventpraise
description: Drive the Advent Praise iOS hymnal app (SwiftUI, scheme AdventPraise) in the iOS Simulator and capture evidence that a feature works — DEBUG build, fresh install, launch arguments for fixed states, and an XCUITest harness that taps through real user journeys (library panel, More drawer, About this hymn, Memorise). Use when asked to verify, demo, smoke-test or screenshot a change in the running app, not just in unit tests.
---

# Verify Advent Praise in the simulator

Advent Praise is an iPhone/iPad hymnal (bundle id `com.mDev.Advent-Praise`, product
`Advent Praise.app`, iOS 17+). The user-facing surface is the app itself; there is no
server, no URL scheme (`openurl` has nothing to open) and no UI test target in the app
project. Two ways in:

1. **Launch arguments** (DEBUG only, `AdventPraise/App/DebugLaunch.swift`) open a screen
   directly: `-screenshotState 1…8`, `-uiDebugSheet memory`, `-uiDebugMore YES`, … They
   *reach* a state; they don't prove the path to it.
2. **The harness** in `harness/` — a standalone XCUITest project (one UI-testing bundle,
   no host app, nothing linked from the app) that drives the installed DEBUG build by
   bundle id, taps by accessibility label, and writes screenshots + a journal. This is
   the proof path. It never touches the app project.

Run every command from the repo root. Commands are deliberately single `xcrun` /
`xcodebuild` calls (no scripts, no `$(…)`): in this repo's agent sessions shell scripts,
`python3`, `ps`, `pkill` and `$(…)` usually need approval, while plain `xcrun` and
`xcodebuild` calls don't.

## Isolate (read first)

- **One booted simulator at a time.** Several booted sims on this Mac have exhausted the
  process table and hung `xcodebuild test`. Run `xcrun simctl list devices booted`
  first. If a simulator that isn't `AP Verify iPhone` is booted, it belongs to another
  session: wait for it to shut down (re-check every few minutes); never shut it down,
  install onto it or reuse it — same bundle id, so you would overwrite that session's
  app and state.
- Use the dedicated device **`AP Verify iPhone`** (iPhone 17 Pro, iOS 27.0). It is
  yours to wipe. `xcrun simctl list devices | grep "AP Verify"` tells you if it exists;
  if not, create it once:
  `xcrun simctl create "AP Verify iPhone" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-0`
  (on this Mac the iOS 27.1 runtime refuses an iPhone 17 Pro, "Incompatible device").
  `simctl` and `-destination name=` accept the name wherever a UDID goes, as long as it is
  unique.
- If another session's simulator stays booted for a long time and you must go on,
  booting `AP Verify iPhone` alongside it (two booted, no more) has worked. Leave theirs
  alone and say so in your report.
- Build into `build/verify-dd` and `build/verify-harness-dd` (gitignored), not Xcode's
  DerivedData, so you never race another session's build.

## Launch

```sh
xcrun simctl boot "AP Verify iPhone"
xcrun simctl bootstatus "AP Verify iPhone" -b
xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/verify-dd build -quiet
xcrun simctl uninstall "AP Verify iPhone" com.mDev.Advent-Praise
xcrun simctl install "AP Verify iPhone" "build/verify-dd/Build/Products/Debug-iphonesimulator/Advent Praise.app"
xcrun simctl launch --terminate-running-process "AP Verify iPhone" com.mDev.Advent-Praise -screenshotState 1
```

- `-quiet` prints nothing on success; exit 0 is the signal. The first build takes a few
  minutes (Swift packages: PostHog, FeaturesVote).
- **Uninstall before install every run**: favourites, playlists, Memorise stars and the
  one-time "reveal first playlist" flag live in UserDefaults and survive an install
  over the old app. The library-panel journey needs that clean slate.
- **Ready** = the reader is on screen with hymn 191 "Blessed Assurance": take a
  screenshot ~3 s after launch and look (`-screenshotState 1` skips the splash and
  What's New and unlocks Pro). The harness's own readiness check waits for the
  Lectern handle (`lectern.handle`).
- Optional, for tidy screenshots: `xcrun simctl status_bar "AP Verify iPhone" override --time 9:41 --batteryState charged --batteryLevel 100`
  (lost on every shutdown; the clock shows "09:41" unless the sim's `AppleLocale` is
  `en_US`, see `SCREENSHOTS.md`).

## Doctor

Run when anything looks off, before blaming the app. All read-only:

```sh
xcrun simctl list devices booted
xcrun simctl listapps "AP Verify iPhone"
xcrun simctl get_app_container "AP Verify iPhone" com.mDev.Advent-Praise
```

Healthy: `AP Verify iPhone` is booted (and ideally nothing else); `listapps` has a
`"com.mDev.Advent-Praise" =` entry whose `CFBundleShortVersionString` matches
`MARKETING_VERSION` in the project (7.0.1 on 2026-10-14) — `xcrun simctl listapps "AP Verify iPhone" | grep -A20 'com.mDev.Advent-Praise" =' | grep CFBundleShortVersionString`;
`get_app_container` prints a path (installed). The bundle path points into the
simulator's own container, not `build/verify-dd`, so if in doubt whether the
newest build is installed, uninstall and install again. A Release
build ignores every `-uiDebug…`/`-screenshotState` argument, so if launch arguments
seem to do nothing, you installed the wrong build.

## Drive

### A. Fixed states with launch arguments (fast look, not proof of a path)

```sh
xcrun simctl launch --terminate-running-process "AP Verify iPhone" com.mDev.Advent-Praise -uiDebugPro YES -uiDebugNoSplash YES -whatsNew.lastSeenVersion 7.0 -uiDebugSheet memory
xcrun simctl io "AP Verify iPhone" screenshot ../verify-evidence/manual-memorise.png
```

`simctl io … screenshot` won't create folders, and an agent shell here may not be allowed
to `mkdir` outside the repo. Write into a folder that already exists: the
`../verify-evidence/` root once any harness run has created it, otherwise
`build/verify-evidence-manual/` inside the repo (gitignored).

Useful ones (full list at the top of `DebugLaunch.swift`, states in `SCREENSHOTS.md`):

| Argument | Opens |
|---|---|
| `-screenshotState 1…8` | reader, playing, number pad, service plans, hymnals, appearance, dark reader, church mode (each also: Pro, no splash/What's New, CIS 191) |
| `-uiDebugLectern library` / `hymn` | the Lectern's library panel / hymn tray |
| `-uiDebugMore YES` | the More drawer (root) |
| `-uiDebugSheet about` | About this hymn drawer (root); also `memory`, `pitch`, `planner`, `collections`, `scripture`, `support` |
| `-uiDebugMemoryMoves 3` | Memorise: 3 right picks then a wrong one (99: finish) — a setter, not a user path |
| `-uiDebugHymn 412` | open that hymn number |
| `-uiDebugPro YES` / `-uiDebugFree YES` | force Pro / force free (the sim may keep a StoreKit test purchase) |

Always add `-uiDebugPro YES -uiDebugNoSplash YES -whatsNew.lastSeenVersion 7.0` unless
you are testing those (`-whatsNew.lastSeenVersion 9.9` does **not** skip it).
`-screenshotState` drops every other `-uiDebug…` argument.

### B. Journeys with the harness (the proof)

Build once per harness change, then run one journey (or all) against the installed app:

```sh
xcodebuild test -project .claude/skills/verify-adventpraise/harness/APVerify.xcodeproj -scheme APVerifyUITests -destination 'platform=iOS Simulator,name=AP Verify iPhone' -derivedDataPath build/verify-harness-dd -resultBundlePath build/verify-results/<new-name>.xcresult -only-testing:APVerifyUITests/MemoriseJourney -quiet
```

Journeys (one class per feature in `features/`):
`LibraryPanelJourney`, `MoreDrawerJourney`, `AboutHymnJourney`, `MemoriseJourney`.
Drop `-only-testing` to run all four (allow 15–20 min: XCUITest queries are slow here,
Memorise alone takes 3–5 min; plus ~1 min to build the harness).
Re-run **Launch's uninstall/install** before `LibraryPanelJourney` if anything has
already added a favourite or created a playlist.

- `-resultBundlePath` must be a path that doesn't exist yet; pick a new name per run.
- Run it in the background and judge progress by the journals, not the console:
  `../verify-evidence/LATEST` names the run folder, and each journey's `journal.txt`
  fills in as it goes. A piped `| grep` buffers everything until the end.
- `xcodebuild test` has hung after the last journey finished (all journals complete,
  no exit). If every journal is complete and xcodebuild hasn't exited ~2 min later,
  stop the command you started; the evidence is already on disk.
- The harness has no host app and no dependency on the app target. It drives
  whatever `com.mDev.Advent-Praise` is installed, so install the build you mean to verify.

Writing a new journey: add a `final class XJourney: JourneyCase` file to
`harness/APVerifyUITests/` (the folder is a synchronized group, no project edit
needed), override `journeyName`, and use the helpers in `Support.swift`:
`launch(extraArgs)`, `openHymnTray()`, `tap(element, "what")`,
`expect(condition, "what")` (stops the journey on failure),
`check(condition, "what")` (a `FINDING`: fails the test at the end but lets the journey
go on, for copy and formatting slips), `shot("name")`, `note("line")`, `settle()`,
`waitGone(element)`, `drawer("More")` (an AdventDrawer card by title; scope its
`Back`/`Close` to it, because the reader menu keeps a `Close` button of its own in the tree). Find elements by what VoiceOver reads — the app's labels are
stable and deliberate (`"Favourites and playlists"`, `"Reading options"`,
`"Add hymn"`, `"Back"`, `"Close"`, identifiers `lectern.handle`, `lectern.hymnTray`).
Grep the feature's Swift for `accessibilityLabel(`, `Button("`, `GlassButton(title:`,
`MoreRow(title:` to find them. Never tap by coordinates except for gestures (the
drawer's drag-down).

## Evidence

- **Where:** `../verify-evidence/` beside the checkout (outside the repo, never
  committed). Each harness run makes `../verify-evidence/<yyyyMMdd-HHmmss>/<journey>/`
  holding numbered PNGs (`01-favourites-empty.png`, …, `NN-FAILED.png` on failure),
  `journal.txt` (every launch, tap, `PASS`/`FAIL`/`FINDING` check and observed value)
  and, on failure, `FAILED-hierarchy.txt` (the accessibility tree XCUITest saw).
  Before calling a `FAIL` an app bug, compare the `FAILED` PNG with the hierarchy. If the
  screen shows the right state, the query is wrong (a hidden duplicate label, an
  element still fading out) and the harness needs fixing.
  `../verify-evidence/LATEST` holds the newest run's path; the test log prints
  `AP-EVIDENCE-DIR <path>`. Override the root with `TEST_RUNNER_AP_EVIDENCE_DIR=/path`
  in the environment of `xcodebuild`.
- Manual `simctl io … screenshot` shots go in `../verify-evidence/` with a descriptive
  name (see Drive A for the folder caveat).
- The xcresult bundle (path printed at the end of `xcodebuild test`) keeps the same
  screenshots as attachments if the files are ever missing.
- **Proof standard:** drive the real path a user takes (tray tile, globe, Lectern
  button), not a `-uiDebug…` setter, for any claim that a feature *works*; the setters
  are for looking. Capture the action and the resulting state (before/after shots,
  journal lines), not only the final screen. Check side effects the user can see
  later: a favourite stays listed, a playlist row appears, Memorise's best stars show
  on the level chip after the round. Report failures with the journal's `FAIL` line and
  the matching PNG; never weaken a check to make it pass.
- Read the PNGs with the Read tool before claiming anything about how a screen looks.
  Read-tool image results can be cached per path, so give re-takes new names.

## Cleanup

```sh
xcrun simctl terminate "AP Verify iPhone" com.mDev.Advent-Praise
xcrun simctl shutdown "AP Verify iPhone"
```

Shut down only `AP Verify iPhone` — never another session's simulator, never by
process name. `build/verify-dd` and `build/verify-harness-dd` are gitignored caches;
keep them for the next run (or delete them to reclaim space). Cleanup never touches
`../verify-evidence/`. After cleanup, `ls ../verify-evidence/` should still list the
run.

## Feature map

`features/README.md` indexes the user-facing features, how to reach each one, the
journey that drives it and what proves it. Keep it honest as the app changes
(`/maintain-verification-skill`).
