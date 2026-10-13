# App Store release readiness — Advent Praise 7.0 (1)

Branch `store`. Checked 2026-10-11 with Xcode 27.1 (27A9269), iPhoneOS 27.1 SDK.

## Archive

| Command | Result |
|---|---|
| `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -configuration Release -destination 'generic/platform=iOS' -archivePath build/AdventPraise.xcarchive -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO archive` | **ARCHIVE SUCCEEDED**, with no warnings or errors in app code |
| The same command, signed (no `CODE_SIGNING_ALLOWED=NO`) | Fails at signing only: *"No profiles for 'com.mDev.Advent-Praise' were found … pass -allowProvisioningUpdates"*. There are no profiles on this machine. I didn't pass `-allowProvisioningUpdates`, because that creates profiles and registers the App ID on the team account. |

So everything up to signing works. To produce an uploadable archive, sign in to team
4729Z4LTF4 in Xcode → Settings → Accounts, then either use Product → Archive, or add
`-allowProvisioningUpdates` to the command above and drop `CODE_SIGNING_ALLOWED=NO`.
`build/` is git-ignored.

## Configuration checked (in the archived Info.plist and bundle)

| Item | Value | OK? |
|---|---|---|
| Bundle ID | `com.mDev.Advent-Praise` | ⚠️ **Must equal the live app's bundle ID** (id1015021132). I couldn't confirm it from here because network access was denied. Check App Store Connect → App Information. If it differs, the upload goes to a different app and existing buyers lose their purchases. |
| Version / build | `CFBundleShortVersionString 7.0`, `CFBundleVersion 1` | ✅ Higher than the live 6.3; bump `CURRENT_PROJECT_VERSION` for each re-upload |
| Deployment target | `MinimumOSVersion 17.0` (iOS 17+) | ✅ Meets App Intents (16+), StoreKit 2 (15+) and PostHog 3 (13+). ⚠️ Users of 6.3 on iOS 15–16 stop getting updates. Check App Analytics → OS versions before release. |
| Devices | `UIDeviceFamily [1, 2]`, arm64 | ✅ iPhone + iPad. iPad supports all 4 orientations, so `UIRequiresFullScreen` isn't needed |
| Display name / category | "Advent Praise", `public.app-category.music` | ✅ |
| Encryption | `ITSAppUsesNonExemptEncryption = NO` | ✅ HTTPS only, exempt. No export compliance question at upload |
| Launch screen | `UILaunchScreen {}` (generated) | ✅ |
| Usage descriptions | none | ✅ No camera, photos, location, microphone, contacts, tracking or notification APIs are used. The audio session is playback-only |
| Background modes | none | ✅ (MIDI playback is foreground only, and no MIDI ships) |
| Scenes | `UIApplicationSupportsMultipleScenes = YES` (Xcode default) | ⚠️ Works, but every window shares `AppServices.shared`, so two iPad windows mirror each other. That's acceptable for 7.0; turn it off if anyone finds it confusing |
| **App icon** | `AppIcon` has no image, and there's no `CFBundleIcons`/`CFBundleIconName` | ❌ **Blocker.** Upload validation rejects the build. Add a 1024×1024 PNG (no alpha) |
| Privacy manifest | in the bundle root, plus the PostHog and PLCrashReporter bundle manifests | ✅ (updated, see below) |
| App Intents | `Metadata.appintents` is in the bundle (`extract.actionsdata`, `nlu`) | ✅ 4 intents, 4 App Shortcuts |
| Packages | `Package.resolved`: PostHog 3.92.0, features-vote-sdk (pinned revision). No RevenueCat: purchases go straight through StoreKit 2 | ✅ pinned and committed |

### Entitlements

There's no `.entitlements` file and no `CODE_SIGN_ENTITLEMENTS`. **That is correct, and none is needed:**

- **In-App Purchase**: a capability that is on by default for every explicit App ID.
  It has no entitlement key. In App Store Connect, check Certificates, Identifiers &
  Profiles → `com.mDev.Advent-Praise` → In-App Purchase ✓.
- **App Intents / App Shortcuts**: need no entitlement. Only the legacy SiriKit
  (`INExtension`) needs `com.apple.developer.siri`, and the app doesn't use it. Siri
  phrases work from `AppShortcutsProvider` alone.
- No iCloud, push, associated domains or App Groups are used.

## Fixed in this branch

1. **Privacy policy inside the app** (Guideline 5.1.1(i) requires one). More → About →
   *Privacy & credits* and the paywall's Privacy Policy link open the native
   `PrivacyPolicyView` (see `MORE_STATUS.md`).
2. **"Rate on the App Store" did nothing most of the time.** It called `requestReview()`,
   which Apple rate-limits (3 times a year) and says shouldn't be triggered from a
   button. It now opens `…/id1015021132?action=write-review`. The unused `StoreKit`
   import is removed.
3. **No IP geolocation in analytics.** Added `config.disableGeoIp = true` in
   `Analytics.swift`. Without it, PostHog infers a coarse location from the IP address,
   and the label would have to declare Location.
4. **The privacy manifest under-declared what is collected.** The app's
   `PrivacyInfo.xcprivacy` now also declares:
   - **Other Usage Data** (Analytics, not linked). PostHog adds app/OS version, device
     model, locale, timezone and screen size to every event, and its own SDK manifest
     declares this type.
   - (Device ID and Purchase History were declared for RevenueCat. RevenueCat has since
     been removed, so neither is collected any more; StoreKit purchases stay between the
     user and Apple. See `privacy-label.md`.)
5. **Typo in the Portuguese hymnal title** shown in the Hymnals panel: it read
   "Hinàrio … Do Sétiomo Dia". Corrected to "Hinário Adventista do Sétimo Dia" in
   `hymnals.json` and `pt.json`, and in `Tools/convert_hymnals.py` (`TITLE_NAMES`) so a
   regeneration keeps the fix. (Português no longer ships in 7.0; the fix stays in the
   converter for `--all`.)

## Docs in this folder

| File | Contents |
|---|---|
| `listing.md` | Name, subtitle, promo text, description, keywords, What's New, category, age rating, IAP display names. Character and byte counts are checked |
| `privacy-label.md` | App Privacy answers for each data type, with the reason for each "No" |
| `review-notes.md` | Notes to paste into App Review, a checklist to finish before submitting, content-rights prep, rejection risks |
| `screenshots.md` | Required sizes, capture rules, a shot list for iPhone (6) and iPad (5) |
| `urls-checklist.md` | Support and privacy URLs, what the policy must say, final checks |

## Still to do (not possible from code)

Blockers, in order:

1. **App icon.** Add the 1024 px PNG to `Resources/Assets.xcassets/AppIcon.appiconset`.
2. **In-app purchases in App Store Connect.** Create the four products with exactly the
   IDs in `Store/PurchaseConfig.swift`: `ap_pro_lifetime` (non-consumable "Advent Praise
   Pro", R199.99 / $9.99), and the consumable tips `ap_tip_amen` (R19.99 / $0.99),
   `ap_tip_hallelujah` (R49.99 / $2.99), `ap_tip_hosanna` (R99.99 / $4.99). Sign the Paid
   Apps agreement, and submit the IAPs with the build. Without these, Pro can't be bought
   or restored, and the app is rejected under 2.1. There is no SDK key or server to set up.
3. **Confirm the bundle ID** matches id1015021132 (see the table above).
4. **Publish the privacy policy and support pages** for App Store Connect: a public
   copy of the in-app policy, and a support page with no personal email. See
   `urls-checklist.md`.
5. **PostHog token** in `Analytics.projectToken`. Optional: with no token, analytics is
   off. Also turn on "Discard client IP data" in the PostHog project.
6. **Content rights documentation**, especially for the SDA Hymnal (1985). See
   `review-notes.md`.

Decisions for Malcolm:

- **Play Hymn shortcut.** It's registered as an App Shortcut ("Play hymn in Advent
  Praise"), but no accompaniment ships, so it always says playback isn't available.
  The review notes explain this. The safer option is to remove `PlayHymnIntent` from
  `HymnShortcuts.appShortcuts`, and the intent, until MIDI ships. I didn't change it
  because it's a product decision.
- **What's New copy** says "with your purchases restored". That only holds once blocker
  2 is done. Every hymnal is free now; *Restore purchases* (`AppStore.sync()`) still
  re-syncs the 6.x hymnal purchases and Pro. The App Store listing copy is worded to
  cover that case.
- **Category**: Music is set in the build. Keep whatever the live app uses in App Store
  Connect.

Not done, as briefed: no tests were written or run. Nothing was pushed.
