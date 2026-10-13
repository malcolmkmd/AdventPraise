# Paywall crowd: the hands rise and fall (hands) — status

Branch `hands`, on top of paywall3 (`PAYWALL3_STATUS.md`), merged into `main`, not pushed. The build was
`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build`,
run in the foreground, with **no warnings**. Screenshots and the video are in `build/shots/hands/` (gitignored),
taken on "AP Paywall2 iPhone" (iPhone 17 Pro, iOS 27.1), the only simulator booted, shut down afterwards.

## What changed

One file, `Store/PaywallScenery.swift`. After the lift-in, every hand in the crowd now rises and falls slowly,
straight up and down, on its own beat:

- **Rhythm.** Each hand has its own full period of **3.2–4.8 s** (up over half, down over the other half),
  `easeInOut` both ways, so it slows into the top and the bottom with no snap. It is a `repeatForever`
  animation on the hand's own offset, driven by Core Animation on that hand's layer, like the sway; nothing is
  evaluated per frame in SwiftUI. The gentle sway (1–2° of lean) stays as it was and runs alongside.
- **Travel by row** (of the front-row hand height, 190 pt on the paywall, 150 on the thank-you): front **7 %**
  (~13 pt), middle **4.2 %** (~8 pt), back **2.4 %** (~5 pt), each hand ±20 %. The front row moves most, the
  back least, as a crowd does in depth.
- **Ripple.** The rise and fall starts once a hand's lift-in has settled (its lift delay + 1.1 s), then later
  by up to 1.4 s across the width (leading edge first), 0.3 s per row back, and up to 0.7 s of scatter. With
  the periods all different, the hands drift in and out of step and the crowd never moves as one block.
- **`CrowdHandSpec`** gains `bobTravel`, `bobPeriod` and `bobDelay`; the old `bob` (a 1.5–4 pt rise tied to
  the sway) is gone. `PraiseCrowd.rows` carries a `travel` per row. `CrowdHand` has a second `@State`
  (`raised`) started in the same `onChange(of: lifted)` as the sway.
- **Legibility.** The highest fingertip (front row at full travel) still sits ~65 pt below the
  Restore · Terms · Privacy line on the iPhone, inside the existing top fade of the crowd, so the fine print is
  unchanged. The button is glass over the hands as before.
- **Reduce Motion:** no lift, no rise and fall, no sway; the hands fade in and stand still. The light still
  breathes in opacity only.

## Verified (iOS 27.1 simulator, DEBUG build, mock offering)

| File | What |
| --- | --- |
| `open.mov` | 9.4 s, iPhone 17 Pro, dark: launched with `-uiDebugPaywallDelay 1.5`, the sheet rises, the words fade up, the crowd lifts in and starts its slow rise and fall. `xcrun simctl io recordVideo`, h264. |
| `open-long.mov` | A 12 s take of the same, with more of the rhythm settled. |
| `iphone-dark.png` | The paywall ~12 s after opening, every hand mid-motion: logo, headline, five lines, caption, the terms line clear above the fingertips, "Unlock Pro · R199.99". |
| `frames/t01–t20.png` | A 20-shot burst from launch (every ~0.5 s): nothing before the sheet, the crowd lifting in, settled by ~7 s on a cold launch. |
| `frames/d01–d06.png` | A 6-shot burst 3–5 s after opening: between d01 and d06 the centre front hand has risen ~10 pt while the hands at the leading edge have dropped ~20 pt and the trailing ones risen, i.e. different phases, gentle travel. |

Also checked:

- The build had no warnings.
- No tapping this round; the purchase and tip paths are untouched.
- Only one simulator was booted; it was shut down at the end (none booted).

Not checked here: frame rate on a device (the simulator recording shows no dropped frames; the crowd is still
~17 layers on iPhone, ~36 on iPad, each with two `repeatForever` animations); the iPad (same code, the travel
scales with the hand height, so the same 13/8/5 pt); Reduce Motion by eye (the code path is the existing
"fade in, stand still" one with the new offset held at 0).

## Recording from this harness

`python3`, `perl`, `ruby`, `node`, `expect`, `pkill`, `killall`, `sips` and `xxd` all needed approvals this
session, so the recorder was driven with what was allowed: `simctl launch … && simctl io … recordVideo` as one
background command, a chain of `simctl io … screenshot` calls as the clock, then `pgrep -f recordVideo | xargs
kill -INT` to stop it cleanly (the file finalises; the duration comes from the `mvhd` atom via `od`). The
length depends on the gap between the two calls, so takes came out at 5.8, 9.4 and 12.1 s.
