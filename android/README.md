# Advent Praise Android

Kotlin, Jetpack Compose and Material 3; min SDK 26; package `com.mDev.AdventPraise`.
The iOS app is the source of truth: this app mirrors its screens (the reader, the
Lectern at the bottom, the reader menu at the top, More and the Pro paywall), its
Vesper design tokens and its behaviour.

## Shared data, not copied

`app/build.gradle.kts` adds the iOS app's folders to the APK's assets:

| Folder | What |
|---|---|
| `AdventPraise/Resources/Hymnals` | `hymnals.json` and one `<key>.json` per hymnal (translations) |
| `AdventPraise/Resources/Midi` | the MIDI accompaniment and `midi-manifest.json` |
| `AdventPraise/Resources/Extras` | `sdah_tunes.json` (which SDA Hymnal hymns share a Christ In Song tune, and so its MIDI) |
| `legal` | shared legal text (`hymn-content-terms.md` in the Terms of Use) |

A hymnal added on iOS (a new entry in `hymnals.json` plus its file) shows up in the
Android translation picker with no code change. The SDA Hymnal (1985) has its own
numbering: as on iOS, switching to or from it keeps the same hymn through the English
hymns' "SDAH n" cross-references, and last hymn and recents are kept per numbering.

## Build

```sh
cd android
./gradlew assembleDebug        # app/build/outputs/apk/debug/app-debug.apk
./gradlew testDebugUnitTest    # unit tests and the JVM screenshot tests
./gradlew recordRoborazziDebug # re-record app/src/test/screenshots (Robolectric, no emulator)
./gradlew verifyRoborazziDebug # compare against them
```

The piano SoundFont (`shared-audio/piano.sf2`) ships as an asset; sheet music
comes from `AdventPraise/Resources/SheetMusic`. Without `revenuecat.androidKey` in
`local.properties` (or `-Prevenuecat.androidKey`), builds use the app's public
RevenueCat key. `cast.receiverAppId` sets the Google Cast receiver.

`local.properties` (not committed) needs `sdk.dir`, and for purchases:

```properties
revenuecat.androidKey=goog_xxxxxxxxxxxxxxxx
```

The key falls back to `-Prevenuecat.androidKey`, then the public SDK key built into
`app/build.gradle.kts`. Debug builds log analytics to Logcat and send nothing; add `-Panalytics.debugSend=true` to send.

## Purchases (RevenueCat)

Same RevenueCat project and `pro` entitlement as iOS (`docs/revenuecat.md`). Products
to create in Play Console (I didn't create any):

| Product | Type | Details |
|---|---|---|
| `ap_pro_annual` | Subscription | Base plan `annual`: auto-renewing, 1 year, R199.99. Offer `free-trial`: 3-day free phase, new customers. RevenueCat ID `ap_pro_annual:annual` |

Then in RevenueCat: add the Play app (`com.mDev.AdventPraise`), upload the Play
service-account JSON, attach `ap_pro_annual:annual` to `pro` and to the `$rc_annual`
package of the default offering. The three tips (`ap_tip_amen`, `ap_tip_hallelujah`,
`ap_tip_hosanna`) are one-time consumables sold by product ID on the Support screen; see
`store/PLAY_CONSOLE.md`.

## Analytics (PostHog)

EU host `https://eu.i.posthog.com`, the iOS project token, the iOS event names and
properties (`analytics/Analytics.kt`). Anonymous, no autocapture, no replay; "Share
anonymous usage" in More turns it off.

## Parity with iOS

Every iOS screen and flow is ported: the hymn list, search and number pad; the reader with
page swipe, the globe menu and the sheet music button; sheet music (Page | System, pinch,
MIDI sync); the SoundFont piano player (`shared-audio/piano.sf2`, also used by the TV);
favourites, playlists and church mode; the worship display on a second display
(`Presentation`) or a Chromecast (`cast/`, receiver in `cast-receiver/`); Collections,
Memorise, scripture, the service planner and the pitch pipe; Hymn of the Day and Church
Remote widgets and the church notification; More, the paywall, Support tips, Terms,
About, the tour and What's New.

Side-by-side iOS / Android shots and how to re-capture them: `parity-shots/README.md`.
Debug builds take the iOS launch arguments as intent extras, e.g.
`adb shell am start -n com.mDev.AdventPraise/.MainActivity --es uiDebugSheet sheetMusic --ez uiDebugPro true`.

## Google Cast

Set `cast.receiverAppId=XXXXXXXX` in `local.properties` (or `-Pcast.receiverAppId`); without
it the Cast output is off. Deploying the receiver, registering it in the Cast console and the
on-TV test script: `cast-receiver/README.md`.

## Release (Google Play)

`./gradlew :app:bundleRelease` writes `app/build/outputs/bundle/release/app-release.aab`, signed
with the Play upload key when one is set up (otherwise unsigned). Nothing about the key is in the
repo: `~/.gradle/gradle.properties` (or `local.properties`) names it, and the password comes from
the macOS login Keychain item `adventpraise-upload-keystore` unless a password property is set.

```properties
adventpraise.upload.storeFile=/Users/<you>/Keys/adventpraise-upload.jks
adventpraise.upload.keyAlias=upload
# optional, instead of the Keychain:
# adventpraise.upload.storePassword=…
# adventpraise.upload.keyPassword=…
```

Store listing, graphics, screenshots and the Play Console fill-in sheet: `store/` (fastlane
supply layout, `store/PLAY_CONSOLE.md`).
