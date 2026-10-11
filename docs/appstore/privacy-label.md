# App Privacy ("nutrition label") answers — Advent Praise 7.0

App Store Connect → App Privacy. These answers match:

- `AdventPraise/Resources/PrivacyInfo.xcprivacy` (the app's own manifest),
- the manifests bundled by the SDKs (`PostHog_PostHog.bundle`, `PostHog_PHPLCrashReporter.bundle`,
  `RevenueCat_RevenueCat.bundle`; checked in the 7.0 archive),
- what the code actually sends (`Services/Analytics.swift`, `Store/PurchaseStore.swift`).

After archiving, check **Xcode → Organizer → archive → Generate Privacy Report**. That
PDF merges every manifest. The answers below explain the one line in it you should
*not* copy (crash data).

## Do you or your third-party partners collect data from this app?

**Yes.**

## Data types

| Category → type | Collected? | Purpose | Linked to user? | Tracking? | Source |
|---|---|---|---|---|---|
| Usage Data → **Product Interaction** | Yes | Analytics | No | No | PostHog events: `hymn_opened`, `search_used`, `church_mode_started`… (full list in `AnalyticsEvent`) |
| Usage Data → **Other Usage Data** | Yes | Analytics | No | No | PostHog adds app version/build, OS version, device model (e.g. "iPhone", not the user's device name), locale, timezone, screen size, wifi/cellular to every event |
| Purchases → **Purchase History** | Yes | App Functionality | No | No | RevenueCat syncs App Store transactions to decide which hymnals are owned |
| Identifiers → **Device ID** | Yes | App Functionality | No | No | RevenueCat sends the IDFV (`UIDevice.identifierForVendor`) as `X-Apple-Device-Identifier` on every request (`purchases-ios` `HTTPClient.swift`) |
| Everything else | No | | | | |

Select **only** these four data types. For each, answer:

- *Used for tracking?* **No**
- *Linked to the user's identity?* **No**
- *Purposes:* Product Interaction → Analytics; Other Usage Data → Analytics; Purchase History → App Functionality; Device ID → App Functionality

Resulting label: **Data Not Linked to You: Usage Data, Purchases, Identifiers.** No
"Data Used to Track You" section.

## Why each "No" is true (keep this if the code changes)

- **Not linked.** Analytics is anonymous: `personProfiles = .never`, `identify` is never
  called, and `setDefaultPersonProperties = false`. PostHog's distinct ID is a random UUID
  stored on the device. RevenueCat uses its own anonymous `$RCAnonymousID`, because
  `Purchases.logIn` is never called. Neither SDK receives a name, email, account ID or
  advertising identifier, and the two IDs are never joined. **If you ever call
  `PostHogSDK.identify` or `Purchases.logIn`, change the answer to "Linked" and add
  Identifiers → User ID.**
- **Not tracking.** No IDFA, no `AppTrackingTransparency`, no data brokers, and no
  combining with other companies' data. `NSPrivacyTracking` is false in every manifest.
- **No Location.** PostHog normally works out a coarse location from the IP address.
  7.0 sets `config.disableGeoIp = true` (`Analytics.swift`), so it doesn't. As a second
  safeguard, turn on **Project settings → "Discard client IP data"** in the PostHog
  project.
- **No Purchase amounts in analytics.** `purchase_completed` only carries the hymnal key.
  Prices are not sent.
- **No Crash Data / Other Diagnostic Data.** PostHog bundles PLCrashReporter, and its
  manifest declares Crash Data and Other Diagnostic Data. 7.0 turns crash capture off
  (`errorTrackingConfig.autoCapture = false`), and session replay, autocapture and
  surveys are off too, so nothing is collected. The Xcode privacy report will still list
  these two types because the bundle is linked. That is expected. **If you turn on
  PostHog error tracking later, add Diagnostics → Crash Data (App Functionality, not
  linked).**
- **Device ID is declared for RevenueCat only.** RevenueCat reads the IDFV, which is
  a device-level ID, so it is declared. PostHog doesn't read the IDFV. Its distinct ID
  is a random UUID that is deleted with the app, so Device ID's purpose is App
  Functionality only, not Analytics. "Not linked" follows RevenueCat's own manifest
  (`NSPrivacyCollectedDataTypeLinked = false`): the IDFV identifies a device for one
  vendor, not a person. If you want the strictest reading, mark Purchase History and
  Device ID as **Linked**. That's allowed, and it never causes a rejection.
- **Customer support email isn't collected by the app.** Send a correction / Request a
  hymnal opens the user's own Mail app (or a `mailto:` link) with an editable draft. The
  user chooses whether to send it, and nothing goes through our servers. That falls under
  Apple's "optional, user-initiated contact" exemption. If you'd rather list it, add
  Contact Info → Email Address and User Content → Customer Support (App Functionality,
  linked).
- **Analytics can be switched off by leaving `Analytics.projectToken` empty.** In
  that case the PostHog rows don't apply, but keeping them on the label is harmless.

## Required-reason APIs (already in the manifests; nothing to enter in ASC)

| API | Who | Reason |
|---|---|---|
| UserDefaults | App, PostHog, RevenueCat | CA92.1 (app's own data) |
| System boot time | PostHog | 35F9.1 |
| File timestamp | PostHog | C617.1 |

The app's own code only uses UserDefaults: settings, favourites, playlists, recents
and What's New seen. The scan was a `grep` for timestamp, uptime and disk-space APIs.
