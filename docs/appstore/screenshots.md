# Screenshot plan — Advent Praise 7.0

## Sizes you must upload

The app is iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`), so both of these are required.
App Store Connect scales them down for smaller devices.

| Slot | Simulator | Portrait pixels |
|---|---|---|
| iPhone 6.9" | iPhone 17 Pro Max | 1320 × 2868 (1290 × 2796 also accepted) |
| iPad 13" | iPad Pro 13-inch (M5) | 2064 × 2752 (2048 × 2732 also accepted) |

Up to 10 per slot. Plan: 6 iPhone and 5 iPad. PNG, RGB, no transparency.

## Capture rules

- Prices must be real (Guideline 2.3.3). Release and TestFlight builds price from the
  App Store. In Debug, run from Xcode (the scheme's Debug Run uses
  `StoreKit/AdventPraise.storekit`) or use `scripts/storekit-shot.sh`, so the paywall
  shows the configured prices. Every hymnal is free; free (not Pro) is the default.
  Launch with `-uiDebugPro YES` to unlock Pro in DEBUG. `-uiDebugFree` no longer exists.
- Set the status bar first: `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
- Dismiss What's New first, except for shot 6.
- **No play button or "piano" text** anywhere. Playback doesn't ship in 7.0.
- Use hymn text from **Christ In Song** (1908, public domain). Don't put SDA Hymnal
  text in screenshots until the rights question in `review-notes.md` is settled.
- Captions are optional. If you use them: one line, sentence case, the Vesper serif,
  on the Paper background `#F7F4EE`. Keep them on the top 18 % of the frame so the UI
  stays readable.

## iPhone shots (in order: the first 3 show in search results)

| # | Screen | Setup | Caption |
|---|---|---|---|
| 1 | Reader, Paper theme | Christ In Song hymn 1 (or a well-known hymn with a chorus), Lectern collapsed | **Every hymn, beautifully set** |
| 2 | Church mode | Same hymn, verse 2. Black, large text | **Church mode: one verse at a time** |
| 3 | Number pad | Typed "12" with the live title preview showing | **Go to any hymn by number** |
| 4 | Hymnals panel | Hymn title → Hymnal. Shows the language tiles with English ticked | **Christ In Song in 9 languages** |
| 5 | Appearance sheet | Sepia theme, Large print on | **Large print and reading themes** |
| 6 | Word search | "Abc", query "blessed", with results listed | **Search the words you remember** |

Optional 7: Siri, a Shortcuts tile for "Open Hymn". Only use a real capture, never
a mock-up of the Siri UI.

## iPad shots (landscape is fine for iPad, but keep them all in one orientation)

| # | Screen | Caption |
|---|---|---|
| 1 | Split view: hymn list with search on the left, reader on the right | **Your hymnal, side by side** |
| 2 | Church mode, full screen | **Made for the front of the church** |
| 3 | Reader in Black theme with Large print | **Easy to read anywhere** |
| 4 | Hymnals panel | **Christ In Song in 9 languages** |
| 5 | Playlists (library → Playlists) with one playlist filled | **Plan the order of service** |

## Localised screenshots (later)

The listing is English-only for 7.0. The App Store has no locale for most of the
bundled languages (Shona, Venda, Ndebele…); if Portuguese, Spanish or French hymnals
come back, those locales are the ones to add, each with its own hymnal open.

## App preview video

Skip for 7.0. If you make one later, it's a 15–30 s capture of the number pad going to
a hymn and then Church mode, with no audio track.
