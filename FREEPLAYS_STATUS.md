# Free playlists and five free plays (freeplays) — status

Branch `freeplays`, on top of paywall3 (`PAYWALL3_STATUS.md`), merged into `main`, not pushed. Every build was
`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build`
(and `build-for-testing`), run in the foreground, with **no warnings**.

## 1. Playlists and the service planner are free

They were never gated in code; only the copy sold them as Pro. The paywall's feature list loses
"Service planner and unlimited playlists" and is now four lines: **Unlimited MIDI sing-along player** · Church mode
with AirPlay casting · Pitch pipe · Unlimited Memorise (two columns on iPad, 2 + 2). The comment in
`PurchaseConfig.swift` says so too. Nothing else in the repo (fastlane metadata, docs) mentioned unlimited playlists.

## 2. Five free plays of the accompaniment

- **`Store/FreePlays.swift`.** `FreePlayAllowance` is the pure counting (`free = 5`, `used`, `remaining`,
  `isUsedUp`, `isLastPlay`, `spend()`, `reconciled(_:)`). `FreePlays` (@Observable, @MainActor, in `AppServices` and
  the environment) keeps the count in **UserDefaults** (`freePlays.used`) and the **Keychain** (generic password,
  service `<bundle id>.freePlays`, `AfterFirstUnlockThisDeviceOnly` so a playlist can advance with the screen locked).
  On launch the higher of the two wins and both are brought up to it, so deleting and reinstalling the app doesn't
  give five more plays. (Restoring a backup onto a new device starts at zero; the Keychain item is this-device-only.)
- **What counts as a play.** `HymnMIDIEngine.play()` treats a play as new when the player isn't active: the first Play
  on a hymn, or Play after it stopped or finished. Resuming after a pause, scrubbing, Restart, an interruption ending,
  and Siri asking for the hymn that is already up are all the same play. A new play is counted through
  `onNewPlay` only once audio is actually running (a failed start counts nothing). A playlist moving on to its next
  hymn is a new play. Pro never counts.
- **The gate.** `player.isLocked` is now `AppServices.freePlaysAreUsedUp` (not Pro and no plays left) and is only
  checked for new plays, so a free user can always pause and resume the fifth play to its end. When it is locked,
  `onLocked` opens the paywall (`ProFeature.player`) from wherever the play came from: the Lectern, a playlist, the
  lock screen, Siri.
- **The Lectern.** Play is no longer short-circuited to the paywall; it goes to the engine, and if the engine opened
  the paywall instead there's no play haptic. The lock badge on Play shows only when Play would open the paywall.
  Before the last free play the status row says **"1 free play left"** instead of "<Hymnal> · piano ready".
- **The paywall**, when it comes from Play: "You've had your free plays of the piano. Pro keeps it playing with you,
  and opens everything below."
- **Siri** ("Play hymn 12") just asks the engine; if the plays are used up it says so and the paywall is open.
- **Restore purchases** is unchanged; `isPro` comes from the entitlement, and as soon as it's active the gate opens
  (and the paywall's existing "unlocked" path closes the sheet and carries on).
- **Analytics** (also in `ANALYTICS_PLAN.md`):
  - `free_play_used` — `hymn_number`, `remaining` (left after this one, 4…0).
  - `play_limit_paywall_shown` — `hymn_number`; followed by the usual `paywall_viewed` with `feature = player`.
- **DEBUG:** `-uiDebugFreePlaysUsed N` sets the stored count (4: the next play is the last; 5: Play opens the
  paywall). Use it with `-uiDebugFree YES` when there is no RevenueCat key (DEBUG is otherwise Pro).

## 3. Unit tests

The project had no test target; it now has **AdventPraiseTests** (Swift Testing, hosted in the app, in the
AdventPraise scheme's Test action; the folder is a synchronized group, so new test files are picked up).
`FreePlaysTests.swift` covers: five plays then none, the sixth refused and uncounted, the last-play hint, clamping,
the higher stored count winning, a reinstall keeping the Keychain count, the count outlasting a launch, saving to
every store, and real UserDefaults and Keychain round trips.

**Result: 12 tests in 3 suites, all passed** (`xcodebuild … -destination 'id=<AP MIDI 17 Pro>' test`, foreground),
run twice: on this branch, and again after merging main (with hands) in. Run them with ⌘U or:
`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'platform=iOS Simulator,name=AP MIDI 17 Pro' test`.

## Verified on the simulator

AP MIDI 17 Pro, DEBUG, no RevenueCat key, `-uiDebugFree YES`. Screenshots in `build/shots/freeplays/` (gitignored):

| File | What |
| --- | --- |
| `last-play-hint.png` | `-uiDebugFreePlaysUsed 4`: the Lectern row reads "1 free play left"; no lock on Play. |
| `used-up-lock.png` | `-uiDebugFreePlaysUsed 5`: the lock badge on Play. |
| `paywall.png` | The paywall from Play: the new lead line, four features (no playlists), the hands crowd from main. |

Not tapped through (no touch driver from the shell): playing five hymns in a row and the sixth opening the
paywall. That path is the engine gate plus the counter; the counter is unit-tested, and the gate is the same
`isLocked → onLocked` path that used to lock every play.

## Notes from this round

- **Builds:** Debug and Release, simulator and device (unsigned), plus `build-for-testing`: all with no warnings.
- **Merged with hands.** Main already had `hands` (the crowd's slow rise and fall in `PaywallScenery.swift`).
  The two branches touch no file in common; main merged into `freeplays` with no conflicts, and then `freeplays`
  was fast-forwarded into `main`.
- **Tests and concurrent simulators.** While another session's simulator was booted and running its own
  `xcodebuild test`, this branch's test run hung, with the host app stuck on the launch screen and no tests
  started. With only this branch's simulator booted, the tests ran in under a minute. Run tests with one
  simulator booted. The simulator was shut down at the end.
- The hint first read "<Hymnal> · 1 free play left" and "Piano ready · 1 free play left"; both truncated in the
  Lectern row on an iPhone 17 Pro, so it is just **"1 free play left"**.

## Not done / to decide

- Five is `FreePlayAllowance.free`; change it there.
- With the plays used up, the Lectern row still says "<Hymnal> · piano ready" next to the locked Play. It could say
  "Piano with Pro" instead, if that's wanted.
