# Analytics audit — Advent Praise 7.0

Branch `analytics`, audited at `abd9330` (before any change on this branch). This covers
what the app sent, what it missed, and the privacy problems. What was changed is at the
end. The funnels and dashboards are in `ANALYTICS_PLAN.md`.

## 1. What was there

`AdventPraise/Services/Analytics.swift`: a `@MainActor enum Analytics` wrapping PostHog
(`posthog-ios` 3.92.0, EU host). `start()` is called from `AdventPraiseApp.init`, and
`track(_:)` is a no-op until then. An empty `projectToken` means it never starts. The token
is still empty, so **no build has sent anything yet**.

The SDK config was already privacy-minded: `personProfiles = .never`, no lifecycle
autocapture, no screen autocapture, no element autocapture, no swizzling, no session
replay, no feature flags, no surveys, no crash autocapture, `disableGeoIp = true`, and
`setDefaultPersonProperties = false`. `identify` is never called.

### Events and call sites

| Event | Properties | Fired from | Problem |
|---|---|---|---|
| `app_opened` | — | `RootView` `.onChange(of: scenePhase)` → `.active` | Fires on **every** `inactive → active`: pulling down Notification Centre or Control Centre, a system alert, Face ID, or the App Switcher. It also fires once per window on iPad (one `RootView` per scene). Cold and warm starts look the same, and nothing marks the app going to the background, so there's no session length. |
| `hymn_opened` | `hymnal`, `number` | `ReaderModel.show(_:)` | Fires for every hymn change, including the playlist advancing on its own when the accompaniment ends, a hymnal switch re-showing the same number, and Siri. **No source**, so it can't answer "how do people find hymns". |
| `hymnal_switched` | `hymnal` | `ReaderModel.switchHymnal` | No `from` and no source. It also fires when a refund forces the app back to English (`RootView.enforceOwnership`), which looks like a user choice. |
| `search_used` | `scope` | `LecternSearchPanel`: tapping a result, or Return | Only fires when a result is **opened**. Searches that were abandoned or found nothing are invisible, and there's no result count or rank. The iPad sidebar search isn't tracked at all. |
| `church_mode_started` | `hymnal` | `ChurchModeView.onAppear`, **and** `Extras.startChurchMode` | **Double-counted** for service plans and collections: both places fire. No source, no exit, no duration. |
| `large_print_changed` | `on` | `HymnReaderView` `.onChange(of: settings.style.scale)` | Lives on the reader, which is rebuilt when the size class flips. It's the only appearance setting tracked. |
| `purchase_completed` | `hymnal` | `PurchaseStore.buy` | No `purchase_started`, `purchase_cancelled` or `purchase_failed`, and no paywall exposure, so **conversion can't be computed**. |
| `restore_tapped` | — | `PurchaseStore.restore` | No outcome (found or not, failed), and no source. |
| `mail_composed` | `kind` | `MailComposeView.onAppear` | Fires when the composer **opens**, not when mail is sent. A cancelled correction counts the same as a sent one. |
| `shortcut_run` | `intent` | the four App Intents | Fine, but nothing says whether it worked (e.g. "no hymn 900"). |
| `whats_new_continued` | `action` | **nowhere** | Declared but never sent. What's New exposure and its "Try Worship Mode" button aren't measured. |

### Not tracked at all

- Screen views (every drawer, sheet and tool).
- Favourites.
- Playlists: create, edit, delete, play.
- Service planner, memory game, pitch pipe, collections, scripture index, About this hymn.
- Accompaniment (MIDI): play, pause, complete, tempo.
- Paywall: shown, dismissed. Purchase: started, cancelled, failed.
- Appearance: surface, font, spacing, alignment, text size, pinch-to-zoom. Church mode text size.
- Haptics and "chorus after every verse" switches.
- Recommend (share sheet), Rate, and the privacy policy link.
- Church mode exit, and whether it reaches a TV or projector ("cast").
- Errors. Audio failures were written to `os.Logger` in `HymnMIDIEngine` only. Purchase,
  restore, product-load and hymnal-load failures were shown to the user and then lost.
- Background, so no session length.

## 2. Structural problems

1. **Names are free strings.** `mailComposed(kind: String)`, `shortcutRun(intent: String)` and
   `whatsNewContinued(action: String)` take any string, so a typo or a new caller makes a new
   value in PostHog without anyone noticing.
2. **No context on events.** Nothing carries the current hymnal, reading surface or large
   print, so you can't break any event down by language without that event repeating it.
3. **No local visibility.** Events aren't logged, so you can't check in Console or Xcode
   that an event fires.
4. **Debug builds would send** to the production project as soon as a token is pasted in.
5. **No opt-out.** The only off switch is the compile-time token.

## 3. Privacy issues

| # | Issue | Severity | Fix on this branch |
|---|---|---|---|
| P1 | **No user-facing opt-out.** The app collects usage data with no way to say no. The privacy label and policy can be accurate and this still isn't a good look for a church app. Under GDPR / ePrivacy, anonymous product analytics relies on legitimate interest, and that needs an easy objection route. | High | "Share anonymous usage" switch in More → About, on by default, saved across launches. Turning it off calls `PostHogSDK.optOut()` **and** `reset()`, so the anonymous ID and super properties are deleted. Turning it back on starts a fresh ID that can't be joined to the old one. |
| P2 | **Special-category data (GDPR Art. 9).** Using an Adventist hymnal at all suggests religious belief, and the hymnal key (e.g. `shona`) suggests language and ethnicity. Anonymous, unlinked data lowers the risk but doesn't make it go away. | Medium (legal) | Data stays anonymous, unlinked, EU-hosted and opt-out-able. **Recommendation for Malcolm:** have the privacy policy name PostHog and the opt-out switch, and decide with counsel whether EEA users should be **opted in by consent** rather than opted out. That's a one-line change (`defaultEnabled`) in `Analytics.swift`. |
| P3 | **The IP address still reaches PostHog.** `disableGeoIp` stops the location lookup, but the request still carries the client IP. | Medium | Kept `disableGeoIp`. The PostHog project setting **"Discard client IP data"** must be on. It's listed as a must-do in `ANALYTICS_PLAN.md` §6 and in `docs/appstore/privacy-label.md`. |
| P4 | **Free-text risk.** Nothing sent text the user typed, but nothing stopped it either: properties were `[String: Any]` from a string. | Low | Every property value is now a typed enum, `Int` or `Bool`. Search sends **query length, result count and whether it was a number**, never the query. Playlist and plan **names are never sent**. Neither is hymn text, the mail body, or anything from it. Errors send a domain and a short code, never `localizedDescription`. |
| P5 | **Prices.** None were sent; the label says purchase amounts aren't collected. | — | Unchanged. Purchase and tip events carry the App Store product ID only (e.g. `ap_pro_lifetime`), never a price. |
| P6 | **IDFA / ATT.** Not used. No AdSupport, no `AppTrackingTransparency`, `NSPrivacyTracking = false`. | — | Unchanged. No ATT prompt is needed, because nothing tracks across apps or companies. |
| P7 | **Device ID.** PostHog's distinct ID is a random UUID on the device, not the IDFV. | — | Unchanged. The opt-out now deletes it (P1). |
| P8 | **Debug and TestFlight noise / leakage.** Simulator and debug sessions would have mixed with real users. | Low | DEBUG builds log events to Console and send nothing, unless launched with `-analytics.debugSend YES`. |
| P9 | **Crash reporter linked.** PLCrashReporter is in PostHog's bundle. Auto-capture is off and stays off. Non-fatal errors are sent as an ordinary `error_occurred` event with a code (Other Diagnostic Data, see §5). | Low | Privacy manifest and label updated for Other Diagnostic Data (P10). |
| P10 | **Labels didn't match the new data.** `error_occurred` counts as Diagnostics → Other Diagnostic Data. | — | `PrivacyInfo.xcprivacy` and `docs/appstore/privacy-label.md` now declare it (Analytics, not linked, not tracking). |

## 4. Gaps against the questions we want answered

| Question | Possible before? | Why not |
|---|---|---|
| What share of new installs read a hymn on day 0 (activation)? | Partly | `app_opened` was inflated, and there was no cold-start marker. |
| How do people find hymns: number pad, search, swipe, playlist, Siri? | No | No `source` on `hymn_opened`. |
| Which features get used, and by how many weekly users? | No | Most features weren't tracked. |
| What's the paywall → purchase conversion, by language and entry point? | No | No paywall exposure, no purchase start, cancel or fail. |
| Which languages are read, switched to, and bought? | Partly | No `from`, no super property, and forced switches looked like choices. |
| Do searches find what people want? | No | Only successful searches were seen. |
| Does What's New's "Try Worship Mode" drive church mode use? | No | Never sent. |
| Does the accompaniment get played to the end? | No | Not tracked. |
| What breaks in the field? | No | Errors weren't counted. |

## 5. What this branch changes

- `Services/AnalyticsEvent.swift`: one typed taxonomy. `AnalyticsEvent` is an enum of 47
  events, all snake_case `object_action`. Property values are typed enums (`HymnSource`,
  `HymnalSource`, `ChurchModeSource`, `PlaylistEdit`…), `Int` or `Bool`. The only strings are
  catalogue keys (hymnal, Pro package or product ID), the app version and iOS's share
  activity type, so a call site can't pass free text by accident. `AnalyticsScreen` names
  22 screens.
- `Services/Analytics.swift`: the one service. It handles the opt-out switch, anonymous ID
  reset, super properties (`hymnal`, `surface`, `large_print`, `is_pro`), screens, app open, background
  and session length, non-fatal errors through `os.Logger` plus `error_occurred`, a debug log of
  every event, and no sending from DEBUG builds.
- Instrumentation for every area listed in the brief. The full event list with properties is
  in `ANALYTICS_PLAN.md` §2.
- Fixes for the bugs above: `app_opened` only on cold start or background → foreground, once
  per app (not per window). Church mode is counted once. Mail counts on its *result*. What's
  New is measured. The playlist advancing on its own is labelled `playlist_advance`.
- "Share anonymous usage" switch in More → About.
- `PrivacyInfo.xcprivacy` and `docs/appstore/privacy-label.md` updated.

### After merging main (ui2)

ui2 landed on main while this branch was in progress: every hymnal became free, purchases
moved to a **Pro** entitlement (accompaniment player and AirPlay) with its own paywall, and
church mode gained a real external-display mode. The merge adapted the analytics:

- The hymnal-picker paywall events went away with the locked hymnals. The pickers keep
  `hymnal_switched` with its source.
- `paywall_viewed` / `paywall_dismissed` now sit on the Pro paywall, with the feature it led
  with (`player`, `air_play`) and the screen it covered (`reader`, `church_mode`).
  `purchase_*` carry the package or product ID and the feature. `restore_completed` says
  whether Pro came back. New super property `is_pro`.
- `church_mode_cast_changed` reports the real external screen (`is_connected`, and
  `shows_hymn`, which is false without Pro). The interim screen-capture heuristic is gone.

## 6. Still open (needs Malcolm)

- Paste the PostHog project token into `Analytics.projectToken`. Until then nothing is sent.
- Turn on **Discard client IP data** in the PostHog project.
- Privacy policy: name PostHog, list the categories, and point to the switch (P2).
- Decide opt-out versus opt-in for the EEA (P2).
- `church_mode_cast_changed` and the Pro paywall events were checked only in the simulator
  (the paywall with `-uiDebugPaywall YES`; free is the default, `-uiDebugFree` is gone). A real AirPlay or HDMI
  connection, and a sandbox purchase, still need checking on a device.
