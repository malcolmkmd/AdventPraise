# AdventPraise 7.0 — integration status

Five branches were merged into `main`, one at a time and in this order, each as a `--no-ff` merge commit. Nothing was pushed. `playlists` and `church` were left alone because other jobs are still writing them.

After every merge, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` ended in **BUILD SUCCEEDED** with **no warnings or errors**. The one warning that came in (features) was fixed before the merge was committed.

| # | Branch | Merge commit | Base | Conflicts |
|---|---|---|---|---|
| 1 | polish | `e8d4034` | 71a6f5c | none |
| 2 | reader | `c50eaa9` | 71a6f5c | `HymnReaderView.swift` |
| 3 | sheet | `d681614` | 71a6f5c | `AppearanceControls.swift`, `WhatsNewSheet.swift`, `LecternView.swift` |
| 4 | features | `e808960` | **3c87c31** (before the design system) | `HymnReaderView.swift`, `LecternView.swift`, `ReaderModel.swift` |
| 5 | store | `16c2aa0` | **3c87c31** (before the design system) | `LecternView.swift`, `STATUS.md` |

The per-branch notes are still in the repo: `POLISH_STATUS.md`, `READER_STATUS.md`, `SHEET_STATUS.md`, `FEATURES_STATUS.md` and `docs/appstore/STATUS.md`.

## How conflicts were resolved

### 1. polish
Merged cleanly. Its Lectern, split into `LecternView` and `LecternPanels`, is the base for everything after it.

### 2. reader
- **`HymnReaderView`, lyric `ForEach`:** both sides kept.
  - From polish: the stable `ReaderBlock` identity (`v1`, `c1`, …).
  - From reader: the pinch-aware `style`, the `Group` wrapper, and the accessibility next/previous-hymn actions.

### 3. sheet
The drawer replaces the system sheets for What's New, Appearance and More.

- **`AppearanceControls`:** `appearanceDrawer` replaces polish's `appearanceSheet` and its `AppearanceSheetBackground`. The drawer's `dsGlass(.sheet)` already turns opaque when Reduce Transparency is on.
- **`WhatsNewSheet`:** the drawer style keeps polish's rule.
  - Normally (iOS 26) the Stage is drawn at 0.92 opacity.
  - Before iOS 26, **or with Reduce Transparency on**, it is opaque. Sheet had only the iOS check, so the Reduce Transparency part was added back. The style now reads the environment.
  - Polish's `ActionsScrim` and `StagePresentation` were dropped, because the drawer's `actionScrim` does that job now.
- **`LecternView` / `LecternPanels`:** polish's split structure is kept, with sheet's change applied to it.
  - `LecternState.more` and `LecternMorePanel` are removed, along with its `MoreRow`/`MoreToggleRow` and `import StoreKit`.
  - The More tile in the hymn tray now runs `closeLectern(); showMore = true`.
  - The header comments point to `MoreDrawer.swift`.
- **`MoreDrawer`:** the row titles are now `LocalizedStringKey`, carrying over polish's localization fix from the old More rows.
- **`RootView`:** fixed a stray `}    }` that came in with the merge.

### 4. features
Features was branched before the design-system commits. Its `LecternView` was the old monolithic file built on `env.*`, `MoreGroup` and `MoreRow(tint:)`. So its hooks were **ported by hand** instead of being merged:

- **`LecternView`:** main's version kept as is.
- **Tools group:** now a `DSInsetGroup(title: "Tools")` in the **More drawer**, between Reading and Help us improve.
  - Rows: About this hymn, Scripture index, Collections, Pitch pipe, Memorise a verse, Service planner.
  - Each row closes the drawer and sets `Extras.shared.sheet`.
  - `ExtrasMoreGroup` became `ExtraSheet.toolsOrder` plus `title`, `systemImage` and `detail(for:)`. The pitch-note detail logic is unchanged.
  - `MoreGroup` and `MoreRow` stay private.
- **`ReaderModel`:** both behaviours are kept.
  - From features: the unsaved queue, `play(queue:)`. The queue is cleared by opening a number, going back, switching hymnal or playing a playlist, and a finished queue stops ("Done").
  - From reader: stepping back through a playlist with `playlistEntry(offset:)`, plus `upcomingHymn` and `precedingHymn`.
  - `advancePlaylist()` runs the queue first, then the playlist through `playlistEntry`.
  - `upcomingHymn` follows the queue through `nextHymn`.
- **`HymnReaderView`:** `.extrasSheets(model:)` is added inside `.dsSurface`. Features' `.environment(\.colorScheme, env.colorScheme)` was dropped, because `ReadingEnvironment` no longer exists and `dsSurface` sets the colour scheme.
- **Extras source:** renamed to the current tokens.
  - `Vesper.brass` / `Vesper.evergreen` → `DS.Palette.brass` / `DS.Palette.evergreen` (same hex values).
  - `PressScaleStyle()` → `DSPressStyle()`.
- **`PitchPipe.swift`:** the render block now uses `withLockUnchecked` instead of `withLock`. This removes a Swift 6 warning about capturing the non-Sendable `UnsafeMutableAudioBufferListPointer` in a `@Sendable` closure. The pointer is only used on the render thread.

### 5. store
This branch was also based on 3c87c31, so its More change was ported.

- **`LecternView`:** main's version kept.
- **`MoreDrawer`:**
  - "Rate on the App Store" now opens `AppInfo.writeReviewURL` instead of `requestReview()`.
  - A new "Privacy policy" row opens `AppInfo.privacyPolicyURL`.
  - `requestReview` and `import StoreKit` were removed.
- **`STATUS.md`:** item 4 is store's (support email and privacy policy). Item 5 is main's (replace the placeholder icon), since the placeholder icon is already committed.
- The other store files merged cleanly: `AppInfo`, `PrivacyInfo.xcprivacy`, `Analytics`, the hymnal JSON, `convert_hymnals.py` and `docs/appstore/`.

## Dropped

- polish's `appearanceSheet` / `AppearanceSheetBackground`, What's New `ActionsScrim` / `StagePresentation`, and `LecternMorePanel` (More panel inside the Lectern). The drawer replaced all of these on purpose, and their intent (Reduce Transparency, localized titles) was carried over.
- features' `ExtrasMoreGroup` and the public `MoreGroup` / `MoreRow` from the old LecternView. Replaced by the Tools group in `MoreDrawer`.
- features' `env.colorScheme` modifier in `HymnReaderView` (API no longer exists).
- No feature from any branch was dropped.

## Not done / worth checking

- **Nothing was run in the simulator after integrating.** Only builds were checked. Worth tapping through by hand:
  - More drawer → each Tools row. The system sheet opens as the drawer closes.
  - More → Rate and Privacy policy.
  - Swiping between hymns while a service-plan queue runs.
  - What's New with Reduce Transparency on.
- The Extras views (pitch pipe, memory game, planner and so on) still use the older `scaledFont` and fixed-size styling, and they open in a system sheet rather than the drawer. They work, but they haven't been brought into the Vesper design system.
- `FEATURES_STATUS.md` and `docs/appstore/` still describe the Tools group and Privacy row as living "in the More panel" in `LecternView`. They are now in `Reader/MoreDrawer.swift`.
- The `playlists` and `church` branches still need to be merged. Both are likely to touch `ReaderModel` (playlist and queue navigation) and `MoreDrawer`/`LecternPanels`. *(Done in pass 2, below.)*

---

# Pass 2: playlists and church

Two more branches were merged into `main`, one at a time and in this order, each as a `--no-ff` merge commit. Nothing was pushed.

After each merge, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` ended in **BUILD SUCCEEDED** with **no warnings or errors**. Another job held the shared DerivedData lock, so these builds used `-derivedDataPath /tmp/ap-integrate-dd`. That was a full build from scratch.

| # | Branch | Merge commit | Base | Conflicts |
|---|---|---|---|---|
| 6 | playlists | `c4d7ab7` | 71a6f5c | `GlassButton.swift`, `LecternView.swift`, `ReaderModel.swift`, `STATUS.md` |
| 7 | church | `9bacb56` | 71a6f5c | `WorshipModeControls.swift`, `ChurchModeView.swift`, `VesperTheme.swift` |

The per-branch notes are in `PLAYLISTS_STATUS.md` and `CHURCH_STATUS.md`.

## 6. playlists

- **`LecternView`:** main's split version kept. Playlists edited the old single-file Lectern (hymn tray, library panel and More panel all inline), so its changes were **ported by hand** into `LecternPanels.swift`:
  - **Hymn tray:** the new **Playlist** menu tile sits between Church and Hymnal. More still opens the drawer (`showMore`), not the removed `.more` panel.
  - **`TrayTileLabel`:** split out of `TrayTile` so the Menu tile and the button tiles share one face. It keeps main's `LocalizedStringKey` label, scaled icon slot and content shape, and adds playlists' `lineLimit(1)` / `minimumScaleFactor(0.8)` (six tiles now share the row).
  - **Library → Playlists:** uses `PlaylistSummaryRow` in place of main's private `PlaylistRow`, which was removed. The "hug a short list, then scroll at 300 pt" behaviour comes from main's `DSFittingScroll` instead of playlists' `onGeometryChange` + `@State` height. The empty-state text is playlists' ("Tap + to start one…").
  - The status line's "Sabbath morning · 2 of 3" (`model.playlistProgress`) merged cleanly into `LecternView`.
- **`ReaderModel`:** both sides kept.
  - **From features (main):** the unsaved queue (`play(queue:)`, `activeQueue`), which runs before the playlist in `advancePlaylist()` and `nextHymn`. A finished queue stops.
  - **From reader (main):** stepping back with `precedingHymn` / `goToPreviousHymn()`.
  - **From playlists:** per-hymnal storage (v2 + v1 migration), the editor, rename and delete-with-confirm, `play(_:from:)`, `activePlaylistID`, `playlistProgress`, and following the **open hymn's position** rather than the stored index.
  - The two ways of finding the neighbouring entry became one: `playlistEntry(step:)`. It works from playlists' `activePosition` and skips numbers the hymnal lacks, in both directions. It drives `upcomingHymn`, `precedingHymn`, `advancePlaylist()` and `goToPreviousHymn()`. If the open hymn was removed from the running playlist, previous goes to the entry just before the gap and next to the one just after it.
  - `play(_:from:)` also clears the queue, as main's `play(_:)` did.
- **`GlassButton`:** playlists' fix (primary labels use `surface.onTint`, because `dsSurface`'s foreground style overrode the prominent label colour) was applied to main's restructured button. It now covers both `.glassProminent` **and** the on-glass `.borderedProminent` variant, which has the same problem. Main's shared `button`/`borderShape` structure is kept, so playlists' per-case `buttonBorderShape` became unnecessary.
- **`STATUS.md`:** playlists' "saved per hymnal" line, with main's fuller privacy-manifest line and App Store prep line.
- Merged cleanly: `RootView` (editor sheet, name prompt, rename and delete alerts, iPad sidebar with Playlists and Favourites above the hymns), `PlaylistEditorView`, `PlaylistSummaryRow`.

## 7. church

Both sides had fixed church-mode text size in different ways. Main (reader branch) added a continuous `worshipPointSize` with pinch to zoom. Church added a stepped `worshipStep` with limits, large print and scrolling. Both are combined:

- **`ReadingSettings` (`VesperTheme.swift`):** kept main's continuous **`worshipPointSize`**, because pinch needs sizes between the steps. Church's `worshipStep` / `worshipStepRange` / snapshot field were dropped; that field was never on main. Taken from church:
  - **42 pt default** (`steps[1]`, was `steps[defaultStep]` = 48), because verses now scroll rather than shrink.
  - `stepWorshipText(by:)`, which returns false at a limit. It now moves to the next worship step from wherever a pinch left the size (main's `stepSize` logic, moved here). `worshipStepTarget(by:)` exposes the target so the view can disable the buttons.
  - The `Comparable.clamped(to:)` helper. The saved size is clamped to the worship pinch range on load.
- **`ChurchModeView`:** church's version is the base, with main's features put back.
  - **From church:** the number-pad popover from the hymn chip; the translation popover (owned hymnals, same number, stays on the verse); VoiceOver actions; scrolling for long verses instead of `minimumScaleFactor(0.28)`; the large-print ×1.2 boost; clamping to 28–96 pt; smaller/larger disabled at the ends, with a selection haptic or a rigid one at a limit; swipes only count when mostly horizontal, so long verses can scroll; and the controls staying up while a popover is open or VoiceOver is on.
  - **From main:** pinch to zoom (`PinchZoom`, over the worship pinch range); double-tap to reset (only listening while zoomed); taps and swipes ignored while pinching; the chorus in the reader's bold-italic chorus face with its brass rule and "Chorus" spoken label; `canGoForward` using `model.upcomingHymn` (playlist- and queue-aware; church used `nextHymn`); `@ScaledMetric(relativeTo: .largeTitle)`.
  - **Auto-hide:** main's `.task(id: hideGeneration)` (a67b3ff replaced church's style of detached `Task`), plus church's conditions: no countdown while a popover is open or VoiceOver is on, checked again after the sleep.
  - The size buttons animate the change, as main's did.
- **`WorshipModeControls`:** church's layout kept.
  - Top: hymn chip (number pad), globe, leave. Bottom: previous, smaller/larger, next.
  - It keeps the generic `NumberPad`/`Translations` popovers and the `EmptyView` convenience init.
  - Opacity, hit testing and accessibility hiding wrap the glass container. Main applied opacity inside the container, which left the glass buttons on screen on iOS 26.
  - Main's tweaks carried over:
    - Disabled glass buttons are dimmed to `DS.Fill.disabled` on iOS 26 too ("too subtle to read across a pew").
    - The label is inset by `DS.Space.m` (12 pt), from main's be26def tuning, instead of church's 14 pt.
    - No stroke on the prominent fallback circle.
  - Main's `WorshipGlass` / `WorshipIconButton` were replaced by church's `WorshipButtonChrome` / `WorshipButton`.
  - Church's chrome Dynamic Type cap (`accessibility1`) was kept over main's `accessibility2`, because church's controls are larger and were checked at AX XL.
- **`STATUS.md`:** church's description of the controls. The line "sized to fit between the controls" was updated to say long verses scroll, and that pinch and double-tap size the text.

## Dropped in pass 2

- playlists' inline Lectern panels (`hymnTray`, `libraryPanel`, `morePanel`, `MoreRow`, …) in `LecternView`. Their playlist parts were ported to `LecternPanels`; the More panel had already been replaced by the drawer.
- main's private `PlaylistRow` (replaced by `PlaylistSummaryRow`) and `playlistEntry(offset:)` (replaced by `playlistEntry(step:)`).
- church's `worshipStep` storage (replaced by the continuous `worshipPointSize`, which pinch needs).
- main's `minimumScaleFactor(0.28)` in church mode (church showed that it undid the chosen size).
- No feature from either branch was dropped.

## Not done / worth checking (pass 2)

- **Still only builds were checked, not the simulator.** Worth trying by hand:
  - The Playlist tile in the hymn tray. Six tiles now share one row, so check the labels on a small iPhone and at large text sizes.
  - Playing a playlist, then a service-plan queue, then a playlist again. Next and previous should follow whichever started last.
  - Previous and next after removing the open hymn from a running playlist.
  - In church mode, pinch to an in-between size, then the smaller/larger buttons. They should snap to the neighbouring step and disable at 36 and 64 pt.
  - Pinching while a long verse is scrolled. Double-tap to reset.
  - With Large print on, the larger button should disable at the 96 pt clamp.
  - Church mode: the number pad and translation popovers with VoiceOver on (controls should stay visible).
- Anyone who ran a church-branch build has a saved `worshipStep` that is now ignored. Church mode returns to 42 pt once. That only affects development builds.
- `CHURCH_STATUS.md` still describes the step-based storage (`worshipStep`) and the 36–64 pt step-only sizing. The behaviour is now as described above.
