# UI3 — status

Branch `ui3`, five tasks, one commit each. After every commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeded with no warnings. Screenshots were taken on an iPhone 17 Pro and an iPad Air 11-inch simulator (iOS 27.0). This harness can't send touches, so anything that needs a finger is marked **not tested by touch** below.

## 1. More: Done goes back to More

- **Before:** every row in More closed the drawer and opened its screen. Pressing Done on that screen dropped the user back on the reader.
- **Now:** Appearance, the six Tools sheets and the two Mail rows stand in for More "one level down".
  - Closing them with Done, Cancel or a swipe reopens More.
  - More reopens scrolled to the row the user came from, so they are where they left off.
- **How:**
  - `ReaderModel.leaveMore(for:open:)` remembers the row and opens the screen.
  - The Extras sheet's `onDismiss`, the Appearance drawer's new `onDismiss` and the Mail sheet's `onDismiss` all call `returnToMore()`.
  - `MoreDrawer` wraps its content in a `ScrollViewReader` and scrolls to the remembered row on appear.
- **Moving on still moves on:** opening a hymn from a Tool (Scripture index, a collection, Open in reader) or starting church mode clears the return. `ReaderModel.show` does this, so the reader stays in front.
- **Unchanged on purpose:** Church mode and Hymnals hand over to another mode or panel rather than a sub-page, so they don't come back to More. The share sheet already opened on top of More.
- **Not tested by touch:** Done and swipe-to-dismiss on each screen.

## 2. Church mode: the playlist or plan in the number pad

- **When it shows:** whenever a playlist, service plan or collection is running.
- **What it shows:** tapping the hymn chip opens the number pad with the list above the keys (`Features/ChurchQueueList.swift`):
  - A header with the list's name and "n of N".
  - Every hymn in order. The next hymn is drawn solid tint, labelled **Next** and scrolled into view. The open hymn is marked **Now**.
  - Hymns this hymnal lacks are muted and can't be chosen.
- **Tapping a hymn** shows it and follows the list on from there. `ReaderModel.jumpInQueue(to:)` keeps the playlist or queue running.
- **Typing a number:** if the number is on the list, the pad jumps within the list instead of leaving it. Any other number opens normally and leaves the list, as before.
- **Recents** are hidden while the list shows, to keep the popover a sensible height.
- **Queue names:** service plans and collections now pass their names (`play(queue:named:source:)`), so the header can show them.
- **Checked by screenshot:** a five-hymn plan, with "Now" and "Next" correct and the list scrolling.
- **Not tested by touch:** tapping a row.

## 3. Service planner: the field stays above the keyboard

- **Before:** each hymn added pushed "Add by number" down a row, so it slid under the keyboard after a few entries.
- **Now:** the plan's list scrolls the field to just above the keyboard, together with its title preview when that shows. This happens:
  - when the field is focused (after the keyboard has risen),
  - after each hymn is added,
  - when the preview line appears.
- **Code:** the list moved into `planList(_:)` so a `ScrollViewReader` can wrap it.
- **Not tested by touch:** there is no keyboard in this harness. Please add five or six hymns in a row on a small iPhone.

## 4. The playlist button

### How it was investigated

- No touches here, so I ran the buttons' exact action closures from a temporary DEBUG probe and took a screenshot after each step. The probe was removed before committing.
- **Steps on iPhone:** New Playlist from the tray tile, Create, close the editor, add hymns, open the library on Playlists, play a row, then Next.
- **Result:** every step presented and updated correctly: the alert, the editor sheet, the panel, and "Sabbath · 1 of 3" → "2 of 3".
- **On iPad,** the same probe toggled the sidebar. That exposed the first cause below.

### Cause 1 — the button never showed its state on iPad

- `ReaderToolbar` took the bookmark button's on state from `openPanel == .library` only.
- On iPad (and any regular width) the button toggles the split view's sidebar instead of opening that panel. So it stayed unlit while the sidebar was showing the playlists, unlike iPhone, where it fills and tints.
- **Fix:**
  - `RootView` mirrors the sidebar's visibility into `ReaderModel.isSidebarVisible`, for regular width and not hidden.
  - `ReaderToolbar` has a new `libraryIsOn` that lights the button (`bookmark.fill`, tint).
  - Checked by screenshot: lit with the sidebar out, plain once it's hidden.

### Cause 2 — Play in the editor's bottom bar could do nothing

- `ReaderModel.play(_:from:)` returned silently when the playlist's *first* entry wasn't in the open hymnal. Play then still dismissed the sheet, so it looked as if nothing happened.
- That can happen with lists moved into a hymnal by the v1 → v2 migration.
- **Fix:**
  - `play()` starts at the first entry the hymnal has, as Next already skips missing ones.
  - The bar's Play is disabled when no entry is playable (`canPlay`), not just when the list is empty.

### Not fixed — worth checking on a device

The Lectern capsule's own swipe (`.gesture(DragGesture)`: down > 40 pt collapses it) may also catch a downward scroll in the library panel's playlist list. I couldn't confirm it without touches, so it is left as it was.

## 5. Project

`DEVELOPMENT_TEAM` is now `B534EWRJTS` in both app configurations (Debug and Release).

## DEBUG-only launch arguments added

- `-uiDebugQueue 12,30,45` runs those numbers as a service plan named "Sabbath morning".
- `-uiDebugChurchPad YES` opens church mode's number pad. Use it with `-uiDebugChurch YES`.
- `-uiDebugLectern hymn|library` opens that Lectern panel.

To skip What's New, use `-whatsNew.lastSeenVersion 7.0`. It must match the current version exactly.

## Merge into main

See the end of this file (added after the merge).
