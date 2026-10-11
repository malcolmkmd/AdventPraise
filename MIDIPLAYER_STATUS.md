# MIDI player: status

Branch `midiplayer`, merged into `main`. Not pushed.

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' clean build`: **BUILD SUCCEEDED, 0 warnings** (Xcode 27.1, iOS 27.1 SDK, Swift 6 strict concurrency).

## MIDI files

- 245 Cyber Hymnal files are in `AdventPraise/Resources/Midi/` as `hymn-NNN.mid`, where NNN is the Christ In Song (English) number. That's every ledger row with decision `downloaded`. The other rows are 53 `not_found`, 1 `skipped_copyright` and 1 `download_failed`; none of those were copied.
- **`Tools/sync_midi.py`** copies the files and writes the manifest. Run it with `python3 Tools/sync_midi.py ../cyber AdventPraise/Resources/Midi`. It:
  - reads `ledger.csv`,
  - copies `midi-raw/hymn-NNN.mid` for each `downloaded` row,
  - deletes any `.mid` in the folder that the ledger no longer marks `downloaded`,
  - writes `Resources/Midi/midi-manifest.json` (`{"hymnals":{"english":{"file":"hymn-%03d","hymns":[…]}}}`),
  - writes provenance (page and .mid URL per hymn) to `docs/midi-sources.csv`, which isn't bundled.
- **After the second download pass:** re-run the script and rebuild. No code changes needed. The folder is folder-synced, so new files get bundled automatically.
- `Model/MIDICatalog.swift` reads the manifest. A hymn gets accompaniment only if it's listed **and** its file is in the bundle. Other hymnals can be added to the manifest later. Only English has files today: the `cs` cross-references in the other hymnals aren't reliable enough to map tunes.

## Player

- **Lectern:** the round play button (play/pause) only shows for hymns with a file. After the first play, a transport strip opens above the row and stays while paused. It has:
  - a scrub bar across all verses, with elapsed and total time at the chosen tempo,
  - Restart,
  - "Verse N of M",
  - a Tempo menu (Slow 0.8×, Medium, Fast 1.2×),
  - Loop.
  - Tempo and loop are saved. The strip closes when the hymn finishes, or when you open a different hymn (which stops playback).
- **Verse-aware playback:** the number of verses comes from the hymn text. The tune plays once per verse, and the chorus is inside each pass when the hymn has exactly one. In the reader:
  - the current verse is highlighted and the others are dimmed;
  - the chorus is highlighted during the chorus part of each pass (with "Chorus after every verse" on, only the copy under that verse);
  - the line being sung turns brass (colour only, so nothing re-wraps);
  - the reader scrolls to keep the current verse in view.
  - **Line timing is an estimate.** Each pass is split evenly across its lines. That suits regular hymn metres but won't match every tune exactly.
- **Audio:** no change at launch. The session (`.playback`, not mixable, so it gets Now Playing) is claimed on the first play. The engine graph is built on the first play (the lazy build from the crash fix is kept). `load()` only parses the file with AudioToolbox to get its length. When a hymn finishes or stops, the engine stops and the session is released with `notifyOthersOnDeactivation`. `UIBackgroundModes = audio` comes from `AdventPraise-Info.plist` at the repo root, which is merged with the generated Info.plist. (The `INFOPLIST_KEY_UIBackgroundModes` build setting is ignored by Xcode.)
- **Sound:** Apple's General MIDI bank (`gs_instruments.dls`, piano). If the OS has no bank, it falls back to the sampler's built-in voice. No `Piano.sf2`.
- **Interruptions and route changes:**
  - a call or alarm pauses playback, and it resumes if the system says it should;
  - unplugging headphones pauses;
  - an engine configuration change rebuilds the graph and keeps the place;
  - a media-services reset rebuilds without auto-playing.
- **Lock screen / Control Centre:** shows the title, hymnal, "Verse N of M", duration and position. Controls are play, pause, toggle, scrub, next (next hymn, or the next playlist entry, and keeps playing) and previous (restart).
- **Siri:** "Play hymn in Advent Praise" asks for the number, then opens the hymn and plays it. If the hymn has no file, it says so. "Next hymn" keeps playing if something was playing.
- **Playlists:** **Play** on a playlist (row, menu or editor) starts the accompaniment for the first hymn. When a hymn finishes, the next playlist entry opens and plays. Service-plan and collection queues advance the same way once something is playing. If the next hymn has no file, it opens and playback stops there.
- **Church mode:** unchanged. Playback carries on underneath it (the wiring lives in `AppServices`, not in a view).
- **More → About:** new last row, "MIDI files from The Cyber Hymnal (hymntime.com)", which opens http://hymntime.com.

## Files

- New: `Model/MIDICatalog.swift`, `Reader/LecternPlayer.swift`, `Tools/sync_midi.py`, `AdventPraise-Info.plist`, `Resources/Midi/*`, `docs/midi-sources.csv`.
- Rewritten: `Audio/HymnMIDIEngine.swift`.
- Edited:
  - `App/AdventPraiseApp.swift` (playlist, finish and next wiring)
  - `Reader/ReaderModel.swift` (`onPlaylistStarted`)
  - `Reader/HymnReaderView.swift` (cue, following, auto-scroll)
  - `Reader/LecternView.swift`
  - `Design/ReaderToolbar.swift` (pause icon)
  - `Design/ChapterVerseBlock.swift`, `ChorusBlock.swift`, `DesignTokens.swift` (`DSLyricText.highlightedLine`)
  - `Model/Hymn.swift`, `Model/Hymnal.swift`
  - `Intents/HymnIntents.swift`
  - `Reader/MoreDrawer.swift`, `App/AppInfo.swift`
  - `project.pbxproj` (`INFOPLIST_FILE`)

## Checked (2026-10-12)

On a new simulator, "AP MIDI 17 Pro" (iOS 27.0), using a temporary DEBUG launch hook that has since been removed:

- **Hymn 3:** 4 verses, 2:30 total. Position advanced verse 1, line 0 → 1 → 2 at about 4.7 s per line. After seeking to the end it finished cleanly (not playing, transport closed).
- **Screenshot during playback:** the transport strip, the brass current line, the verse 1 badge, and dimmed verses 2–4 and chorus all render correctly.
- **Queue [3, 5]:** at the end of hymn 3 the reader opened hymn 5 and it was playing. The screenshot showed the transport at verse 1 of 4.
- **Final build** without the hook: launched and stayed running, with no exceptions in the console.

## Not checked

- **Sound on a real device.** In the simulator, `gs_instruments.dls` comes from the Mac. Whether iOS devices ship that bank isn't confirmed. If they don't, the player still works but uses the sampler's plain default voice. If the tone is poor on device, the fix is to bundle a General MIDI SoundFont, which the brief ruled out for now.
- Not driven by touch, because no tap tool was available: the buttons, scrub dragging, tempo menu, loop, the lock-screen controls, real Siri, interruptions (calls) and unplugging headphones. The code paths are there but haven't been exercised by hand.
- Some Cyber Hymnal files may include a short intro or play the refrain differently from the printed text. Verse highlighting assumes one tune pass per verse.
