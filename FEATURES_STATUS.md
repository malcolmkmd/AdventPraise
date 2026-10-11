# AdventPraise 7.0 — features branch status

Branch `features`. `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with no warnings in app code (Xcode 27.1, Swift 6, complete strict concurrency). The app launches on the iPhone 17 Pro simulator, and the four data files are in the built bundle. The new sheets compile, but I didn't tap through them in the simulator.

## Where it lives

All new code is in `AdventPraise/Extras/` and all new data is in `AdventPraise/Resources/Extras/`. The folder-synced group picks both up automatically. Existing files were touched only to hook the new code in:

| File | Change |
|---|---|
| `Reader/LecternView.swift` | `MoreGroup` / `MoreRow` are no longer `private`. Adds one line in the More panel: `ExtrasMoreGroup(model:tint:)`, a new **Tools** group. |
| `Reader/HymnReaderView.swift` | Adds one line: `.extrasSheets(model: model)`. |
| `Reader/ReaderModel.swift` | Adds `play(queue:)`, an unsaved ordered list that runs like a playlist. `nextHymn` and `goToNextHymn` follow it and stop after its last hymn, so church mode shows "Done". Opening a hymn by number, going back, switching hymnal or playing a playlist clears it. |

`Extras/Extras.swift` holds the coordinator (`Extras.shared.sheet`). Every tool is presented in a single sheet with its own `NavigationStack` and a Done button. Church mode is started after that sheet has been dismissed.

## Features

All data files ship **empty**: no stories, passages, collection contents or starting notes have been invented. Each file uses the format `{ "version": 1, "hymnals": { "<hymnal key>": { "<hymn number>": … } } }` and is loaded by `ExtrasData.swift` (`PerHymnFile`). Collections are the one exception and use their own shape.

- **Hymn stories:** `HymnStories.swift` and `hymn_stories.json`.
  - Fields: `words`, `music`, `year`, `story` and `sources`, all optional.
  - Shown in **Tools → About this hymn**, with "No story has been added for this hymn yet" when a hymn has none.
- **Scripture links:** `ScriptureLinks.swift` and `scripture_links.json`.
  - Each passage is `{ "book": "John", "chapter": 3, "from": 16, "to": 17 }`. `from`/`to` are optional; leaving them out means the whole chapter. `book` must be a full name from `BibleBook.names`.
  - About this hymn lists the hymn's passages. Tapping one shows every other hymn whose passage overlaps it.
  - **Tools → Scripture index** lists every linked passage in canonical order, grouped by book, and can be searched.
- **Collections:** `HymnCollections.swift`, `CollectionsView.swift` and `hymn_collections.json`.
  - Six collections are defined: Christmas, Easter, Communion, Wedding, Funeral and Children. Each has a title and an SF Symbol, and `hymns` is an empty per-hymnal map, e.g. `"hymns": { "english": [12, 40] }`.
  - Until an editor fills them, each shows "Coming soon".
  - A filled collection opens hymns, offers **Sing in church mode** (runs in order through the queue) and **Copy to a new service plan**.
  - About this hymn lists the collections that include the open hymn.
- **Pitch pipe:** `PitchPipe.swift` and `PitchPipeView.swift`, with data in `pitch_notes.json` as `{ "key": "F major", "note": "C4" }`.
  - The tone is a soft sine wave with a little of the octave and twelfth added. It is rendered by an `AVAudioSourceNode` in its own `AVAudioEngine`, separate from the MIDI graph, with a 40 ms attack and a 250 ms release so it doesn't click.
  - A tap sounds the note for 2.5 s. The audio session (`.playback`, mix with others) is only claimed when the note plays.
  - With no published note, the singer picks one from a chromatic keyboard (octaves 2–5). That choice is remembered per hymn in UserDefaults (`pitch.custom.v1`) and wins over the published note.
  - The note is shown on the Tools row. The pitch pipe can also be opened from About this hymn and from each service-plan hymn.
- **Memory game:** `MemoryGameView.swift` (**Tools → Memorise a verse**).
  - Pick a verse or the chorus, then a level: Read / A few / Half / Most / All, hiding 0, 25, 50, 75 or 100% of the words.
  - Tap a blank to peek at its word; peeked words turn brass. "First letters" shows hints.
  - **New blanks** reshuffles which words are hidden; **Hide more** moves up a level. There's a peek counter.
  - Includes a reusable `FlowLayout`.
- **Service planner:** `ServicePlanner.swift` and `ServicePlannerView.swift` (**Tools → Service planner**).
  - Plans belong to one hymnal and are saved in UserDefaults (`service.plans.v1`). A new plan defaults to the coming Saturday's date and starts with the open hymn.
  - Each plan has an editable name and date. Hymns can be reordered (drag or Edit), removed by swiping, or added from the open hymn or by number (validated against the hymnal).
  - Each hymn can have an optional role ("Opening hymn", "Closing hymn", …), open in the reader, or open the pitch pipe.
  - **Start in church mode** runs the plan in order and ends after its last hymn.

## Not done / follow-ups

- **Content:** all four data files need sourced entries, and only `english` has a key so far (other hymnals can be added the same way). Stories should cite their sources in `sources`.
- Stories and scripture are keyed per hymnal. There's no automatic sharing across translations through the `AH`/`SDAH` cross-references yet.
- There's no pitch pipe button inside church mode itself; it's reachable from the planner and Tools. Adding one means editing `ChurchModeView.swift`.
- No analytics events for the new tools, other than `church_mode_started` when church mode is started from a plan or collection.
- No tests, as briefed.
