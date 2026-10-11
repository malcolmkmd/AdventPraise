# Church mode — fix status (branch `church`)

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' clean build` succeeds with **no warnings and no errors** (Xcode 27.1, iOS 27 simulator SDK). Checked on an iPhone 17 Pro simulator (iOS 27.0).

## 1. Changing hymn and translation from inside church mode

The top bar is now: **hymn chip** (number ▾, title, "Verse 2 of 4") · **globe** · **leave**. The bottom bar is: **previous** · **text smaller / larger** · **next**.

- **Tap the hymn number chip** to open a compact number pad in a popover. It's the design-system `HymnNumberPad` with a live title preview and recent hymns, and it won't accept numbers past the end of the hymnal. Go opens that hymn in church mode at verse 1. A hardware keyboard works too (digits, ⌫, ↩).
- **Tap the globe** to open a quick translation switcher in a popover. It lists the owned hymnals (language, the hymnal's own name, ✓ on the current one). Choosing one calls `ReaderModel.switchHymnal`, which **keeps the hymn number**, and church mode stays on the same verse (clamped if the new hymnal has fewer verses). If a hymnal's highest number is below the current hymn, the row says so; it opens that hymnal's first hymn. Buying a hymnal is left to the full Hymnals panel; the quick switcher only shows owned ones.
- **Large targets:** top buttons are 60 pt, previous and next 72 pt, and the chip is 60 pt tall.
- **Auto-hiding chrome:**
  - Controls fade after about 4 s. A tap anywhere brings them back without turning the page.
  - They stay up while either popover is open, and restart the timer when it closes.
  - They never hide while VoiceOver is running.
  - Hidden controls don't take touches. Hardware keys (← → space, page keys, esc) still work.
  - VoiceOver also gets "Jump to hymn number" and "Change translation" actions on the screen.
- **Glass:** only the floating controls are glass. On iOS 26+ they use the native `.buttonStyle(.glass)` and, for next, `.glassProminent` (brass tint), in one `GlassEffectContainer`. The two popovers get an opaque dark `presentationBackground`, because glass over large white lyrics washed out to grey in testing. On iOS 17–25 the controls stay opaque raised colour, as before.

## 2. Text size buttons didn't work — cause and fix

**Cause:** `ChurchModeView` set the font from a fixed `@ScaledMetric var lyricSize = 48` and never read `worshipStep`, the state the buttons changed. There was a second problem behind that: `.minimumScaleFactor(0.28)` with an unbounded height shrank long verses back to "fit", so even a correctly wired size would often have shown no change. The step also lived in view `@State`, so it was lost every time.

**Fix:**
- The size is now `DS.LyricScale.worship.steps[step]` (36/42/48/56/64 pt) × Dynamic Type (`@ScaledMetric`, capped at 1.2× like the reader's worship scale) × 1.2 when **Large print** is on. The result is clamped to **28–96 pt**.
- The change applies live.
- The size you choose is honoured exactly. A verse too long for the screen scrolls vertically, with no bounce if it fits, instead of being shrunk back down. The default step is now 42 pt so a typical verse fits on an iPhone without scrolling.
- The step is **persisted** in `ReadingSettings` (`worshipStep`, stored in the existing `reading.settings.v1` snapshot as an optional field, so older saved settings still decode). It's clamped on load and on every change through `stepWorshipText(by:)`.
- Smaller and larger **disable at the limits** (larger also disables once the 96 pt clamp is reached), with a rigid haptic at a limit and a selection haptic otherwise.
- The lyric itself is not capped by Dynamic Type. The control chrome is capped at accessibility1 so it still fits.

## 3. A separate bug found while testing: auto-hide never actually hid

`WorshipModeControls` applied `.opacity(isVisible ? 1 : 0)` *inside* `DSGlassGroup`. On iOS 26 a `GlassEffectContainer` draws the glass itself, so the buttons stayed on screen even though the state flipped (I confirmed this with logging). The opacity, hit testing and accessibility hiding now wrap the container.

## Verified in the simulator

The simulator has no tap tool here, so I drove the app with a **throwaway XCUITest runner** that targets the installed app by bundle id. It lives in the git-ignored `DerivedData/ChurchProbe` and is **not part of the repo or the app project**. Each step was checked with screenshots and element labels:

| Check | Result |
|---|---|
| Smaller to the minimum (36 pt) and larger to the maximum (64 pt), text visibly changes each step, buttons disable at the ends | ✅ |
| Size persists across app relaunch | ✅ |
| Dynamic Type AX XL: lyric larger, still clamps; chrome fits | ✅ |
| Large print on: lyric larger (64 → ~77 pt at max), larger disables | ✅ |
| Next / previous buttons move verse 1 ⇄ 2 | ✅ |
| Swipe left / right moves verse 1 ⇄ 2 | ✅ |
| Tap right / left third moves verse 1 ⇄ 2 | ✅ |
| Controls hide after idle (screenshot); a tap reveals them without turning the page | ✅ |
| Hymn chip → pad → 1, 2 → Go opens hymn 12 | ✅ |
| Globe → Tswana keeps hymn 12 ("Motswedi O Teng"), globe value reads "Tswana"; back to English | ✅ |
| Leave closes church mode | ✅ |

Known nit: XCUITest still reports hidden controls as existing in the accessibility tree (opacity 0 inside the glass container), even though they are invisible and can't be touched. The probe's `exists` assertion for "hidden" failed for that reason only; the screenshot confirms they're hidden.

## Not done / for later

- Not checked on iPad or in landscape in this pass. The layout uses the same flexible bars, and the popovers fall back to normal popovers on iPad.
- The translation switcher doesn't offer purchases. Use the Hymnals panel for that.
- No tests were added to the repo, as briefed.

## Files

- `AdventPraise/Features/ChurchModeView.swift`: size computation, scrolling lyric, number pad and translation popovers, auto-hide that pauses while a popover is open and is off for VoiceOver.
- `AdventPraise/Design/WorshipModeControls.swift`: new layout (chip, globe, leave / previous, size, next), native glass button styles, popover hooks, the fade moved outside the glass container.
- `AdventPraise/Theme/VesperTheme.swift`: persisted `worshipStep`, `stepWorshipText(by:)`, `Comparable.clamped(to:)`.
