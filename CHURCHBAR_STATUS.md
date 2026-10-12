# Church mode top bar: status (branch `churchbar`)

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with **no warnings and no errors** (iOS 27 simulator SDK), on the branch and again on `main` after the merge.

## The problem

The hymn chip (number, title, verse) shared one row with three 60 pt buttons (AirPlay, globe, leave). On a narrow iPhone it was left with about 120 pt, so it read "1 Go…" / "VERSE 1 O…".

## The new top area

Two rows, so the title never competes with buttons:

1. **Controls row**: leave (✕) on the leading edge; AirPlay and the translation globe on the trailing edge. 52 pt circles (they were 60 pt). They have the row to themselves, and 52 is still well above the 44 pt minimum.
2. **Hymn card** (full width, max 560 pt so it keeps a readable measure on iPad and in landscape):
   - **Default layout**: the number in brass at display size with a ▾ beside it. Next to it, the full title (serif, wraps; two lines covers every bundled title tested) and below the title a small "VERSE 1 OF 4" label with **progress dots** for the sung sequence (verses and choruses; ≤ 12 blocks, otherwise no dots). A 📺 icon shows while the hymn is also on a big screen.
   - **From xLarge Dynamic Type up**: the number and "VERSE 1 OF 4" share the top line and the title gets the full width underneath. This switch point was chosen from screenshots. With the number beside it, a 45-character title needed 3 lines at xLarge on 375 pt; stacked, it needs 2.
   - The title allows a 3rd line as a safety net instead of truncating. That only happens at accessibility sizes with 40+ character titles.
   - **Tapping the card** still opens the number pad popover (now anchored under the card). The accessibility label ("Hymn 125, Go Letsatsi Kwa Dithabeng. Verse 1 of 3", plus "Also on the big screen") and the hint are unchanged. The dots are hidden from VoiceOver because the label already says the position.
3. **The lyric starts below the bar**: the bar reports its measured height (`onTopBarHeight`), so the lyric's top inset follows a 1-, 2- or 3-line title instead of the fixed 108 pt.

Unchanged: glass on iOS 26 (`.glass` button style; the card uses a rounded-rectangle border shape) with the opaque fallback before 26, and the card sits apart from the controls row so their glass doesn't merge. Also unchanged: auto-hide, key handling, the translation popover, and all `Haptics.play` and `Analytics` calls in `ChurchModeView`. The bottom bar is untouched apart from what it shares with the top (the glass container).

### External display (AirPlay / cable)

The header above the verse was `number · title` on one line with `lineLimit(1)`. It's now the number in brass above the full title, with balanced wrapping and centred.
- Found while testing: putting `lineLimit(2)` on a balanced-wrap text squeezed it to "Mus / hu…". `BalancedWrap` finds its width by comparing heights, and a capped height never grows, so the search ran down to its lower bound. Dropping the line limit fixed it. There's a comment at the call site.

### DEBUG launch arguments (for screenshots)

- `-uiDebugChurchControls YES`: church mode's controls never auto-hide.
- `-reader.hymnal tswana`: documented in `DebugLaunch.swift` (it was already a plain UserDefaults key).

## Verified (simulator screenshots, iOS 27.0, dark)

| Device | Text size | Hymn | Result |
|---|---|---|---|
| iPhone 14 Pro (393 pt) | Large (default) | Tswana 125 "Go Letsatsi Kwa Dithabeng" | ✅ one line, beside the number |
| iPhone 14 Pro | Large | Tswana 299 "Morena Nthobela Senkgwe Se Se Tshedileng" | ✅ 2 lines |
| iPhone 14 Pro | XXXL | Venda 90 "Mushumo Wa maduvha Matanu na lithihi Wo Fhela" (45 chars) | ✅ stacked, 2 lines |
| iPhone 14 Pro | AX5 (chrome capped at AX1) | Tswana 299 | ✅ stacked, 3 lines, not truncated |
| iPhone 13 mini (375 pt) | Large | Tswana 125 / Tswana 299 / Venda 90 | ✅ 2 lines each |
| iPhone 13 mini | xLarge | Venda 90 | ✅ stacked, 2 lines (3 before the threshold change) |
| iPhone 13 mini | Large | number pad (`-uiDebugChurchPad`) | ✅ popover under the card, fits |
| iPad Air 11" | Large | Tswana 299 | ✅ one line; card capped at 560 pt, leading |
| External screen view (`-uiDebugExternal verse`, drawn on the phone) | n/a | Venda 90 | ✅ number over a balanced 2-line title |

Simulators used: "AP Churchbar 14 Pro", "AP Churchbar 13 mini" and "AP Churchbar iPad", one at a time and shut down afterwards. The Mac was at its simulator process limit, so I shut down the idle **"AP UI1 17 Pro"** simulator (from the finished, merged `ui1` job) to make room. Boot it again if anyone needs it.

## Notes / not done

- **Data issue, not fixed here:** Sotho hymn 283's `title` in `sotho.json` contains the whole first verse run together (several hundred characters). The card shows 3 lines and then truncates. It needs fixing in the hymnal data/converter.
- Sotho hymn 1 is "Letsa phala Molebeli". "Go Letsatsi Kwa Dithabeng" is **Tswana 125**, which is what I tested.
- The dots count the sung sequence, choruses included. "Verse 1 of 3" with 7 dots means 3 verses plus the chorus repeats. That matches what next/previous step through.
- No external display was physically connected. The external layout was checked with the debug view on the phone.
- The reader header, bottom action bar and splash were not touched.

## Files

- `AdventPraise/Design/WorshipModeControls.swift`: controls row, hymn card (side-by-side and stacked layouts), progress dots, top bar height callback.
- `AdventPraise/Features/ChurchModeView.swift`: passes step/count and reads the bar height into the lyric's top inset; DEBUG keep-controls flag.
- `AdventPraise/Features/ExternalDisplay.swift`: number over a wrapping, balanced title.
- `AdventPraise/App/DebugLaunch.swift`: `-uiDebugChurchControls`.
