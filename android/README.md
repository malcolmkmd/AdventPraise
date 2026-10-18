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

Without a key the app runs with purchases off (the paywall offers Try again). Debug
builds log analytics to Logcat and send nothing; add `-Panalytics.debugSend=true` to send.

## Purchases (RevenueCat)

Same RevenueCat project and `pro` entitlement as iOS (`docs/revenuecat.md`). Products
to create in Play Console (I didn't create any):

| Product | Type | Details |
|---|---|---|
| `ap_pro_annual` | Subscription | Base plan `annual`: auto-renewing, 1 year, R199.99. Offer `free-trial`: 3-day free phase, new customers. RevenueCat ID `ap_pro_annual:annual` |

Then in RevenueCat: add the Play app (`com.mDev.AdventPraise`), upload the Play
service-account JSON, attach `ap_pro_annual:annual` to `pro` and to the `$rc_annual`
package of the default offering. Tips are not sold on Android yet.

## Analytics (PostHog)

EU host `https://eu.i.posthog.com`, the iOS project token, the iOS event names and
properties (`analytics/Analytics.kt`). Anonymous, no autocapture, no replay; "Share
anonymous usage" in More turns it off.

## First milestone

Working: the hymn list and search (number, title, words; accent- and
apostrophe-insensitive, as iOS), the reader (verses, choruses, "Chorus after every
verse", swipe for next/previous, tap to hide the chrome), translations (same number
in another hymnal), Theme and Text settings, the number pad, favourites, More, the
Terms and Privacy Policy, the paywall on RevenueCat (annual subscription with trial,
Restore, Manage subscription) and MIDI play/pause with five free plays.

Not yet: playlists, church mode and the worship display, sheet music, Memorise, the
pitch pipe, scripture and collections, verse-following in the player, tempo and
scrubbing, widgets, tips, What's New and the tour.
