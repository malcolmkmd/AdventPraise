# AdventPraise — scripture branch status

Branch `scripture`. Christ In Song (`english`) now has **423 scripture references across 230 of its 300 hymns**. They show in **Tools → About this hymn** as tappable chips that open the passage in the YouVersion Bible app, or on bible.com in Safari when it isn't installed. `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' clean build` succeeds with no warnings (Xcode 27.1). I checked it in a dedicated simulator, "AP Scripture 17 Pro" (iOS 27.0); see Verification.

## Where the references come from (read this first)

The brief asked for public-domain references printed in the source hymnal data, or the 1908 *Christ in Song* / hymnary.org scripture indices where available. In practice:

- **The source data has none.** The bundled hymnal files (and the converters in `Tools/`) only hold number, title, refs (AH/SDAH numbers) and lyrics. No scripture field exists anywhere in the data.
- **The printed indices could not be used.** This session had no network access: curl, WebFetch and WebSearch were all blocked. Also, this 300-hymn *Christ In Song* is not the 949-hymn 1908 book. Its numbers don't match, so the 1908 index couldn't be applied directly even with access.

So every reference shipped is **`source: "lyric"`**: the hymn's own words quote or closely paraphrase a specific KJV verse. No scripture text, quotes, authors or dates were added to the app.

- **Evidence.** Each reference carries the exact lyric line it rests on, in `docs/scripture/english.jsonl` (with a short "why"). It is not shipped in the app.
- **Machine checks.** `Tools/build_scripture_links.py` rejects any row whose line isn't verbatim in that hymn, whose book name is unknown, whose chapter doesn't exist (KJV chapter counts), or whose verse range is malformed. All 423 pass.
- **Not machine-checked.** That the verse number is right for the quoted words comes from the reviewer's knowledge of the KJV (subagents drafted, I reviewed all 434 candidates). Checking against an actual KJV text is the obvious follow-up.
- **Confidence.**
  - `high` (the hymn quotes or near-quotes the verse): 106 references.
  - `medium` (an unmistakable echo of one specific passage): 317 references. These show with **≈** on the chip and a footnote.
  - No low-confidence or "thematic" links were kept.
- **Review edits.** I dropped 10 loose candidates (e.g. 46 → John 6:68, 241 → Deuteronomy 33:28, 251 → John 11:35) and downgraded 6 "high" entries to medium. I also narrowed 204 from Luke 15 to Luke 15:11–32.
- **Uncovered hymns.** 70 hymns have no reference, on purpose. Their words don't clearly quote a passage (e.g. 56, 58, 224).
- **Room for other sources.** The format already accepts `cis1908` (text printed with the hymn) and `hymnary` sources. When someone with access goes through hymnary.org or a printed index, add rows with that `source` to the JSONL and rerun the builder.

## Data format

`AdventPraise/Resources/Extras/scripture_links.json` is generated; don't edit it by hand. Edit `docs/scripture/english.jsonl` and run `python3 Tools/build_scripture_links.py`.

```json
{"version":2,"columns":["ref","source","confidence"],
 "sources":{…legend…},"confidence":{…legend…},
 "hymnals":{"english":{
 "168":[["Psalms 23:1","lyric","high"],["Psalms 23:5","lyric","high"],["Psalms 23:6","lyric","medium"]],
 …}}}
```

- **Rows.** Each hymn has rows of `[ref, source, confidence]`, one hymn per line, about 17 KB in total.
- **`ref`.** Either `Book C`, `Book C:V` or `Book C:V-W`, with a full book name from `BibleBook.names`.
- **Loader.** The existing `PerHymnFile` loader is unchanged; v2 just changes the entry type to `[ScriptureLink]`.

## Code

All the changes stay in the features data files, their loaders and views, plus the analytics event list. Nothing in the reader header, bottom action bar, splash or church mode top bar was touched.

| File | Change |
|---|---|
| `Extras/ScriptureLinks.swift` | `Passage(reference:)` parser; `ScriptureLink` (decodes a row), `ScriptureSource`, `ScriptureConfidence`; USFM book codes; `Passage.bibleURL`. |
| `Extras/AboutHymnView.swift` | The Scripture section is a flow of `ScriptureChip`s. A footer names the source and explains ≈. Passages another hymn shares get an "Also on John 3:16 · 2 hymns" row, which links to the existing passage page. The passage page (also reached from the Scripture index) gets a "Read …" chip. |
| `Services/AnalyticsEvent.swift`, `ANALYTICS_PLAN.md` | `scripture_opened`: `hymnal`, `book` (USFM), `surface` (`about_hymn` \| `passage`), plus `hymn_number` and `confidence` on About this hymn. |
| `Tools/build_scripture_links.py`, `docs/scripture/english.jsonl` | Builder/validator and the reviewed evidence. |

### Opening the Bible app

- **Link format.** Chips open `https://www.bible.com/bible/1/<USFM>.<chapter>[.<verse>[-<verse>]]` (version 1 = KJV) through SwiftUI `openURL`.
- **Universal link.** That is a universal link: YouVersion opens it when installed, otherwise Safari. Because no custom scheme (`youversion://`) is used, **`LSApplicationQueriesSchemes` isn't needed and Info.plist is unchanged**. `canOpenURL` is never called.
- **Not tested with YouVersion.** The simulator doesn't have YouVersion, so the app hand-off itself wasn't tested; Safari was.

## Verification

Screenshots are in `wt-scripture/.scratch/` (not committed; the repo keeps no screenshots):

- `about168.png`: hymn 168 "The Lord Is My Shepherd" shows chips for Psalms 23:1, Psalms 23:5 and ≈ Psalms 23:6, with the footer.
- `about1.png`: hymn 1 shows three ≈ chips plus "Also on Matthew 11:28 · 9 hymns" and "Also on Luke 14:23 · 1 hymn".
- `index.png`: the Scripture index is now populated, grouped by book in canonical order.
- `safari.png` and `range.png`: the generated URLs `…/MAT.11.28` and `…/LUK.15.11-32` open in Safari as the KJV verse and range, with the "◀ Advent Praise" back link.

Limits:

- **Chip taps and the event weren't exercised.** No touch-automation tool was available, so I didn't tap a chip in the app. I opened the same URLs with `simctl openurl` instead, so the `scripture_opened` event wasn't seen firing either.
- **The passage page's Read chip wasn't screenshotted.** It is the same `ScriptureChip`.
- **How the sheet was opened.** The About sheet was opened through a temporary DEBUG launch hook, which was removed before committing.

## Follow-ups

- Check each verse number against a KJV text file (the builder can take one), then add `hymnary` / `cis1908` rows where those indices are available.
- Translations: references are keyed by hymnal. The other hymnals could inherit `english` references through their `refs.vern` / AH / SDAH cross-references, but that isn't done.
- 70 hymns without references.
