# Crash fix: HymnMIDIEngine launch crash

## Cause
`HymnMIDIEngine.init()` (created at app launch in `AdventPraiseApp`) did
`engine.connect(sampler, to: engine.mainMixerNode, format: nil)` before any
audio session existed. The mixer's hardware format was 0 Hz / 0 channels and
AVAudioEngine raised an Objective-C exception, which Swift can't catch, so the
app died on launch.

## Fix
- `AdventPraise/Audio/HymnMIDIEngine.swift`
  - `init` no longer touches AVFoundation. The engine and sampler are built
    lazily in `preparedGraph()` the first time `play()` runs.
  - `load(_:)` doesn't touch audio: it only resolves the `.mid` URL and resets
    `duration` and the verse timing. The sequencer gets built on play.
  - `play()` order: activate the session (throws now, no more `try?`), build
    the graph, start the engine, build the sequencer, start.
  - The sampler is connected with an explicit format: standard stereo at the
    mixer's sample rate. The code checks that rate > 0 and throws
    `invalidOutputFormat` if it isn't, rather than letting AVAudioEngine raise
    an exception.
  - Sound bank: bundled `Piano.sf2`, falling back to the system
    `gs_instruments.dls` if it exists. If both are missing or fail to load, it
    logs and uses the sampler's default voice. A missing sound bank never
    throws.
  - Any setup failure gets logged (`Logger`, category `audio`), the graph is
    torn down and `isAvailable` is set to false. It never crashes.
- `AdventPraise/Reader/LecternView.swift`: the play control is hidden when
  `player.isAvailable` is false.
- `AdventPraise/Extras/PitchPipe.swift`: activates the audio session before
  `configureIfNeeded()` so it reads a valid output rate. It already connects
  with an explicit format.

Review changes on top of the earlier job's edits: an explicit stereo format,
instead of reusing the mixer's output format and its channel count, which
could be greater than 2 on some routes. Also resets `duration` and
`verseStartSeconds` in `load`.

## Verification (2026-10-11)
- Clean Debug build for iOS Simulator (Xcode 27.1 SDK, iPhone 17 Pro, iOS
  27.0): **BUILD SUCCEEDED, 0 warnings**.
- Installed and launched on a dedicated simulator, "AP Crashfix 17 Pro":
  - The What's New drawer showed, and the app stayed running.
  - Relaunched with What's New marked seen. The reader opened hymn 1, "Watchman
    Blow The Gospel Trumpet" (Christ In Song), and the process stayed alive. No
    exceptions or AVAudio errors in the unified log.
- Not exercised: the actual play path. No `.mid` or `Piano.sf2` is bundled
  yet, so every hymn has `hasAccompaniment == false` and the play control
  isn't shown. Navigating to other hymns by tapping wasn't possible because no
  tap tool was available in this session.
