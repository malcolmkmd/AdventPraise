# Google Play Console fill-in sheet: Advent Praise (Android)

Everything here was checked against the Android code on main (October 2026). The listing
text and graphics are in `metadata/android/<locale>/` (fastlane `supply` layout), so they can be
uploaded with `fastlane supply --metadata_path android/store/metadata/android` later, or pasted in by hand.

## The build

| Field | Value |
|---|---|
| applicationId | `com.mDev.AdventPraise` |
| versionName | `7.1` (matches iOS) |
| versionCode | `1` (first Play upload; raise it by 1 for every upload) |
| minSdk / targetSdk / compileSdk | 26 / **36** / 37 (Play needs target 36 for new apps since 31 Aug 2026) |
| Format | Android App Bundle, `./gradlew :app:bundleRelease` → `app/build/outputs/bundle/release/app-release.aab` |
| Signing | Signed with the **upload key**. Keystore on Malcolm's Mac at `~/Keys/adventpraise-upload.jks` (outside the repo), alias `upload`, RSA 2048, valid to 2056. Password in the macOS login Keychain, item `adventpraise-upload-keystore`. `~/.gradle/gradle.properties` names the file and alias; `app/build.gradle.kts` reads the password from the Keychain. Back the keystore and the password up somewhere safe: losing them means asking Google for an upload key reset. |
| Upload certificate SHA-1 | `FE:ED:BF:88:07:7D:43:00:5C:B2:49:68:16:6A:B7:8C:3B:E0:DA:02` |
| Upload certificate SHA-256 | `18:2C:14:84:6A:BD:C0:ED:35:75:15:60:F4:16:DF:05:2D:A8:86:1A:91:0B:AF:8E:18:05:AE:73:30:B2:AB:9F` |
| Play App Signing | Opt in (default for new apps). Google holds the app signing key, and we keep only the upload key. |
| Billing permission | `com.android.vending.BILLING` is in the merged release manifest (added by RevenueCat's Play Billing dependency). |
| RevenueCat key | `goog_zHpZXDfruZmXDBETYMkhlxDEpoJ` from `android/local.properties` (`revenuecat.androidKey`), public by design |

## Create app

| Field | Answer |
|---|---|
| App name | **Advent Praise Hymnal** (`title.txt`, 20 of 30). Alternatives: `Advent Praise` (the iOS name), `Advent Praise: Hymns & Piano` |
| Default language | English (United States) – en-US. The same text is also provided as English (South Africa) – en-ZA. |
| App or game | App |
| Free or paid | Free (with in-app purchases) |
| Declarations | Developer Program Policies: yes. US export laws: yes. |

## Store settings

| Field | Answer |
|---|---|
| Category | **Music & Audio** (recommended). It matches iOS (Music), the piano and the sheet music, and the category is less crowded. 7 of the 28 SDA hymnal competitors sampled are in Music & Audio (including the biggest Christ In Song app) and 20 in Books & Reference. Second choice: Books & Reference. |
| Tags (up to 5) | Religion & spirituality / Christianity (whichever Play offers), Music, Lyrics, Sheet music, Reference |
| Email | hi@malcolmk.com |
| Website | https://malcolmk.com |
| Phone | leave empty |
| Privacy policy URL | https://malcolmk.com/adventpraise/privacy (live) |
| Terms (in the description) | https://malcolmk.com/adventpraise/terms |
| External marketing | allow (default) |

## Main store listing

| Asset | File | Spec |
|---|---|---|
| App name | `metadata/android/en-US/title.txt` | 20 / 30 chars |
| Short description | `short_description.txt` | 77 / 80 |
| Full description | `full_description.txt` | ~3,330 / 4,000. Plain text, no rankings, prices or emoji. Includes the hymn ownership note, the Terms and the Privacy Policy |
| App icon | `images/icon.png` | 512 × 512, 32-bit PNG (the app's icon) |
| Feature graphic | `images/featureGraphic.png` | 1024 × 500, 24-bit PNG |
| Phone screenshots | `images/phoneScreenshots/01…08` | 8 × 1080 × 1920 (9:16), 24-bit PNG, real Android emulator captures |
| Marketing screenshots | `phoneScreenshots-framed/en-US/01…08` | 1080 × 1920 with captions. Optional: upload these **instead of** the raw ones if you prefer the captioned look (Play allows either, up to 8). Kept outside `metadata/` so supply doesn't upload both. |
| Tablet screenshots | none | The Android app has no tablet layout yet (it's the phone layout, stretched). Skip the 7-inch and 10-inch tablet slots. Play doesn't require them, but the app won't be badged "designed for tablets". |
| Release notes (versionCode 1) | `changelogs/1.txt` | 343 / 500 |

## App content

### Privacy policy
https://malcolmk.com/adventpraise/privacy

### Ads
**No, my app does not contain ads.** There's no ad SDK in the dependencies (Compose, AndroidX, Glance, Play services Cast, MediaRouter, AndroidSVG, RevenueCat, PostHog). The "Go Pro" banner on a mirrored screen is the app's own upsell, not an ad.

### App access
**All or some functionality is restricted** → add instructions:

> No account or login is needed. Everything is open except Advent Praise Pro (piano accompaniment after 5 free plays, the full sheet music page, the worship display on a TV, church mode controls in notifications, the pitch pipe). Pro is an annual Google Play subscription with a 3-day free trial; you can start the trial with a licence-test account from the paywall (More → Advent Praise Pro, or tap ▶ on any hymn more than 5 times). Church mode: open the tray at the bottom of the reader → Church mode. Sheet music: the music button next to the globe at the top right of a hymn that has notes (for example Christ In Song 1).

(Add the reviewer's Gmail as a licence tester in Play Console → Settings → License testing so they can subscribe without being charged.)

### Content rating (IARC questionnaire)
- Category: **Reference, News, or Educational** (or "All other app types" if that's what the form offers)
- Violence, fear, sexuality, nudity, language, controlled substances, crude humour, gambling: **No** to all
- Users can interact or exchange content: **No** (no chat, accounts or user posts)
- Shares the user's current location with others: **No**
- Lets users buy digital goods: **Yes** (subscription and tips)
- Unrestricted internet or web browser: **No** (it opens a few links in the browser: Bible.com verses, the Play subscription page and the Play listing)
- Expected result: Everyone / PEGI 3 / USK 0 / IARC 3+

### Target audience and content
- Target age groups: **13–15, 16–17, 18 and over**. Don't tick under-13 groups: that puts the app under the Families policy, and PostHog and RevenueCat would then have to be Families-certified SDKs.
- Appeals to children: **No** (a hymnal for church and home, not designed for children)

### News app
No.

### COVID-19 contact tracing and status apps
No.

### Data safety
Is any data collected or shared? **Yes.** Is all data encrypted in transit? **Yes** (HTTPS to PostHog EU and RevenueCat). Can users request deletion? **No account is created**, so choose "No"/not applicable. Analytics can be turned off in More → Share anonymous usage (this resets the anonymous ID), and nothing is linked to a person.

Data types (none is **shared**: PostHog and RevenueCat are service providers acting for us, which Play doesn't count as sharing):

| Data type | Collected | Optional? | Purposes | Notes from the code |
|---|---|---|---|---|
| App activity → App interactions | Yes | Yes (switch in More, on by default) | Analytics | PostHog EU (`eu.i.posthog.com`): anonymous events (hymn opened, hymnal, settings changed, church mode, player…). No person profiles, autocapture, session replay or GeoIP. Search words are never sent, only `query_length` and `result_count`. |
| App info and performance → Diagnostics | Yes | Yes | Analytics | Non-fatal errors as the `error_occurred` event, and app or OS version, device model and locale as event properties. No crash SDK. |
| Device or other IDs | Yes | No | Analytics, App functionality | PostHog's random anonymous ID (reset when analytics is switched off) and RevenueCat's anonymous app user ID ($RCAnonymousID), used to restore purchases. Not the advertising ID. |
| Financial info → Purchase history | Yes | No | App functionality | RevenueCat receives the Google Play purchase token and receipt to grant the `pro` entitlement. The app never sees card details: Google Play handles payment. |
| Location, personal info, messages, photos, audio, files, contacts, calendar, health, web history | No | | | |

Not counted as collection: Google Cast sends the hymn text and timing to the Advent Praise web receiver on the user's TV (app content, no user data). Favourites, playlists, settings and the free-play count stay on the device; Android Auto Backup may copy settings to the user's own Google Drive backup, which Play doesn't count as collection by the developer. There's no feature-vote board in the Android build (no board key is configured), so it makes no calls to Features.Vote.

### Government apps
No.

### Financial features
None (the app offers no financial services).

### Health
No health features.

## Monetise → Products

### Subscription (required)
| Field | Value |
|---|---|
| Product ID | `ap_pro_annual` |
| Name | Advent Praise Pro |
| Benefits (up to 4) | Unlimited piano accompaniment · Sheet music to read and play from · Worship display on a TV or projector · Church mode controls and the pitch pipe |
| Base plan ID | `annual` – auto-renewing, billing period 1 year, grace period default, resubscribe allowed |
| Price | ZAR 199.99 (South Africa). Let Play convert the other countries from it, or set USD 9.99 to match iOS. |
| Offer | ID `free-trial`, eligibility **New customer acquisition** (never had this subscription), phase: **Free trial, 3 days** |
| RevenueCat | Add the Play app (`com.mDev.AdventPraise`) to project "Advent Praise", upload the Play service-account JSON, import `ap_pro_annual:annual`, attach it to the `pro` entitlement and to the `$rc_annual` package of the `default` offering. |

### In-app products (one-time, consumable): tips
Same IDs as iOS (`PurchaseConfig.TIPS`). They unlock nothing. The Support screen sells them with RevenueCat by product ID.

| Product ID | Name | Description | Suggested ZAR price (preview store) |
|---|---|---|---|
| `ap_tip_amen` | Amen | A quiet thank you | R19.99 |
| `ap_tip_hallelujah` | Hallelujah | Keeps the hymns ringing | R49.99 |
| `ap_tip_hosanna` | Hosanna | Carries Advent Praise further | R99.99 |

Play's newer one-time products need a purchase option; use "Buy" with the price above. Mark them consumable in RevenueCat (RevenueCat consumes them).

### Lifetime
**Not needed on Android.** `ap_pro_lifetime` and `ap_midi_unlock` were only sold on iOS 7.0.x and aren't on sale now. iOS buyers keep Pro through the `pro` entitlement wherever they sign in to the same RevenueCat customer. Android has no restore across stores without a login, so don't create them.

## Testing and release
1. Internal testing track → upload `app-release.aab` (versionCode 1), add testers (email list).
2. Licence testing: add the testers' Gmail addresses so trial and subscription purchases are free.
3. With a new personal developer account, Play requires a **closed test with at least 12 testers for 14 days** before production access. Organisation accounts (MDEVSA (Pty) Ltd with a D-U-N-S number) are exempt. Check which kind of account Rolo opened.

## How the images were made
- Screenshots: the debug build on a Pixel 8 emulator (API 35, Google Play image) with its display set to 1080 × 1920 at 420 dpi, opened in each state with the debug launch extras (`DebugLaunch.kt`: `uiDebugHymn`, `uiDebugMenu translation`, `uiDebugSheet sheetMusic`, `uiDebugChurch`, `uiDebugPaywall`…), with the status bar in demo mode (9:41). Pro screens use `uiDebugPro` and the paywall uses the preview store's prices. Script: `tools/store-shots.sh`.
- The icon is the app icon (`AppIcon.png`, the same art as the adaptive icon) at 512 px. The feature graphic is built in code by `tools/make_art.py` (Pillow): the real icon lockup, Inter, the Vesper evergreen and brass, and a real reader screenshot. The captioned frames come from `tools/make_shots.py` (Noto Serif and Inter).
