# App Privacy ("nutrition label") answers — Advent Praise 7.0

App Store Connect → App Privacy. These answers match:

- `AdventPraise/Resources/PrivacyInfo.xcprivacy` (the app's own manifest),
- the manifests bundled by the SDKs (`PostHog_PostHog.bundle`, `PostHog_PHPLCrashReporter.bundle`;
  checked in the 7.0 archive),
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
| Usage Data → **Other Usage Data** | Yes | Analytics | No | No | PostHog adds app version/build, OS version, device model (e.g. "iPhone", not the user's device name), locale, timezone, screen size, wifi/cellular to every event. The app adds the open hymnal, reading surface, large print and whether Pro is active as super properties |
| Diagnostics → **Other Diagnostic Data** | Yes | Analytics | No | No | `error_occurred`: a domain (audio, purchase, restore, products, hymnal_load) and a short code such as `SKErrorDomain.2` or `StoreKit.StoreKitError.1`. No messages, no stack traces, no crash reports |
| Everything else | No | | | | |

Select **only** these three data types. For each, answer:

- *Used for tracking?* **No**
- *Linked to the user's identity?* **No**
- *Purposes:* Product Interaction → Analytics; Other Usage Data → Analytics; Other Diagnostic Data → Analytics

Resulting label: **Data Not Linked to You: Usage Data, Diagnostics.** No "Data Used
to Track You" section.

**Purchase History and Device ID are no longer collected.** They were declared only
because RevenueCat synced transactions and sent the IDFV. RevenueCat has been removed:
purchases go straight through StoreKit 2, Pro is read from
`Transaction.currentEntitlements` on the device, and there is no server, SDK or API
key. StoreKit purchases stay between the user and Apple, so if the live label still
lists Purchases or Identifiers, untick them. (The app's own `PrivacyInfo.xcprivacy`
should drop its Device ID and Purchase History entries to match.)

`purchase_*` and `tip_*` analytics events (started, completed, cancelled, failed) carry
the App Store product ID only (e.g. `ap_pro_lifetime`), and for Pro the feature the
paywall led with. They count as Product Interaction, not Purchase History, because they
hold no transaction, price or receipt. `is_pro` is a yes/no flag, not a purchase record.

## Why each "No" is true (keep this if the code changes)

- **Not linked.** Analytics is anonymous: `personProfiles = .never`, `identify` is never
  called, and `setDefaultPersonProperties = false`. PostHog's distinct ID is a random UUID
  stored on the device. PostHog never receives a name, email, account ID or advertising
  identifier. **If you ever call `PostHogSDK.identify`, change the answer to "Linked"
  and add Identifiers → User ID.**
- **Not tracking.** No IDFA, no `AppTrackingTransparency`, no data brokers, and no
  combining with other companies' data. `NSPrivacyTracking` is false in every manifest.
- **No Location.** PostHog normally works out a coarse location from the IP address.
  7.0 sets `config.disableGeoIp = true` (`Analytics.swift`), so it doesn't. As a second
  safeguard, turn on **Project settings → "Discard client IP data"** in the PostHog
  project.
- **No Purchase amounts in analytics.** Purchase and tip events only carry the App Store product ID.
  Prices are not sent.
- **No user content in analytics.** Search sends the query's length and result count,
  never the words. Playlist and service plan names and hymn text are never sent. Every property value is a typed enum, number or boolean
  (`AnalyticsEvent.swift`).
- **No Crash Data.** PostHog bundles PLCrashReporter, and its manifest declares Crash Data
  and Other Diagnostic Data. 7.0 turns crash capture off
  (`errorTrackingConfig.autoCapture = false`), and session replay, autocapture and
  surveys are off too. The Xcode privacy report will still list Crash Data because the
  bundle is linked. That is expected; don't copy it. **Other Diagnostic Data is real**:
  the app's own `error_occurred` event counts non-fatal failures by code, so it is
  declared. **If you turn on PostHog error tracking later, add Diagnostics → Crash Data
  (App Functionality, not linked).**
- **The user can turn analytics off.** More → About → *Share anonymous usage*. The
  in-app Privacy Policy (More → About → *Privacy & credits*) says the same as this file. Off opts
  PostHog out and calls `reset()`, deleting the anonymous ID and super properties. The
  label still declares the data types, because they are collected from everyone who
  leaves it on.
- **No Device ID.** Nothing in the app reads the IDFV now that RevenueCat is gone.
  PostHog's distinct ID is a random UUID that is deleted with the app, not a device ID.
- **No Purchase History.** Purchases are made and checked with StoreKit 2 on the
  device; no third party sees them.
- **No email contact.** 7.0 has no Send a correction, no Request a hymnal and no
  `mailto:` link, so no Contact Info is involved. Requests go to the Features.Vote board
  when the build has one (anonymous; see `FeatureBoardConfig.swift`).
- **Analytics can be switched off for everyone by leaving `Analytics.projectToken`
  empty.** In that case the PostHog rows don't apply, but keeping them on the label is
  harmless. Debug builds never send (unless launched with `-analytics.debugSend YES`).

## Required-reason APIs (already in the manifests; nothing to enter in ASC)

| API | Who | Reason |
|---|---|---|
| UserDefaults | App, PostHog | CA92.1 (app's own data) |
| System boot time | PostHog | 35F9.1 |
| File timestamp | PostHog | C617.1 |

The app's own code only uses UserDefaults: settings, favourites, playlists, recents
and What's New seen. The scan was a `grep` for timestamp, uptime and disk-space APIs.
