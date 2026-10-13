# Langs status

Branch `langs`, merged into `main`, not pushed. Every build was `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build`, run in the foreground. Each one succeeded with **no warnings**. Screenshots were taken on a new simulator, "AP Langs 17 Pro" (iPhone 17 Pro, iOS 27.0).

## 1. Relaunch with the nine 6.3 hymnals

**Bundled:** English, Chichewa, Tswana, Xhosa, Sotho, Shona, Venda, Zulu and Ndebele, in that order (the order 6.3 listed them). The language labels are the 6.3 names, so "isiXhosa" is now "Xhosa" and "Ndebele / isiZulu" is now "Ndebele".

**Zulu wasn't bundled.** It is now. `zulu.json` is built by `Tools/convert_hymnals.py` from `../handoff/zulu.min.json` (the legacy 6.x Zulu text), with the cis-v2 Ndebele spelling fixes applied, the same way Ndebele already was. It's the same book (UKrestu Esihlabelelweni, 300 hymns), so the two files differ only in key and label.

**Removed from the bundle:** sdah, twi, pt, es, ru, dg, kinyarwanda, tumbuka, abagusii, tonga, dholuo, xitsonga, sepedi, gikuyu, icibemba and swahili. The built `.app` contains only the nine hymnal files plus `hymnals.json`.

**They can still be regenerated:**
- `python3 Tools/convert_hymnals.py ../handoff AdventPraise/Resources/Hymnals` writes the nine bundled hymnals (the `BUNDLED` list).
- Adding `--all` also writes the other 16. Point it at a scratch directory, e.g. `build/hymnals-all`.
- Before changing anything, I checked that the converter reproduced every old file byte for byte. After the change, `--all` output is identical to before except for Ndebele's label and the new Zulu file.

**Other references updated:**
- **Collections:** `hymn_collections.json` now lists only the nine. Zulu uses Ndebele's numbers. The SDA Hymnal's own lists are gone.
  - `build_collections.py` now reads `sdah.json` from `build/hymnals-all` (only to check cross-references), and its `CIS_NUMBERED` list is the bundled set.
  - The hymnary.org source file it checks against (`_src/sdah1985`) isn't in the repo, so I couldn't run the tool itself. I trimmed the JSON with the same logic the tool would apply.
  - The `sdah`-only footer branch in `CollectionsView` is gone.
- **Scripture links, stories, pitch notes, MIDI:** these only ever had English, so nothing changed.
- **Siri / App Intents and analytics enums:** nothing names a hymnal. Hymnal keys are free strings, so nothing changed here either. The examples in `ANALYTICS_PLAN.md` and `ANALYTICS_AUDIT.md` now use bundled keys.
- **App copy:** the share text now reads "Christ In Song in 9 languages." The Tonga refrain example is gone from the previews.
- **App Store docs** (`docs/appstore/listing.md`, `screenshots.md`, `STATUS.md`):
  - Subtitle: `Christ In Song in 9 languages` (29 chars).
  - Description: the new list of nine. It's now 1,921 chars.
  - Keywords: `swahili` is replaced by `venda` (95 bytes).
  - What's New: "All nine hymnals in one place, and every one is free."
- **`STATUS.md`:** the "Translations" and "which hymnals are free" lines are updated.

**Saved state** (`Model/RemovedHymnals.swift`, `ReaderModel.moveOffRemovedHymnals`, `ServicePlanner.copyPlansOffRemovedHymnals`):
- **Open hymnal:** if it was a removed hymnal, the reader opens English. It goes to the matching hymn if there is one, otherwise hymn 1, and recents are mapped the same way.
- **Favourites, playlists and service plans** of removed hymnals are copied into English once (guarded by a flag). Only hymns with a known English match are kept.
  - Tonga, Xitsonga, Tumbuka, Sepedi and Icibemba keep their numbers up to 300, and Kinyarwanda up to 200 (the same CIS alignment Collections uses).
  - SDA Hymnal numbers are mapped through the English "SDAH n" cross-references.
  - Swahili, Twi, Português, Español, Русский, Français, Kikuyu, Abagusii and Dholuo have their own numbering, so their hymns can't be mapped. Those hymns are dropped from the copies.
  - Copies are named "Sabbath · Tonga" so the user can see where they came from.
  - The originals stay in UserDefaults, untouched, in case a hymnal comes back.
- **Verified on the simulator** by seeding a container where the reader was on `tonga`, with favourites `tonga#12`, `sdah#368` and `swahili#5`, and playlists for `tonga` (12, 330, 30) and `sdah` (368, 999). After launch:
  - The hymnal was English and the last hymn was 30.
  - `english#12` was added (`sdah#368` became `english#1`, which was already there), and `swahili#5` was not copied.
  - The playlists became "Sabbath · Tonga" [12, 30] and "Vespers · SDA Hymnal" [1].
- **Service-plan copying was not exercised on the simulator.** It's the same mapping code.
- **Who this affects:** only 7.0 beta users could have had these hymnals selected. 6.x users never had them.

## 2. Translation selector colours

The old palette was assigned by position in the list and reused the brand Evergreen (`#1F7466`) and Brass (`#7F5B1C`) as hymnal colours, shown as a small square. It's replaced by:

- **`DS.Language`** (`DesignTokens.swift`): nine earthy tones, keyed by hymnal id, so a colour never moves when the list changes. Each has a light-surface and a dark-surface value; the dark ones are a step lighter so tiles don't sink into the Muted/Black grounds.

  | Hymnal | Colour | Light | Dark |
  |---|---|---|---|
  | English | Indigo | `#3F3D8F` | `#5250A6` |
  | Chichewa | Terracotta | `#A3452A` | `#A54B30` |
  | Tswana | Sapphire | `#1D5A94` | `#2866A2` |
  | Xhosa | Teal | `#0F6878` | `#13707F` |
  | Sotho | Ochre | `#8A5908` | `#8F5E0C` |
  | Shona | Olive | `#5C6B1A` | `#5F6F1D` |
  | Venda | Plum | `#74305E` | `#8A3B70` |
  | Zulu | Forest | `#2D6639` | `#34723F` |
  | Ndebele | Clay | `#8F4F55` | `#95545A` |
  | (unknown) | Slate | `#4C5857` | `#5A6766` |

- **`LanguageTile`** (`Design/LanguageTile.swift`): the whole tile is the language's colour. The language is in serif semibold and the hymnal title (or "No hymn N · opens the first hymn") sits under it.
  - Text is `surface.languageInk`: white on light surfaces, warm off-white `#F7F1E6` on dark ones. It's drawn at full opacity, so hierarchy comes from type, not fading.
  - **Current hymnal:** a check badge plus a 2 pt ring in the surface's ink, 3 pt outside the tile. That keeps the ring readable against both the ground and any tile colour.
  - The purchasing and locked states are still supported.
  - **`LanguageTileGrid`** shows two columns, or one at accessibility text sizes. Each row is as tall as its tallest tile.
- **Contrast:** `Tools/contrast_check.py` now checks every fill against its ink on all five surfaces, plus the ring against the ground. All pass. The lowest tile text is 4.94:1 (Olive on dark); light surfaces are 5.88–9.23:1.
- **Where it's used:**
  - The reader's globe menu (Translation panel).
  - Church mode's translation popover.
  - `LanguagePicker` (iPad Hymnals sheet).
  - `LanguageMenuButton`, which now shows a `LanguageChip` (a filled capsule in the language's colour).
  - The component gallery and previews.
- `PaywallLanguageRow`, `PricePill`, the swatch radius and size tokens, and `Color(hex:)` are removed. `PaywallUnlockAllButton` moved to its own file.
- **New DEBUG launch argument:** `-uiDebugChurchTranslations YES` opens church mode's switcher, for screenshots.

**Screenshots** (`build/shots/langs/`, gitignored):
- `selector-paper.png`: light, hymn 12, English current.
- `selector-black.png`: dark, Xhosa hymn 320. Most tiles show "No hymn 320".
- `selector-church.png`: church mode's popover, with Shona current.

## Not done / notes

- **Touch wasn't tested.** This harness can't tap, so screens were opened with launch arguments.
- **The `LanguagePicker` grid** (iPad sidebar sheet) shares the tile code but wasn't screenshotted on iPad.
- **The listing used to say** other hymnals "can be bought". `PurchaseConfig.swift` says every hymnal is free from 7.0, so the listing now says so.
- **Bundle size:** the hymnal folder went from about 6.5 MB to about 2 MB.
- **Simulators:** the Mac hit its process limit once mid-session ("fork failed"). I shut my simulator down for the rebuild, then booted it again. "AP Langs 17 Pro" is shut down now.
