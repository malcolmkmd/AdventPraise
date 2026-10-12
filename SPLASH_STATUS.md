# Splash status

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds with no warnings. Checked on an iPhone 17 Pro simulator (iOS 27.0), in light and dark, with Reduce Motion on and off.

## Logo: which file was used

**No SDA logo exists anywhere in this repo's git history.** Everything was searched: `git log --all` over every path ever committed, including the old `AdventPraises/` app and `AdventPraisesKit/`. The only image ever committed is `AdventPraise/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (blob `6e4aaf1`), the gold ring around a Didone "AP" on evergreen. The legacy asset catalogs only ever held AccentColor and an empty AppIcon set. The legacy app's own repository isn't reachable from this checkout.

So the splash uses **the app icon's mark**, rebuilt as vectors:

- `Tools/make_splash_logo.swift` draws it with CoreGraphics on a 160 × 160 pt canvas. The ring is a 5 pt stroke; "AP" is Didot Bold turned into glyph outlines, so no font ships. To regenerate: `xcrun swift Tools/make_splash_logo.swift AdventPraise/Resources/Assets.xcassets`.
- `SplashRing.imageset/SplashRing.pdf` and `SplashMonogram.imageset/SplashMonogram.pdf`: vector template images, used in the app.
- `LaunchLogo.imageset/LaunchLogo.pdf` and `LaunchLogo-dark.pdf`: coloured, vector, used by the launch screen.
- `LaunchBackground.colorset`: the launch ground.

**To use the real SDA logo instead:** replace the two template PDFs with the same 160-pt canvas, and redraw LaunchLogo from them. If the new mark isn't round, `SplashView`'s hole needs to follow its outline; it is a circle today because the ring's silhouette is a disc.

## Colours (DS tokens)

| | Ground | Ring | Letters |
|---|---|---|---|
| Light | `evergreen` #1F7466 | `brassOnDark` #D4A853 | paper #F7F4EE (as on the icon) |
| Dark | `stage` #0E1110 | `brassOnDark` #D4A853 | `evergreenOnDark` #5FB8A6 |

`SplashView.Palette` holds the same values as the launch assets. Change both together.

## Sequence

1. **Launch screen** (`UILaunchScreen` in `AdventPraise-Info.plist`): `LaunchBackground` with `LaunchLogo` centred in the full screen (`UIImageRespectsSafeAreaInsets` = NO).
2. **SplashView** (`AdventPraise/App/SplashView.swift`): overlays `RootView` through `.splashReveal()` in `AdventPraiseApp`. Its first frame is the launch frame, at the same size and centre, and screenshots show no change in position. After a 0.15 s hold the ring dips to 0.88, then grows on a critically damped spring (0.75 s, bounce 0) until its inner edge clears the screen's corners. The ground is an even-odd shape with a hole the size of the ring, so the ring is the mask and the app shows through it. The letters and the disc behind them fade over 0.22 s to open the window, and the app settles from 1.06× to 1×. The whole thing takes about a second. The overlay is hidden from VoiceOver and is removed when the reveal ends. `RootView` keeps its identity, because only a `scaleEffect` and an environment value are added around it.
3. **Reduce Motion:** no scaling. The splash cross-fades out over 0.4 s.
4. **What's New:** `WhatsNewPresenter` reads `\.splashPhase`. It waits until the splash has finished, pauses 1.75 s, then presents. It still shows once per version, on the same `whatsNew.lastSeenVersion` key. Where there's no splash (previews, `-uiDebugNoSplash`) it shows straight away, as before.

## Debug launch arguments

- `-uiDebugNoSplash YES`: no splash.
- `-uiDebugSplashSpeed 0.03`: plays the reveal about 33× slower, so screenshots can catch frames.

## Files touched

`AdventPraise-Info.plist`, `AdventPraiseApp.swift` (one modifier), `DebugLaunch.swift`, `WhatsNewSheet.swift` (show-once presenter only), and the new `SplashView.swift`, assets and `Tools/make_splash_logo.swift`. The reader header and the bottom action bar weren't touched.

## Checked on the simulator

- Light: the launch frame and the splash's first frame have the same geometry. Mid-reveal, the gold band sweeps out over the paper reader. What's New rises after the pause.
- Dark (black surface): gold ring and evergreen letters on the Stage, with the reader revealed through the ring.
- Reduce Motion: the reader fades in under a static mark.

## Open

- In simulator screenshots, the system launch snapshot looks a little more saturated than the app's first frame. Setting the colorset to Display P3 values didn't change the screenshot at all, which suggests a capture artefact rather than a wrong value. Check the hand-off by eye on a device.
- In a Debug cold start the system launch screen stays up about 2 s before the app's first frame. Release builds should be much quicker.
- iPad: the layout is size-independent (the cover scale comes from the window diagonal) but wasn't checked on an iPad simulator. Each new iPad window plays its own splash.
