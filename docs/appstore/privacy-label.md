# App Privacy ("nutrition label") answers — Advent Praise 7.0

App Store Connect → App Privacy. These answers match:

- `AdventPraise/Resources/PrivacyInfo.xcprivacy` (the app's own manifest),
- the manifests bundled by the SDKs (`PostHog_PostHog.bundle`, `PostHog_PHPLCrashReporter.bundle`,
  `RevenueCat_RevenueCat.bundle`; checked in the 7.0 archive),
- what the code actually sends (`Services/Analytics.swift`, `Services/AnalyticsEvent.swift`,
  `Store/PurchaseStore.swift`). Every event and property is listed in `ANALYTICS_PLAN.md`.

After archiving, check **Xcode → Organizer → archive → Generate Privacy Report**. That
PDF merges every manifest. The answers below explain the one line in it you should
*not* copy (crash data).

## Do you or your third-party partners collect data from this app?

**Yes.**

## Data types

| Category → type | Collected? | Purpose | Linked to user? | Tracking? | Source |
|---|---|---|---|---|---|
| Usage Data → **Product Interaction** | Yes | Analytics | No | No | PostHog events and screen views: `hymn_opened`, `search_performed`, `church_mode_entered`, `paywall_viewed`… (full list in `AnalyticsEvent` and `ANALYTICS_PLAN.md`) |
| Usage Data → **Other Usage Data** | Yes | Analytics | No | No | PostHog adds app version/build, OS version, device model (e.g. "iPhone", not the user's device name), locale, timezone, screen size, wifi/cellular to every event. The app adds the open hymnal, reading surface and large print as super properties |
| Diagnostics → **Other Diagnostic Data** | Yes | Analytics | No | No | `error_occurred`: a domain (audio, purchase, restore, products, hymnal_load) and a short code such as `RevenueCat.ErrorCode.10`. No messages, no stack traces, no crash reports |
| Purchases → **Purchase History** | Yes | App Functionality | No | No | RevenueCat syncs App Store transactions to decide which hymnals are owned |
| Identifiers → **Device ID** | Yes | App Functionality | No | No | RevenueCat sends the IDFV (`UIDevice.identifierForVendor`) as `X-Apple-Device-Identifier` on every request (`purchases-ios` `HTTPClient.swift`) |
| Everything else | No | | | | |

Select **only** these five data types. For each, answer:

- *Used for tracking?* **No**
- *Linked to the user's identity?* **No**
- *Purposes:* Product Interaction → Analytics; Other Usage Data → Analytics; Other Diagnostic Data → Analytics; Purchase History → App Functionality; Device ID → App Functionality

Resulting label: **Data Not Linked to You: Usage Data, Diagnostics, Purchases,
Identifiers.** No "Data Used to Track You" section.

`purchase_*` analytics events (started, completed, cancelled, failed) carry the product
key only (`swahili`, `all`). They count as Product Interaction, not Purchase History,
because they hold no transaction, price or receipt.

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
- **No Purchase amounts in analytics.** Purchase events only carry the product key.
  Prices are not sent.
- **No user content in analytics.** Search sends the query's length and result count,
  never the words. Playlist and service plan names, hymn text and the correction email
  are never sent. Every property value is a typed enum, number or boolean
  (`AnalyticsEvent.swift`).
- **No Crash Data.** PostHog bundles PLCrashReporter, and its manifest declares Crash Data
  and Other Diagnostic Data. 7.0 turns crash capture off
  (`errorTrackingConfig.autoCapture = false`), and session replay, autocapture and
  surveys are off too. The Xcode privacy report will still list Crash Data because the
  bundle is linked. That is expected; don't copy it. **Other Diagnostic Data is real**:
  the app's own `error_occurred` event counts non-fatal failures by code, so it is
  declared. **If you turn on PostHog error tracking later, add Diagnostics → Crash Data
  (App Functionality, not linked).**
- **The user can turn analytics off.** More → About → *Share anonymous usage*. Off opts
  PostHog out and calls `reset()`, deleting the anonymous ID and super properties. The
  label still declares the data types, because they are collected from everyone who
  leaves it on.
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
- **Analytics can be switched off for everyone by leaving `Analytics.projectToken`
  empty.** In that case the PostHog rows don't apply, but keeping them on the label is
  harmless. Debug builds never send (unless launched with `-analytics.debugSend YES`).

## Required-reason APIs (already in the manifests; nothing to enter in ASC)

| API | Who | Reason |
|---|---|---|
| UserDefaults | App, PostHog, RevenueCat | CA92.1 (app's own data) |
| System boot time | PostHog | 35F9.1 |
| File timestamp | PostHog | C617.1 |

The app's own code only uses UserDefaults: settings, favourites, playlists, recents
and What's New seen. The scan was a `grep` for timestamp, uptime and disk-space APIs.
