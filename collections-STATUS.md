# Collections status

> **Update (branch `langs`):** 7.0 ships only English, Chichewa, Tswana, Xhosa, Sotho, Shona, Venda, Zulu and Ndebele. `hymn_collections.json` now lists only those (Zulu has Ndebele's numbers; same book), and the SDA Hymnal's own lists are gone with it. `build_collections.py` reads `sdah.json` from `build/hymnals-all` (`convert_hymnals.py --all`) to check cross-references. The coverage below is the beta's, kept for when hymnals come back. See `LANGS_STATUS.md`.

Branch `collections`. Collections were empty placeholders (Christmas, Easter, Communion, Wedding, Funeral, Children) with no hymns. They are now the topical sections of the **Seventh-day Adventist Hymnal (1985)**. Each section opens to its hymns in the open hymnal, which can be sung in church mode or copied to a service plan, as before.

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeded with **no warnings** after each commit. Screenshots were taken on a new iPhone 17 Pro simulator (iOS 27.0, "AP Collections 17 Pro"). The reader header, bottom bar, splash and church mode top bar weren't touched.

## Sources

- Hymnal page: https://hymnary.org/hymnal/SDAH1985
- Topic (section) index, 46 pages: https://hymnary.org/browse/topics/SDAH1985 (`?page=0` … `?page=45`), fetched 2026-10-12.
- Saved to `_src/sdah1985/hymnary_topics_SDAH1985.txt`: every heading and its hymn numbers, page by page, with the URLs. hymnary.org shows a bunny.net bot challenge to curl, so the pages were read with WebFetch and the raw HTML couldn't be kept. `_src/` is gitignored (like `_src/cis-v2`), so this file is only in the `wt-collections` worktree, not in git.
- CIS→SDAH cross-references: `refs.sdah` in `Resources/Hymnals/english.json` (the "(Vern-1, AH-350, SDAH-368)" subtitles) and `hymnal_references` in `_src/cis-v2/tonga/tonga.json` and `_src/cis-v2/sepedi/sepedi.json`.

## Sections

The hymnary.org index gives 13 hymn sections that cover SDAH 1–695 with no gaps. Hymns 696 and up are scripture readings, calls to worship, benedictions and similar, and aren't used. `Tools/build_collections.py` checks the ranges against the saved index on every run. The only number filed outside its range is 651, which hymnary.org also lists under Christian Church; in the hymnal it's in Christian Home.

| # | Section | Symbol | SDAH | SDA Hymnal | Christ In Song | Kinyarwanda |
|---|---|---|---|---|---|---|
| 1 | Worship | `hands.sparkles` | 1–69 | 69 | 7 | 6 |
| 2 | Trinity | `triangle` | 70–73 | 4 | 1 | 1 |
| 3 | God the Father | `sun.max` | 74–114 | 41 | 3 | 2 |
| 4 | Jesus Christ | `crown` | 115–256 | 142 | 29 | 21 |
| 5 | Holy Spirit | `flame` | 257–270 | 14 | 3 | 3 |
| 6 | Holy Scriptures | `book` | 271–278 | 8 | 1 | 1 |
| 7 | Gospel | `heart` | 279–343 | 65 | 29 | 24 |
| 8 | Christian Church | `building.columns` | 344–379 | 36 | 11 | 9 |
| 9 | Doctrines | `text.book.closed` | 380–437 | 58 | 13 | 11 |
| 10 | Early Advent | `hourglass` | 438–454 | 17 | 3 | 3 |
| 11 | Christian Life | `figure.walk` | 455–649 | 195 | 55 | 44 |
| 12 | Christian Home | `house` | 650–659 | 10 | 1 | 1 |
| 13 | Sentences and Responses | `text.bubble` | 660–695 | 36 | 1 | 1 |

Jesus Christ uses `crown` because SF Symbols' `cross` looks like a medical plus.

## Mapping

- **SDA Hymnal:** its own numbers go straight into the ranges, so all 695 hymns are in a section.
- **Christ In Song:** each hymn goes in the section of its SDAH cross-reference. A ref is only used if the SDAH hymn it points to has the same title or first line, because the refs contain slips:
  - 139 refs come from the English subtitles.
  - 15 come from Tonga/Sepedi `hymnal_references`. These fix the English refs at 23, 59, 68, 79, 115, 119, 120, 121 and 269 (119–121 are shifted by one in the English source) and add refs the English source lacks.
  - 3 were corrected by an exact first-line match: 106 Build On The Rock → 531, and 173/174, whose refs are swapped (→ 440 and 533).
  - 5 were rejected because no ref matched and no SDAH first line matched either: 71 Is My Name Written There?, 172 How Long?, 241 Beulah Land, 258 One Living Faith, 284 While The Days Are Going By.
  - **157 of 300 CIS hymns are in a section. 143 aren't:** 138 have no SDAH ref and 5 had refs that were rejected. As decided, unreferenced hymns aren't guessed at. For reference, only 4 of the 143 have a near-identical first line in the SDAH, so first-line matching wouldn't add much.
- **Hymnals that share CIS numbering** get the CIS numbers as they are. These were confirmed by `title_english`, matching AH refs, and verse/chorus shape against the English edition at the same number: Ndebele/isiZulu, Tswana, Sotho, Shona, Venda, isiXhosa, Xitsonga, Chichewa, Tonga, Tumbuka, Sepedi and Icibemba (numbers 1–300). Kinyarwanda follows CIS only up to 200; from 201 it has different hymns, so only 1–200 are mapped. Hymns above 300 (Chichewa, isiXhosa, Tonga, etc.) aren't in any section.
- **Not covered:** Swahili, Gikuyu, Abagusii, Dholuo, Português, Español, Français, Русский and Twi. Their numbering matches neither CIS nor the SDAH, so the Collections screen shows an empty state that explains why.

### Coverage by hymnal

| Hymnal | Hymns | In a section | Not in a section |
|---|---|---|---|
| SDA Hymnal | 695 | 695 | 0 |
| Christ In Song (English) | 300 | 157 | 143 |
| Ndebele / isiZulu, Tswana, Sotho, Shona | 300 each | 157 | 143 |
| Venda | 306 | 157 | 149 |
| isiXhosa | 352 | 157 | 195 |
| Xitsonga | 311 | 157 | 154 |
| Chichewa | 350 | 157 | 193 |
| Tonga | 341 | 157 | 184 |
| Tumbuka | 372 | 157 | 215 |
| Sepedi | 303 | 157 | 146 |
| Icibemba | 311 | 157 | 154 |
| Kinyarwanda | 500 | 127 | 373 |

## Files

- `Tools/build_collections.py` writes `Resources/Extras/hymn_collections.json`. Run it with `--check` to print the report (ref fixes, rejections, counts per section and hymnal) without writing the file. It needs `_src/sdah1985` and `_src/cis-v2`.
- `hymn_collections.json` is version 2. Each collection has `id`, `title`, `symbol`, `order`, `sdah` [first, last], `counts` per hymnal, and `hymns` per hymnal.
- `HymnCollections.swift` decodes `order` and `sdah` and sorts collections by `order`. `available(in:)` returns the sections that have hymns in a given hymnal.
- `CollectionsView.swift`:
  - The list shows only the sections with hymns in the open hymnal, with counts and a footer naming the source.
  - If the open hymnal has none, it shows an empty state that explains why.
  - The detail view has a hymn-count header and an "SDA Hymnal 1–69" footer.
- The More drawer's Collections row subtitle changed from "Christmas, Easter…" to "Worship, Gospel…".
- `-uiDebugCollection <id>` (DEBUG, used with `-uiDebugSheet collections`) opens a section for screenshots.

## Verified by screenshot

- Christ In Song: all 13 sections with counts. Jesus Christ opens with its 29 hymns (3 Face To Face, 7 When He Cometh, …).
- SDA Hymnal, Christian Home: 650–659, whose titles confirm the range.
- Tonga, Gospel: 29 hymns in Tonga titles.
- Himnario Adventista (es): the empty state.

**Not tested by touch:** tapping a row to open the hymn, church mode from a section, and copying to a service plan. These actions are unchanged from before.

## Merge into main

- `collections` was merged into `main` (on top of the scripture merge, 923a1e5) with no conflicts. `DebugLaunch.swift` auto-merged.
- **Rebuild:** a Debug build of the merged tree for the iOS Simulator succeeded with **no warnings**.
- **Smoke test:** the merged build ran on the iPhone 17 Pro simulator. Collections for Ndebele/isiZulu showed all 13 sections with the expected counts.
- Not pushed.

## Not done

- Subsections (for example Jesus Christ → Birth, Second Advent) are in the saved source, but the extraction dropped some of the Christian Life subheadings. Collections stay at section level.
- Occasion lists (Christmas, Communion, …) were replaced, not kept alongside. Jesus Christ covers SDAH 118–143 (Birth) and 165–176 (Resurrection), but there's no separate Christmas list.
