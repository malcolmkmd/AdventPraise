# MIRROR_STATUS — Screen mirroring banner and the Pro worship display

Branch `mirror`, merged into `main`. Not pushed.

`xcodebuild … build` for the iOS Simulator: **no warnings, no errors** (Xcode, iOS 27.1 SDK).
`xcodebuild … test` on one iPhone 17 Pro simulator (iOS 27.0): **28 tests in 5 suites passed**,
including the 6 new `ScreenMirroringTests`. Build output (`build/DD`) was deleted afterwards.

## The problem

Without Pro, church mode's TV casting was gated: the external display scene showed a Pro
card, and a paywall popped up over church mode. Mirroring, recording, iPhone Mirroring on
a Mac or a broadcast (Zoom, Teams) all show the phone as it is, and nothing marked them.

## 1. Mirroring without Pro: a Go Pro banner (`Features/ScreenMirroring.swift`)

- **Detection.** `ScreenMirroring` (in `AppServices`, in the environment) watches
  `UITraitCollection.sceneCaptureState` on the window scene. That's the iOS 17 replacement
  for `UIScreen.isCaptured`, which is deprecated and would warn. It registers on the
  **scene**, not a view, because church mode's full-screen cover takes the root out of the
  window. A connected external display also counts: without Pro it gets no window of its
  own, so iOS mirrors the phone (see 2).
- **Rule** (`ScreenMirroring.bannerRoute`): Pro never sees the banner. Otherwise an
  external display gives `external_display` and a capture gives `capture`. With neither,
  there's no banner.
- **Banner.** A small opaque capsule: the SDA logo in gold, **Advent Praise**, and *Go Pro
  for a clean worship display*. It is drawn in the app's own window, so it appears in the
  mirrored picture.
  - In the reader it sits in the bottom-trailing corner, above the Lectern, and stays up in
    focus mode.
  - In church mode it sits in the bottom-trailing corner, under the controls. The controls
    and the lyric's bottom padding move up by its height, so it **never covers the words**.
    It stays up when the controls auto-hide.
  - It never blanks or blocks anything.
- **Tap** (on the phone) opens the paywall with the new `ProFeature.mirroring`. Its lead
  reads: "Your screen is being mirrored. Pro shows a clean worship display on any TV or
  projector instead…". Analytics shows it as `feature: mirroring`.
- **Analytics:** `mirroring_detected` (`via`, `in_church_mode`) fires once per session.
  It's added to `ANALYTICS_PLAN.md`.
- **Removed:** the paywall that popped up by itself when a screen connected without Pro (in
  `ExternalDisplaySceneDelegate` and `ChurchModeView.onAppear`). With mirroring it would
  have been projected over the lyrics. The locked AirPlay button in church mode still opens
  the `airPlay` paywall.

## 2. Pro: a dedicated worship display (`Features/ExternalDisplay.swift`)

Church mode already had an external-display scene (`windowExternalDisplayNonInteractive`
through `AppDelegate`). It was **upgraded in place**, not duplicated.

- **Pro only.** `ExternalDisplaySceneDelegate` gives the scene a window only with Pro. It
  follows `store.isPro` with `withObservationTracking`: buying Pro while connected puts the
  display up straight away, and a refund takes it down. Without Pro there's no window, so
  iOS mirrors the phone and the banner shows.
- **Layout (`ExternalHymnView`)**, laid out for 1080 pt high and scaled to any screen:
  - **Ground:** the brand ground (`WorshipDisplayGround`), Stage lit from below with
    evergreen and a little gold.
  - **Header:** the hymn number in brass and the title across the top.
  - **Lyrics:** large, centred serif (84 pt on 1080 at the phone's default size). The
    phone's text-size buttons still scale it, and a long verse shrinks to fit. A chorus gets
    a CHORUS label in brass.
  - **Footer:** a rule with "VERSE 2 OF 4" and progress dots.
  - **Title card** between hymns (church mode closed): the logo, the hymnal, a big number
    and the title.
  - **Blank:** the ground and a faint logo.
  - The external scene is non-interactive, so there's no phone UI, status bar,
    notifications or controls.
- **The phone is the remote.** While the display is up, church mode's top row adds:
  - **Next hymn** (`forward.end.fill`): the next playlist or plan entry, or the next number.
    It's disabled at the end.
  - **Blank the screen** (`eye.slash`, prominent while blank). While blank, the phone dims
    its lyric and the card reads "Big screen blank".
  - Previous and next verse, the number pad and translation work as before. Any verse turn,
    hymn change or leaving church mode un-blanks.
- **Copy.**
  - Paywall line: "Clean worship display on any TV or projector" (was "Church mode with
    AirPlay casting").
  - AirPlay lead: "A clean worship display on any TV or projector, with your phone as the
    remote…".
  - The Pro card's thank-you line in More says the same.

## Screenshots (`build/shots/mirror/`, git-ignored)

| File | What |
|---|---|
| `01-reader-mirrored-free.png` | Reader, free, mirrored: banner above the Lectern |
| `02-church-mirrored-free.png` | Church mode, free, mirrored: banner under the controls, which move up |
| `04-church-pro-remote.png` | Church mode, Pro, display connected and mirroring forced: no banner; Next hymn and Blank in the top row; TV icon on the card |
| `05-tv-verse.png`, `05-tv-chorus.png`, `05-tv-title.png`, `05-tv-blank.png` | The worship display at 1920 × 1080 |
| `06-paywall-mirroring.png` | The paywall opened from the banner |
| `07-more-pro-card.png` | More's Pro card with the new line |

The simulator's I/O → External Displays menu can't be scripted, so these new DEBUG launch
arguments stand in for it:

- `-uiDebugMirroring YES`: counts the screen as captured.
- `-uiDebugExternalConnected YES`: behaves as if a display were connected (church mode's
  remote).
- `-uiDebugRenderExternal <prefix>`: writes the display's four states to PNGs with
  `ImageRenderer`.
- `-uiDebugExternal blank`: draws the blank display on the phone.
- `-uiDebugPaywall mirroring`: opens the mirroring paywall.

Note: this simulator holds a StoreKit test purchase, so use `-uiDebugFree YES` to see the
free path.

## Not verified / for Malcolm

- **On a device with a real AirPlay receiver or cable:**
  - Check that a free user's external display scene **with no window** really falls back
    to mirroring. That's Apple's documented behaviour, but I couldn't check it in the
    simulator.
  - Check that the Pro display appears, follows verses, blanks, and comes up when Pro is
    bought while connected.
  - Check that `sceneCaptureState` turns on for Control Centre Screen Mirroring, a screen
    recording and iPhone Mirroring.
- **Possible leak:** a sheet or the paywall over the reader covers the banner while it's
  open, and so would the What's New sheet. That's acceptable to me, but it's a gap if
  someone mirrors with a sheet left open.
- **No analytics for Blank or Next hymn.** Add events if you want usage numbers.
- **Not checked:** iPad, or iPhone in landscape.
