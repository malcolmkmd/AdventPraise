# App Store screenshots: `-screenshotState`

DEBUG builds take a launch argument that opens the app straight into a fixed state for
an App Store screenshot. It is compiled out of Release (`#if DEBUG` in
`AdventPraise/App/DebugLaunch.swift`), so no screenshot code ships.

```sh
xcrun simctl launch --terminate-running-process booted com.mDev.Advent-Praise -screenshotState 1
```

| n | State | What it sets |
|---|---|---|
| 1 | Reader | Christ In Song 191 "Blessed Assurance", Paper |
| 2 | Piano playing | the same hymn with the accompaniment playing (transport open, line highlighted) |
| 3 | Number pad | the Lectern's pad with "100" typed: the live preview shows *What A Friend We Have In Jesus* |
| 4 | Service plans | the Service planner with sample plans (next Sabbath, Vespers, Communion Sabbath, a past one) |
| 5 | Hymnals | the reader menu on the hymnal tiles (English ticked) |
| 6 | Appearance | the reader menu on Theme (reading surfaces) |
| 7 | Dark reader | hymn 191 on the Black surface |
| 8 | Church mode | the full-screen worship display of hymn 191 on verse 2, controls held up (no status bar: church mode hides it) |

Every state also:

- unlocks Pro, so no paywall, Go Pro or free-play prompts appear;
- skips the launch splash and What's New;
- opens Christ In Song (English) at 191 with the default reading style, and no
  favourites or recents;
- drops every other `-uiDebug…` argument, so leftover debug arguments can't change the
  picture. Plain defaults passed alongside (e.g. `-AppleLanguages`) still apply.

The preset goes into the launch-argument domain, so it wins over saved settings without
overwriting them. A state's settings (the surface, for one) may still be saved by the app
as it runs, as with the other debug arguments.

The pieces are ordinary debug arguments and can be used on their own:
`-uiDebugPlay YES` (the accompaniment playing) and `-uiDebugDigits 100` (the pad open
with digits typed) were added for states 2 and 3, and `-uiDebugChurchBlock 2` (church
mode opening on the third block in sung order: verse 1, chorus, verse 2) for state 8.

## The status bar

An app can't set the status bar, so the simulator does it. The clock follows the
simulator's region: a 24-hour region (South Africa, the UK) shows "09:41". Set
`en_US` once, reboot, then override:

```sh
SIM=<simulator UDID>
xcrun simctl spawn $SIM defaults write -g AppleLocale en_US
xcrun simctl shutdown $SIM && xcrun simctl boot $SIM && xcrun simctl bootstatus $SIM -b
xcrun simctl status_bar $SIM override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```

The override is lost when the simulator shuts down; run it again after every boot.

## Capturing all eight

Build Debug, install fresh (`simctl uninstall` first, so nothing saved leaks in), then
per state run each `simctl` command on its own (not as one script), waiting ~5 s
after launch so the menus and the Lectern have finished opening:

```sh
xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -configuration Debug \
  -destination "id=$SIM" -derivedDataPath build/dd build
xcrun simctl uninstall $SIM com.mDev.Advent-Praise
xcrun simctl install $SIM build/dd/Build/Products/Debug-iphonesimulator/*.app

xcrun simctl launch --terminate-running-process $SIM com.mDev.Advent-Praise -screenshotState 1
sleep 5
xcrun simctl io $SIM screenshot build/shots/1-reader.png
# … 2-player, 3-number-pad, 4-service-plans, 5-hymnals, 6-appearance, 7-dark-reader, 8-church
```

Use one simulator at a time; several booted at once can hang `xcodebuild`.

## What isn't fixed

- **Service plan dates** are relative to today (the sample plan is "this Sabbath"), so
  state 4's "In 3 days" and dates change with the day you capture.
- **Playback position** in state 2 is however long it has played (about 0:05 after a
  5 s wait). Capture at the same delay for a matching set.
- State 2 plays sound through the Mac.

For which shots go in the listing and their captions, see
[`docs/appstore/screenshots.md`](docs/appstore/screenshots.md).
