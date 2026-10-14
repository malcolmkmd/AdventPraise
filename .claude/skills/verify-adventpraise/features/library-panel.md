# Library panel: Add hymn and New Playlist

The Lectern's library panel holds Favourites and Playlists behind a full-width segmented control. A full-width button at the panel's foot follows the tab: **Add hymn** on Favourites asks for a number and stars that hymn in the open hymnal (a gentle "No Hymn N" alert when the hymnal has no such number), **New Playlist** on Playlists names and creates a playlist holding the open hymn and opens its editor. After the very first playlist only, closing its editor brings the library back on Playlists (iPad: the sidebar) to show where it lives.

## Sub-features

- `lib-open` the library button opens the panel on Favourites, tabs spanning the panel, Add hymn at its foot.
- `lib-add-hymn` Add hymn → type a number → Add puts that hymn in Favourites, marked favourite.
- `lib-add-missing` a number the hymnal lacks shows "No Hymn N" with Try Again / Cancel; nothing is added.
- `lib-tab-cta` switching to Playlists swaps the foot button to New Playlist.
- `lib-new-playlist` New Playlist → name → Create opens the editor on that name, holding the open hymn.
- `lib-first-reveal` closing the first playlist's editor reopens the library on Playlists with the new row (once per install).

## How to get to it (user POV)

- iPhone: the Lectern's **Favourites and playlists** button (bottom bar, beside the number/search key).
- iPad (regular width): the sidebar's Favourites and Playlists sections; the first-playlist reveal shows the sidebar instead of the panel.
- The hymn tray's **Playlist** tile also creates a first playlist (same name prompt), but not the Add hymn CTA.

## Driving it with the APVerify harness

Preconditions:

- Fresh install on `AP Verify iPhone` (SKILL.md → Launch: uninstall, then install): no favourites, no playlists, reveal flag unspent.
- iPhone simulator (compact width); the iPad path is not covered by the journey.

- **Run.** `xcodebuild test-without-building … -only-testing:APVerifyUITests/LibraryPanelJourney` (full command in SKILL.md). Evidence in `../verify-evidence/<run>/library-panel/`.
- **Open.** Tap `Favourites and playlists`. The segmented control is >70% of the window wide, `Add hymn` sits below it. Shot `favourites-empty`.
- **Add 100.** Tap `Add hymn`; alert `Add Hymn`; type `100`; tap `Add`. A row labelled `100, What A Friend We Have In Jesus, favourite, …` appears. Shots `add-hymn-alert`, `favourite-added`.
- **Missing number.** Add hymn → `9999` → Add. Alert `No Hymn 9999` with `Try Again`. Shot `no-such-hymn`; Cancel.
- **Playlists tab.** Tap the `Playlists` segment. `New Playlist` replaces `Add hymn`. Shot `playlists-empty`.
- **Create.** Tap `New Playlist`; alert `New Playlist`; type `Verify set`; `Create`. Navigation bar `Verify set`, holding hymn 191. Shot `playlist-editor`.
- **Reveal.** Tap `Done`. The library is back on Playlists with a row labelled `Verify set, 1 hymn`. Shot `first-playlist-revealed`.
- **Quick look without a path.** `-uiDebugLectern library` opens the panel directly (not proof of the button).

## Gotchas

- Favourites, playlists and `reader.firstPlaylistRevealed` persist in UserDefaults. Without the uninstall the reveal step fails (it fires once per install) and Favourites isn't empty.
- Don't pass `-reader.favourites.v2` or playlist keys as launch arguments: the argument domain would mask what the app saves, so additions would look lost.
- Hymn numbers are per hymnal. The journey pins `-reader.hymnal english` (Christ In Song, 1–?); 100 must exist and 9999 must not.
- The number field is a `.numberPad` text field inside an alert. Tap it before typing.
