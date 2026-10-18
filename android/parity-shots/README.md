# Parity shots: iOS beside Android

Each composite puts the iOS simulator (iPhone 17 Pro, iOS 26) on the left and the Android
emulator (Pixel 8, API 35) on the right, both scaled to the same height, in the same debug
state, opened with the same launch arguments (iOS `-uiDebug…`, Android intent extras of the
same names: see `app/src/debug/java/com/mDev/AdventPraise/DebugLaunch.kt`). Raw captures are in
[`ios/`](ios) and [`android/`](android); `drive/` holds shots taken while driving the emulator.

Fonts differ by platform and are not counted as differences: SF Pro / New York / Avenir Next on
iOS, Roboto / Noto Serif on Android (SF sets about 8 % wider, so sans text wraps a little later on
Android). So are the status bar, the gesture bar, Material's switches, and iOS 26's glass
sheet chrome (inset sheet corners, the Done capsule).

| Screen | Light | Dark | State |
|---|---|---|---|
| Hymn list (library panel) | [list-light](list-light.png) | [list-dark](list-dark.png) | done |
| Reader | [reader-light](reader-light.png) | [reader-dark](reader-dark.png) | done |
| Globe menu (Translation) | [globe-bar-light](globe-bar-light.png) | [globe-bar-dark](globe-bar-dark.png) | done |
| Sheet music, Page | [sheet-page-light](sheet-page-light.png) | [sheet-page-dark](sheet-page-dark.png) | done |
| Sheet music, System | [sheet-system-light](sheet-system-light.png) | [sheet-system-dark](sheet-system-dark.png) | done |
| Paywall | [paywall-light](paywall-light.png) | [paywall-dark](paywall-dark.png) | partial: the iOS reference is the offline state (simctl launches without the StoreKit file), Android is priced by the preview store (R199.99/year, 3-day trial) |
| More | [more-light](more-light.png) | [more-dark](more-dark.png) | done |
| Church mode | [church-light](church-light.png) | [church-dark](church-dark.png) | partial: Android has one Cast button where iOS has AirPlay and Show on a TV |
| Number pad | [numpad-light](numpad-light.png) | [numpad-dark](numpad-dark.png) | done |
| Search | [android only](android/search-light.png) | [android only](android/search-dark.png) | no iOS launch argument opens search |
| About this hymn | [about-hymn-light](about-hymn-light.png) | [about-hymn-dark](about-hymn-dark.png) | done (Android's card is near-opaque: no live blur) |
| Memorise | [memorise-light](memorise-light.png) | [memorise-dark](memorise-dark.png) | done (the hidden words are random) |
| Collections | [collections-light](collections-light.png) | [collections-dark](collections-dark.png) | done |
| Support | [support-light](support-light.png) | [support-dark](support-dark.png) | done (iOS shows USD prices from the simulator's store, Android the preview store's rand) |
| Terms (hymn content) | [terms-light](terms-light.png) | [terms-dark](terms-dark.png) | done |
| Pitch pipe | [pitch-light](pitch-light.png) | [pitch-dark](pitch-dark.png) | done |
| Hymn tray | [hymn-tray-light](hymn-tray-light.png) | [hymn-tray-dark](hymn-tray-dark.png) | done |
| Tour, step 1 | [tour-1-light](tour-1-light.png) | [tour-1-dark](tour-1-dark.png) | done |
| What's New | [whats-new-light](whats-new-light.png) | [whats-new-dark](whats-new-dark.png) | done (Ask Siri is App shortcuts on Android, by decision) |
| Splash, mid-reveal | [splash-light](splash-light.png) | [splash-dark](splash-dark.png) | done (the frame caught differs a little; Android's logo is 140 dp, the widest the system splash allows) |
| Playlist editor | – | – | no launch argument on either platform; covered by the Roborazzi golden `app/src/test/screenshots/playlist_editor_*.png` |

## Driven on the emulator

- Page swipe with the edge arrow, hymn 1 → 2: [drive/swipe-mid](drive/swipe-mid.png)
- Globe menu opened by tapping the globe: [drive/globe](drive/globe.png)
- Sheet music Page ↔ System, double-tap zoom: [drive/zoom](drive/zoom.png) (pinch can't be sent with `adb input`)
- MIDI playing in sheet music, the measure, note and syllable marks moving and the system turning
  (AudioTrack `started`, media session `PLAYING`, no crash): [drive/play](drive/play.png)
- Church mode Next / Previous: verse 1 → chorus → verse 2 → back to the chorus (read from the
  accessibility tree): [drive/church-verse](drive/church-verse.png)
- Hymn of the Day widget added from the launcher's widget picker: [drive/widget-home](drive/widget-home.png)

## Re-capture

```sh
# Android: emulator running (emulator -avd Pixel_8 -no-snapshot-save -no-boot-anim), debug APK built
cd android && ./gradlew assembleDebug
./parity-shots/tools/android-shots.sh                 # every shot, light and dark
ONLY="reader paywall" MODES=light ./parity-shots/tools/android-shots.sh

# iOS: a private booted simulator and a DEBUG build of the app
IOS_UDID=<udid> IOS_APP="<DerivedData>/Build/Products/Debug-iphonesimulator/Advent Praise.app" \
  ./parity-shots/tools/ios-shots.sh

# Composites (macOS, AppKit only): every name found in both folders
swiftc -O parity-shots/tools/compose.swift -o /tmp/compose
/tmp/compose --all parity-shots/ios parity-shots/android parity-shots
```

The Android script sets the demo status bar (09:41, full battery), turns off the immersive-mode
notice, grants the notification permission, force-stops the app before each shot and switches
`cmd uimode night yes|no`. One debug launch by hand:

```sh
adb shell am start -S -n com.mDev.AdventPraise/.MainActivity \
  --es uiDebugSheet sheetMusic --es sheetMusic.viewMode system --ez uiDebugPro true --ei uiDebugHymn 1
```
