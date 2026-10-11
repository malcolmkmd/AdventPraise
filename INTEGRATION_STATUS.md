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
- The `playlists` and `church` branches still need to be merged. Both are likely to touch `ReaderModel` (playlist and queue navigation) and `MoreDrawer`/`LecternPanels`.
