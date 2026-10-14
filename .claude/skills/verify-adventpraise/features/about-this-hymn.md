# About this hymn drawer

About this hymn is a drawer, not a sheet. Its root shows the hymnal and number, the title, the start of the story, then rows: Read the full story, Words and music, Sources, Scripture → Passages (each passage → other hymns on it), each collection, and Tools (Pitch pipe, Memorise a verse). Each row except Memorise pushes a page inside the same drawer. Back returns to the root, and only the root has Close. Memorise a verse opens its own full sheet.

## Sub-features

- `about-open` reader menu → About this hymn panel → full-details button opens the drawer on the open hymn.
- `about-pages` Story / Words and music / Sources / Passages each push a page (Back, no Close).
- `about-passage` Passages → "Also on <ref>" pushes a second-level page of other hymns on that passage.
- `about-pitch` Pitch pipe is a page in this drawer.
- `about-memorise` Memorise a verse leaves the drawer for the Memorise sheet.
- `about-collections` a collection row pushes that collection's hymns. 191 is in "Christian Life", but the journey doesn't tap it yet (next step to add).

## How to get to it (user POV)

- Tap the globe (`Reading options`) → the **About this hymn** tab → **Read the full story** (or **More about this hymn** when there is no story).
- Debug shortcut only: `-uiDebugSheet about`.

## Driving it with the APVerify harness

Preconditions:

- DEBUG build installed; the journey opens Christ In Song 191 "Blessed Assurance" via base arguments.

- **Run.** `xcodebuild test-without-building … -only-testing:APVerifyUITests/AboutHymnJourney`. Evidence in `../verify-evidence/<run>/about-this-hymn/`.
- **Open.** Tap `Reading options`, then `About this hymn`. Shot `menu-about-panel`. Tap `More about this hymn` (or `Read the full story` for a hymn with a story). The `Blessed Assurance` title and `Close` show, with no `Back`. Shot `about-root`.
- **Pages.** For each row present among `Read the full story`, `Words and music`, `Sources`, `Passages`: tap it. `Back` shows and `Close` doesn't (shot `page-…`). Tap Back and `Close` returns. At least two must push.
- **Passage level.** On Passages, tap an `Also on …` row if present. `Back` shows (shot `page-passage`). Back twice.
- **Pitch pipe.** Tap `Pitch pipe`, see `Back`, shot `page-pitch`, then Back.
- **Memorise.** Tap `Memorise a verse`. The navigation bar `Memorise` appears. Shot `memorise-sheet-from-about`.

## Gotchas

- Christ In Song 191 has **no story** (as of 7.0.1). The menu button reads `More about this hymn`, the drawer has no `Read the full story` row, and the root offers Words and music, Sources (2), Passages (≈ Hebrews 1:14), In collections → Christian Life, Pitch pipe, and Memorise a verse. For the story page, pick a hymn that has one (`-reader.lastHymn N`).
- "Read the full story" is both a reader-menu button and the drawer's first row. Once the drawer is open, the menu is closed, so the label is unique again.
- XCUITest reports the drawer as an **Alert** labelled `About this hymn`. Scope `Back`/`Close` with `drawer("About this hymn")`, because the reader menu's own `Close` stays in the tree.
- Rows depend on the hymn's data (story, sources, scripture links, collections). The journey logs a missing row as data and doesn't fail on it, but it requires at least two pages.
- The drawer's accessibility container is labelled `About this hymn`, as is the reader menu's tab button. Tap the tab only while the menu is open.
