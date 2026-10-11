# Playlists — status (branch `playlists`)

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' clean build` succeeds with **no warnings** (Xcode 27.1, Swift 6 mode). I ran it on an iPhone 17 Pro simulator and an iPad Pro 11-inch simulator (iOS 27.0), with old v1 playlists seeded in UserDefaults first.

## What works

- **Create with a name.** The + in the Lectern's library panel, "New Playlist…" on the hymn tray's Playlist tile, or "New Playlist" in the iPad sidebar asks for a name. The default is "Playlist N", skipping names already in use, and a blank name uses that default. The new playlist starts with the open hymn and opens in the editor.
- **Editor** (`Features/PlaylistEditorView.swift`): a native inset-grouped `List` with hymn number and title on each row, `EditButton`, `.onMove` (drag to reorder), `.onDelete` (swipe to remove), and a count header.
  - Tap a hymn to open it and follow the playlist from there.
  - The ⋯ menu has Rename (an alert with a text field) and Delete Playlist (an alert with Cancel / Delete).
  - **Play** and **Add Hymns** float at the bottom as `GlassButton`s. These are the only glass on the screen, and they stack vertically at accessibility text sizes.
  - Numbers this hymnal doesn't have show as "Not in this hymnal" and can't be opened.
- **Picker** ("Add Hymns", pushed): `.searchable` by number, title or words. A bare number puts that hymn first. Tap to add a hymn (at the end) or remove it; a check shows what's already in the playlist.
- **From the reader:** the hymn tray has a new **Playlist** tile, a menu of playlists with "New Playlist…". It is tinted when the open hymn is already in a playlist, and playlists that already contain the hymn are disabled in the menu.
- **Playlist rows** (`Features/PlaylistSummaryRow.swift`, shared by the Lectern panel and the iPad sidebar):
  - Tap plays; the pencil opens the editor.
  - Touch and hold for Play / Edit / Add hymn N / Rename / Delete.
  - In the sidebar, swipe for Delete / Edit.
  - Every delete asks first.
- **iPad sidebar:** Playlists (with New Playlist) and Favourites now sit **above** the hymn list. Before, they were below several hundred hymns. A search shows only matching hymns.
- **Queue / next / church mode / Siri:**
  - The running playlist follows the open hymn's position, not a stored index, so reordering or removing hymns while it's running doesn't derail it. If the open hymn is removed, it carries on from where that hymn was.
  - Numbers missing from the hymnal are skipped. Deleting the running playlist stops it.
  - `goToNextHymn()` (Siri "Next Hymn", accessibility action, church mode) and the MIDI `onFinish` both use this logic, unchanged in shape.
  - Church mode's forward control now checks `upcomingHymn` (the next playlist entry, then the next number).
  - The Lectern status line shows "Sabbath morning · 2 of 3" while a playlist is running.
- **Accessibility:**
  - Playlist rows are one element ("Name, 3 hymns", value = numbers or "Playing") with actions: Edit playlist, Add hymn N, Rename, Delete playlist.
  - Editor rows read "Hymn 12, title", with actions Move up / Move down / Remove from playlist (the VoiceOver alternative to dragging).
  - Picker rows report "In playlist" and the Selected trait.
  - Dynamic Type everywhere through `@ScaledMetric` and design fonts; checked at accessibility-XL.

## Storage and migration

- New key `reader.playlists.v2` holds `[hymnalID: [Playlist]]`. The `Playlist` struct is unchanged (`id`, `name`, `hymnNumbers`).
- **Migration:** on first launch without a readable v2, the v1 list (`reader.playlists.v1`) is moved under the hymnal that is open at that moment, with names, ids and order kept. v2 is then written. **v1 is never modified or deleted**, so going back to an older build loses nothing. I checked this in the simulator: "Sabbath morning" [1, 12, 100] and "Vespers" [5] came through under `english` with their names.
- **Note:** v1 was not actually per hymnal. One list was shared by every hymnal, and the brief's "as today" didn't match the code. Moving everything into the hymnal open at upgrade is a guess; the alternative was to copy the lists into every hymnal. Someone who built a list in one hymnal and then switched before upgrading will find it in the hymnal they had open at upgrade. Only 7.0 development/TestFlight builds ever wrote v1 (6.x didn't save playlists), so very few people should be affected.

## Small fixes made along the way

- `GlassButton` `.primary` on iOS 26: the label was dark on the evergreen glass because `dsSurface`'s foreground style overrode the prominent label colour. It now uses `surface.onTint`. This affects every primary GlassButton (Go, Unlock, …), and each of them was presumably low-contrast before.
- The Lectern's playlists panel hugs its rows (up to 300 pt, then scrolls) instead of always reserving 300 pt.

## Not done / notes

- No tests (as briefed).
- Not checked in the simulator by hand-driven taps. There was no tap/UI-automation tool in this session, so I opened each screen with a temporary launch-argument hook that has since been removed and took screenshots. Screens checked: library panel, hymn tray tile, editor, picker, name prompt, delete alert, playlist progress in the Lectern, iPad sidebar, and the editor at AX-XL. **Not checked by touch:** drag-to-reorder, swipe-to-delete, the EditButton mode, and the Rename alert. These are standard `List` / `.alert` APIs, but they're worth a quick manual pass.
- The iOS 17–25 fallback path compiles but wasn't run (simulators are iOS 27 only).
- When a playlist ends, "next" falls through to the next hymn number, as before.
- No new App Intent (for example "Play playlist X"). The existing intents keep working with playlists.
