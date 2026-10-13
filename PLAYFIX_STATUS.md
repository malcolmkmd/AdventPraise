# Play opened the paywall with no free play (playfix) — status

Branch `playfix`, on top of freeplays (`FREEPLAYS_STATUS.md`), merged into `main`, not pushed.

**The bug.** TestFlight build 202610131639, on an iPhone 14 Pro that had had Debug builds of the same bundle
installed from Xcode: Play on hymn 37 opened the Pro paywall at once. Not one free play.

## Root cause

The free-play count was stored somewhere that outlives installs, under one name shared by every build.

- `FreePlays` keeps the used count in **UserDefaults** (`freePlays.used`) and in a **Keychain** generic password
  (service `<bundle id>.freePlays`). On launch the **higher** of the two wins.
- Keychain items survive deleting the app. With no `keychain-access-groups` entitlement, the item's access group
  is `<Team ID>.<bundle id>`, the same for a development-signed Debug build and the distribution-signed TestFlight
  build. Installing TestFlight over a Debug build also keeps the app's UserDefaults.
- Debug builds wrote real counts to those same names: `-uiDebugFreePlaysUsed N` (`debugSet` writes every store),
  and playing a Debug build with `-uiDebugFree YES`. Once a Debug run on that phone reached five, the TestFlight
  build read five plays used. Release has no RevenueCat key, so `isPro` is false, so `freePlaysAreUsedUp` was
  true on the very first Play: the engine called `onLocked` and opened the paywall.

I can't read the phone's Keychain from here, so the stored value of five is inferred, not observed. But it is the
only path that locks a fresh release build on the first Play. The others in the bug report were ruled out:

- **(b) Spending more than once.** It doesn't. `HymnMIDIEngine.play()` decides "new play" as `!isActive` before
  starting, checks the gate only for a new play, and calls `onNewPlay` once, after `seq.start()` succeeded. A
  failed start throws before that. Resume, scrub, restart, interruption-resume and route rebuilds all run with
  `isActive` true. `cue`/`load` never count. A playlist advance or lock-screen "next" while playing is a new hymn,
  counted once, by design. Even double counting couldn't lock the *first* Play: nothing had played yet.
- **(c) "Not configured" treated as locked.** In Release without a key, `isPro` is false. That is the intended
  free user: five plays, then the paywall. Nothing else reads `isConfigured` for gating. The only other paywall
  setters are More (support) and AirPlay (church mode with an external screen), not Play.
- **(d) Stale gate state.** `isLocked` is a closure read at the moment of the tap, from `store.isPro` and
  `freePlays.allowance`. `store.start()` runs in `App.init`, before any view.

## The fix

1. **Versioned, build-separated storage** (`FreePlayStorageName` in `Store/FreePlays.swift`):
   - Release builds use `freePlays.v2`: UserDefaults `freePlays.v2.used`, Keychain service
     `<bundle id>.freePlays.v2`.
   - DEBUG builds use `freePlays.v2.debug`, chosen by `#if DEBUG`. Nothing a Debug build writes (including
     `-uiDebugFreePlaysUsed`, which is DEBUG-only code anyway) can reach a TestFlight or App Store build on the
     same phone.
   - The old `freePlays.used` / `.freePlays` items are never read (and left alone). Bump the version to start
     everyone at zero again.
   - Reinstall protection is unchanged: within a name, the higher of Keychain and UserDefaults still wins.
2. **A play is counted once, when audio starts.** That was already the case (see (b)). Now `free_play_used` is
   also only sent for plays that are actually counted, not for plays let through past the limit (below).
3. **No dead end without purchases.** `PurchaseStore.canPurchase` (a RevenueCat key, or the DEBUG mock). When it's
   false, the player's paywall keeps "Purchases aren't available in this build." and adds **Keep playing**. That
   closes the sheet and plays the hymn anyway (`AppServices.keepPlayingWithoutPro()` lets that one play past the
   gate). So the TestFlight build still shows five free plays, then the paywall, and stays usable after it.

## Tests

`AdventPraiseTests/FreePlaysTests.swift`, new:

- `aCountLeftByPreReleaseBuildsIsIgnored`: reproduces the bug. Five used under the old names locks the first
  Play; under the current names the same user has five plays, each counted once, then none. The old items are
  left untouched.
- `aDebugCountNeverReachesRelease`: five written under the debug name; a release-named `FreePlays` has five left.
- `theNamesAreVersionedAndKeptApart`: legacy, release and debug names differ; a DEBUG build's default storage
  uses `freePlays.v2.debug`.

**Result: 15 tests in 3 suites, all passed** (`xcodebuild … -destination 'id=<AP MIDI 17 Pro>' test`, foreground,
the only simulator booted). Builds: Debug simulator plus tests, and Release simulator: both **no warnings**.

## Not done / notes

- **Keep playing** wasn't seen on screen. A DEBUG build has the mock store (`canPurchase` true), so the button
  only appears in a Release build without a key, like TestFlight 202610131639's successor. Check it on the next
  TestFlight: use five plays, then Play opens the paywall with Keep playing.
- Once the RevenueCat key is in, `canPurchase` is true and Keep playing never shows.
- The disk was full during this round (about 400 MB free; one edit and one build failed with ENOSPC). Derived
  data went to `build/dd-playfix` and was deleted after each build.
- On Malcolm's phone, the old count stays in the Keychain under the old name, unused. Nothing needs doing.
