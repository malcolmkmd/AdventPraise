# UI1 — status

Branch `ui1`, five changes, each its own commit. After every commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with no warnings in app code. Checked with screenshots on an iPhone 17 Pro simulator (iOS 27).

## 1. Globe translation switcher in the reader

- `Reader/TranslationSwitcher.swift`. A globe in the reader's navigation bar (`topBarTrailing`, on iPhone and iPad) opens a popover headed "Hymn N in…".
- Owned hymnals switch in one tap and keep the hymn number. If a hymnal has no hymn of that number, the row says so ("No hymn N · opens the first hymn").
- Locked hymnals are listed under "More hymnals" with the brass `PricePill`. Tapping one buys the hymnal and then switches to it, through the existing `store.access` / `model.select` path. Restore purchases is at the bottom.
- Church mode's globe now uses the same `TranslationSwitcher`, on its black ground, so the two match (church mode used to list owned hymnals only).
- The iPad-only `LanguageMenuButton` and the reader's separate Hymnals sheet are no longer used in the reader. `LanguageMenuButton` is still in the design system.
- On iPhone the navigation bar is now always present. It's clear, so the reader's top inset dropped from 38 pt to 12 pt. The globe hides in focus mode. The bar stays, so the text doesn't shift.
- **Not seen in the simulator:** locked rows. DEBUG builds unlock every hymnal, so only owned rows can be shown there.

## 2. No ellipsis beside the hymn title

The `ellipsis.circle` on the Lectern's title button is gone. The handle chevron above the row is still the expand cue, and tapping the title still opens the hymn tray.

## 3. Hymn paging swipe (`HymnReaderView`)

- **The text moves on x only:**
  - The axis is decided after 8 pt of movement, before the scroll view's own pan begins.
  - A horizontal drag then sets `.scrollDisabled` for that drag.
  - A counter-offset cancels any vertical scroll that happened before the axis locked. `ScrollProbe` is a plain class, so tracking it doesn't re-render the reader.
  - The page offset is horizontal only.
- **Edge arrow:** `PageArrow` is a round chevron on the edge the next hymn comes from.
  - It grows from 30 to 52 pt and its ring fills as you drag.
  - At the threshold (22% of the width, at most 110 pt) it fills solid tint and a `UIImpactFeedbackGenerator(.medium)` fires once.
  - No arrow appears at the ends of the hymnal or playlist; the text rubber-bands instead.
- **Release:** past the threshold the hymn changes; before it, the text springs back. A fast flick no longer counts on its own; the threshold decides.
- **Reduce Motion:** the text stays still while dragging. Only the arrow fills (no growing or sliding), and the hymn change cross-fades.
- **Not tested with a real finger:** this harness can't send touches. The arrow was checked at fixed drag distances with `-uiDebugPageDrag`, and the drag logic was reviewed by reading it. Please try it on a device, especially diagonal swipes and a swipe that starts while the hymn is still scrolling.

## 4. Contrast: Memorise and Pitch pipe

- **Root cause:** the Tools sheet followed the system appearance but took the reading surface's text colour. On Black or Muted it drew light text on a light sheet; on Paper with the system in dark mode it was the other way round. That gave grey nav text and Done, invisible words, and dim chips and keys.
- **Fix:** `ToolSheetChrome` puts the whole sheet on the reading surface (`dsSurface`) with an opaque presentation background, and uses the high-contrast ground when Increase Contrast is on. This also fixes the other Tools sheets.
- **Colours** (`Extras/ToolControls.swift`; tokens only):
  - Selected chips, keys and the sound button: solid tint with `onTint` text.
  - Everything else: `elevated` fill with the new `DSSurface.controlBorder` outline (foreground at 62%).
  - Hidden words: full foreground text in a tint wash.
  - The action bar is opaque, so Reduce Transparency changes nothing.
- **Measured:** `python3 Tools/contrast_check.py` checks every pair on all five surfaces and exits 1 if any fails. All pass.
  - Lowest text pair: tint on Parchment, 4.65:1.
  - Lowest outline: Sepia, 3.21:1 (WCAG 1.4.11 asks for 3:1).
  - Tint text inside a tint wash measured 4.0–4.5:1, so it isn't used.
- **Checked by screenshot:** Black, Muted, Paper (with the system in dark mode) and Sepia with Increase Contrast.

## 5. Memorise as a game

- `Extras/MemoryRound.swift` holds the rules as a value type; `MemoryGameView` draws them.
- **Levels:** A few, Half, Most and All hide 25, 50, 75 or 100% of the words. The old "Read" level (nothing hidden) is gone, because it isn't a round.
- **Play:**
  - Blanks are filled in reading order. The next blank has a tint outline; later blanks are dashed.
  - Four chips offer the right word plus distractors from the same hymn: at most one later hidden word, then words of similar length. Distractors get the same capital letter as the answer, so case never gives it away.
- **Right word:** it drops in with a spring and a short brass glow, a success haptic plays, and the score and streak go up. It scores 10, plus 2 per word of the streak so far (bonus capped at +10).
- **Wrong word:** the chip shakes, is struck through and disabled, an error haptic plays, and the blank shows one more letter. The Hint button does the same on request. A word found after a mistake or a hint scores 5 and resets the streak.
- **Finish:** a card shows the score, best streak and first-try %. It offers Hide more words, then Next verse at the top level, and Play again.
- The verse and chorus tabs and the First letters toggle stay.
- **Accessibility:**
  - VoiceOver reads the verse with "blank" and "next blank starting L".
  - Chips are plain buttons, and right, wrong and finished are announced.
  - Reduce Motion replaces the shake, pop and scale with fades.
  - The chips and the verse wrap at large text sizes.

## Merge into main

`ui1` was merged into `main` in `../AdventPraise`, on top of the `midiplayer` merge. Two conflicts were resolved by hand:

- `HymnReaderView`: kept main's `player.cue` task and put the DEBUG page-drag hook before it.
- `ReaderToolbar`: kept main's header comment about the transport, without the `⋯`.

The merged tree builds for the iOS Simulator with no warnings in app code, and a launch smoke test showed the globe, the edge arrow, the Lectern without the ellipsis, and main's play button. Nothing was pushed. The main checkout's uncommitted `DEVELOPMENT_TEAM` edit in `project.pbxproj` was left as it was, unstaged.

## DEBUG-only launch arguments (`App/DebugLaunch.swift`)

These open a screen directly, for simulator screenshots. They aren't compiled into Release.

`-whatsNew.lastSeenVersion 7.0`, `-uiDebugSurface sepia`, `-uiDebugSheet memory|pitch|…`, `-uiDebugTranslations YES`, `-uiDebugPageDrag 60`, `-uiDebugMemoryMoves 3` (99 finishes the round).
