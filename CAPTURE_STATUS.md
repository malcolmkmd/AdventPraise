# App Store capture status (branch `shotstate`)

All eight `-screenshotState` shots, captured on 2026-10-14 by following
[`SCREENSHOTS.md`](SCREENSHOTS.md): one iPhone 17 Pro Max simulator (iOS 27, 6.9-inch),
Debug build, fresh install, `en_US` region, status bar overridden to 9:41, a ~5 s wait per
state. Every file is native 1320 × 2868 PNG in `../store-raw/`.

| n | File | Shows |
|---|---|---|
| 1 | `state-1-reader.png` | Christ In Song 191 "Blessed Assurance" on Paper |
| 2 | `state-2-player.png` | the same hymn playing, transport open, verse 1 line highlighted (0:04) |
| 3 | `state-3-number-pad.png` | the number pad with "100": *What A Friend We Have In Jesus* |
| 4 | `state-4-service-plans.png` | Service planner: Sabbath morning "In 3 days" (Sat 17 Oct), Vespers, Communion Sabbath, Youth programme |
| 5 | `state-5-hymnals.png` | reader menu on the hymnal tiles, English ticked |
| 6 | `state-6-appearance.png` | reader menu on Theme, Paper selected |
| 7 | `state-7-dark-reader.png` | hymn 191 on Black |
| 8 | `state-8-church.png` | church mode: hymn 191, verse 2 of 3, controls up (no status bar, by design) |

Each PNG was checked by eye. None showed a splash, What's New, a paywall or another
prompt, so none needed retaking.

## State 8 (new)

`-screenshotState 8` opens church mode on hymn 191 at verse 2 ("Perfect submission,
perfect delight"), with the controls held up. It uses a new DEBUG argument,
`-uiDebugChurchBlock n`, which opens church mode on block `n` of the sung sequence. For
191 that sequence is verse 1, chorus, verse 2, so `n` is 2. The listing plan
(`docs/appstore/screenshots.md`, shot 2) asks for "Same hymn, verse 2". Like the other
states, it's compiled out of Release.

The simulator used was the already-booted "StoreArt iPhone 17 Pro Max". DerivedData
(`build/dd`) was deleted after the build.
