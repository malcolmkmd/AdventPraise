# Analytics plan — Advent Praise 7

What we measure, why, and the PostHog insights and dashboards to build. The audit that
led here is `ANALYTICS_AUDIT.md`. The code is `AdventPraise/Services/AnalyticsEvent.swift`
(the taxonomy) and `AdventPraise/Services/Analytics.swift` (the service).

## 1. Ground rules

- **Anonymous.** One random UUID per install, kept on the device. No identify, no person
  profiles, no IDFA, no ATT prompt. So a "user" in PostHog is **an install**. Reinstalling,
  a new phone, or turning *Share anonymous usage* off and on all count as a new user. Read
  retention as install retention.
- **Opt-out users are invisible.** Rates are "of people who share usage". Expect a small
  bias towards less privacy-minded users.
- **No content.** No search words, no playlist or plan names, no hymn text, no prices. Hymn
  numbers and hymnal keys are fine: they're catalogue data.
- **Weekly is the natural unit.** People use a hymnal at Sabbath worship, choir practice
  and vespers. Daily retention will look poor and isn't the right test. Use **weekly**
  retention and active users, and expect Friday evening and Saturday peaks.
- **Names.** Events are `object_action` in snake_case, past tense. Properties are
  snake_case. Adding an event means adding a case to `AnalyticsEvent`; the compiler then
  makes you name it and give it typed properties.

## 2. Event dictionary

Every event also carries PostHog's defaults ($app_version, $os_version, $device_type,
$locale, $timezone, $session_id, $screen_name of the last screen) and three super
properties set by the app:

| Super property | Values | Set when |
|---|---|---|
| `hymnal` | `english`, `shona`, `zulu`… | launch and every hymnal switch |
| `surface` | `paper`, `parchment`, `sepia`, `muted`, `black` | launch and Appearance change |
| `large_print` | bool | launch and change |
| `is_pro` | bool | entitlements loaded, and every change |

### App

| Event | Properties | When |
|---|---|---|
| `app_opened` | `launch`: `cold` \| `warm` | Process start, or back from the background. Not returning from Control Centre or a system alert, and once per app, not per iPad window |
| `app_backgrounded` | `foreground_seconds` | App goes to the background. Flushes the queue |

### Reading

| Event | Properties | When |
|---|---|---|
| `hymn_opened` | `hymnal`, `hymn_number`, `source` | A hymn is put on screen. `source`: `numpad`, `search`, `favourites`, `playlist`, `playlist_advance` (accompaniment finished, playlist moved on), `swipe` (incl. VoiceOver next/previous), `church_mode`, `keyboard`, `siri`, `lock_screen`, `sidebar` (iPad list), `collection`, `scripture`, `service_plan`. A hymnal switch re-showing the same number isn't counted (see `hymnal_switched`) |
| `hymnal_switched` | `from_hymnal`, `to_hymnal`, `source` | The open hymnal changes. `source`: `sidebar` (iPad Hymnals sheet), `translation` (the reader menu's Translation panel, under the globe), `church_mode` (church mode's globe). `lectern` (the old Hymnals panel) is no longer sent. Every hymnal is free |
| `search_performed` | `surface` (`lectern` \| `sidebar`), `scope` (`lyrics` \| `titles`), `query_length`, `result_count`, `is_number` | 1.5 s after typing pauses |
| `search_result_opened` | `surface`, `scope`, `rank` (1-based) | A result is tapped, or Return opens the first |
| `favourite_toggled` | `hymn_number`, `is_favourite` | Star in the hymn tray, or ⌘D |
| `reader_menu_opened` | `panel` (`translation`, `theme`, `text`, `about`, `none`) | The globe grows into the reader menu; `panel` is the one open under its bar |
| `reader_menu_panel_opened` | `panel` | A tab in the open reader menu shows its panel (not sent when a tab folds its panel away) |

### Playlists, service plans, collections

| Event | Properties | When |
|---|---|---|
| `playlist_created` | `hymn_count` | New playlist named |
| `playlist_edited` | `action` (`hymn_added`, `hymn_removed`, `reordered`, `renamed`), `hymn_count` | Each edit |
| `playlist_deleted` | `hymn_count` | After the confirmation |
| `playlist_played` | `hymn_count`, `start_index` | Play, or a hymn tapped in the editor |
| `service_plan_created` | `hymn_count` | New plan, or a collection copied to a plan |
| `service_plan_edited` | `action` (`hymn_added`, `hymn_removed`, `reordered`, `role_set`), `hymn_count` | Each hymn edit (name and date aren't tracked) |
| `service_plan_deleted` | `hymn_count` | Swipe to delete |
| `service_plan_started` | `hymn_count` | "Start in church mode" |
| `collection_started` | `hymn_count` | "Sing in church mode" on a collection |

### Church mode

| Event | Properties | When |
|---|---|---|
| `church_mode_entered` | `source`: `tray`, `more`, `whats_new`, `siri`, `keyboard`, `voiceover`, `service_plan`, `collection` | Church mode appears |
| `church_mode_exited` | `duration_seconds`, `verses_shown`, `hymns_shown` | Church mode closes |
| `church_mode_cast_changed` | `is_connected`, `shows_hymn` | A TV or projector (AirPlay or cable) is already connected when church mode opens, or connects or disconnects while it's open. `shows_hymn` is false without Pro: the screen mirrors the phone (no worship display) |
| `mirroring_detected` | `via`: `external_display`, `capture`; `in_church_mode` | A free user's screen is mirrored or captured and the Go Pro banner shows. Once per session. Its paywall's `feature` is `mirroring` |

### Appearance and settings

| Event | Properties | When |
|---|---|---|
| `appearance_changed` | `setting` (`surface`, `font`, `line_spacing`, `alignment`, `large_print`), `value` | 1 s after the change settles, one event per setting changed |
| `text_size_changed` | `context` (`reader` \| `church_mode`), `method` (`pinch`, `slider`, `buttons`, `reset`), `point_size` | Reader: 1 s after it settles. Church mode: on release / tap |
| `setting_changed` | `setting` (`haptics`, `repeat_chorus`), `is_on` | Switch flipped |

### Accompaniment (MIDI)

| Event | Properties | When |
|---|---|---|
| `accompaniment_played` | `hymn_number`, `tempo`, `resumed` | Play from any control (Lectern, lock screen, Siri, playlist start). Not the engine resuming itself after an interruption |
| `accompaniment_paused` | `hymn_number`, `progress_percent` | Pause from a control. Not interruptions, headphones out, or stopping for another hymn |
| `accompaniment_completed` | `hymn_number`, `tempo`, `verses` | The last verse ends |
| `accompaniment_tempo_changed` | `tempo` | Tempo menu |
| `free_play_used` | `hymn_number`, `remaining` (plays left after this one, 4…0) | A free user starts a new play (a hymn from the top; not a resume, scrub or restart). Never for Pro |
| `play_limit_paywall_shown` | `hymn_number` | A free user with no free plays left starts a new play; the paywall opens instead (followed by `paywall_viewed`, `feature` = `player`) |

### Pro paywall and purchases

Every hymnal is free. Pro (owning the non-consumable `ap_pro_lifetime`, read from StoreKit's
`Transaction.currentEntitlements`; no server, no SDK) unlocks the accompaniment player
beyond its five free plays, AirPlay to a church screen, the pitch pipe and unlimited
Memorise. There is no subscription and no trial. The paywall opens when a free
user with no free plays left plays a hymn (Lectern, playlist, lock screen, Siri) or taps
AirPlay, or when a screen connects in church mode.

| Event | Properties | When |
|---|---|---|
| `paywall_viewed` | `feature` (`player` \| `air_play`), `context` (`reader` \| `church_mode`) | The Pro paywall opens |
| `paywall_dismissed` | `feature`, `context`, `outcome` (`unlocked` = Pro became active while open, bought or restored; `closed`) | It closes |
| `purchase_started` | `product` (the App Store product ID, e.g. `ap_pro_lifetime`; never a price), `feature` | Unlock Pro tapped |
| `purchase_completed` | `product`, `feature` | The purchase went through and Pro is active |
| `purchase_cancelled` | `product`, `feature` | The buyer cancels the App Store sheet |
| `purchase_failed` | `product`, `feature`, `reason` (see below) | It can't start, the store fails, it's pending, or Pro doesn't activate |
| `restore_started` | `source` (`more` \| `paywall`) | Restore purchases tapped (`AppStore.sync()`) |
| `restore_completed` | `found_purchases`, `pro_active` | Restore finished |
| `restore_failed` | — | Restore errored |
| `tip_started` | `product` (e.g. `ap_tip_amen`) | A tip tapped on Support Advent Praise (More) |
| `tip_completed` | `product` | The tip went through |
| `tip_cancelled` | `product` | The buyer cancels the App Store sheet |
| `tip_failed` | `product`, `reason` (see below) | As `purchase_failed` |

`reason` on `purchase_failed` and `tip_failed`: `unavailable` (the product didn't load
from the App Store), `store_error`, `not_activated` (bought, but Pro isn't in
`Transaction.currentEntitlements`), `pending` (Ask to Buy or a payment check; it may
still go through later via `Transaction.updates`), `unverified` (StoreKit couldn't
verify the transaction), `not_allowed` (purchases turned off in Screen Time).
Cancellations are never failures; they are the separate `*_cancelled` events.

### Tools

| Event | Properties | When |
|---|---|---|
| `tool_opened` | `tool` (`about`, `scripture`, `collections`, `pitch`, `memory`, `planner`), `source` (`more`, `tray` = Memorise tile, `reader_menu` = About panel's "More about this hymn") | A Tools sheet is opened |
| `memory_game_started` | `part` (`verse` \| `chorus`), `level` (`few`, `half`, `most`, `all`), `word_count` | Each new round |
| `memory_game_completed` | `part`, `level`, `score`, `best_streak`, `first_try_percent`, `hints_used`, `stars` (1–3) | Last blank filled |
| `memory_hint_used` | `part`, `level`, `hints_left` | A hint spent: a letter shown, chips that can't fit ruled out |
| `memory_streak_reached` | `part`, `level`, `streak` (3, 6, 9…) | A streak earns a hint |
| `memory_verse_learned` | `part`, `stars` | A stanza finished with every word hidden |
| `memory_round_replayed` | `part`, `level` (the new round's), `reason` (`again`, `next_level`, `next_block`, `start_over`) | A button on the completion card starts another round |
| `pitch_pipe_used` | `action` (`published_note`, `custom_note`, `key_chosen`) | Note sounded |
| `scripture_opened` | `hymnal`, `book` (USFM code, e.g. `JHN`), `surface` (`about_hymn` \| `passage` \| `reader_menu`), `hymn_number` and `confidence` (`high` \| `medium`, About this hymn only) | Scripture chip or "Read in the Bible" tapped (opens bible.com / YouVersion) |

### Feedback, sharing, system

| Event | Properties | When |
|---|---|---|
| `feature_board_opened` | `disclosed` (true = straight to the board; false = the first-open notice) | Vote on features opens (More, only when the app has a Features.Vote board) |
| `feature_board_disclosure_accepted` | — | Continue on the first-open notice |
| `feature_board_closed` | `duration_seconds`, `showed_board` (false = closed at the notice) | The sheet closes. No titles, votes or board ids are sent |
| `whats_new_viewed` | `version` | What's New shown (once per major version) |
| `whats_new_dismissed` | `version`, `action` (`primary` = Try Worship Mode, `continue`, `dismissed` = swiped away) | It closes |
| `share_opened` | — | Recommend Advent Praise |
| `share_finished` | `completed`, `activity` (iOS activity type, e.g. `com.apple.UIKit.activity.Message`) | Share sheet closes |
| `external_link_opened` | `link` (`rate_app`) | Rate on the App Store in More. The privacy policy is in the app now: its screen view is `privacy` |
| `intent_run` | `intent` (`open_hymn`, `play_hymn`, `next_hymn`, `church_mode`), `succeeded` | Siri / Shortcuts / Action button |
| `error_occurred` | `domain` (`audio`, `purchase`, `restore`, `products`, `hymnal_load`), `code` | Non-fatal failure. Also written to `os.Logger` |

### Screens (`$screen`)

`reader`, `church_mode`, `more`, `appearance`, `hymnals`, `translations`, `paywall`, `search`,
`library`, `number_pad`, `whats_new`, `playlist_editor`, `playlist_hymn_picker`,
`about_hymn`, `about_hymn_panel` (the reader menu's summary), `scripture_index`, `collections`, `pitch_pipe`, `memory_game`,
`service_planner`, `service_plan`, `about_app`, `privacy`, `share`, `feature_board`.

## 3. Key questions and how to answer them

### Activation: do new installs get to a hymn, and to something they'll come back for?

- **Activated install** = on its first day, opened **3 or more hymns**, *or* did one
  "keeper" action: `church_mode_entered`, `favourite_toggled` (is_favourite = true),
  `playlist_created`, `service_plan_created` or `accompaniment_played`.
- Funnel (first-time users, 1-day window): `app_opened` (launch = cold, first time) →
  `hymn_opened` → 2nd `hymn_opened` → any keeper action.
- Break down by `$locale`, `hymnal` and `$device_type`. iPad users may skew towards
  musicians and leaders.
- Time to first hymn: funnel time-to-convert from first `app_opened` to `hymn_opened`.
  Target: median under 20 seconds.
- Does What's New help? Funnel `whats_new_viewed` → `whats_new_dismissed` (action =
  primary) → `church_mode_entered` (source = whats_new) → `church_mode_exited` with
  `duration_seconds` ≥ 60.

### Retention

- **Weekly retention**, first event `app_opened`, return event `hymn_opened`, 8 weeks.
  This is the headline number.
- Same, broken down by first-week behaviour (cohorts below): used church mode, made a
  playlist or plan, played accompaniment, used Siri. Which first-week habit predicts week 4?
- Weekly retention by `hymnal` (language). Are some language communities underserved?
- **Stickiness**: weekly active / monthly active installs, and days active per week.
  Expect 1–2 (Sabbath plus one).
- **Sabbath shape**: `hymn_opened` by day of week and hour, in the user's timezone.

### Feature adoption

For each feature, the share of **weekly active installs** that used it that week.

| Feature | Event (filter) |
|---|---|
| Number pad | `hymn_opened` source = numpad |
| Search | `search_performed` |
| Swipe | `hymn_opened` source = swipe |
| Favourites | `favourite_toggled` is_favourite = true, or `hymn_opened` source = favourites |
| Playlists | `playlist_played` or `playlist_created` |
| Service planner | `service_plan_created` or `service_plan_started` |
| Church mode | `church_mode_entered` |
| Projection | `church_mode_cast_changed` is_connected = true (and shows_hymn for Pro) |
| Accompaniment | `accompaniment_played` |
| Appearance | `appearance_changed`, `text_size_changed` |
| Large print | super property `large_print` = true (share of all events' installs) |
| Siri / Shortcuts | `intent_run` |
| Memory game | `memory_game_started` |
| Pitch pipe | `pitch_pipe_used` |
| Collections / Scripture | `hymn_opened` source in (collection, scripture), `collection_started` |
| Translation globe | `hymnal_switched` source = translation |

Also:

- **How people find hymns**: `hymn_opened` broken down by `source`, excluding
  `playlist_advance`, as a share of all opens per week.
- **Search quality**: share of `search_performed` with `result_count` = 0, by `scope`.
  Conversion `search_performed` → `search_result_opened` within 2 minutes. Mean `rank`.
  If titles-scope zero results are high, consider fuzzy matching.
- **Accompaniment completion**: `accompaniment_played` (resumed = false) →
  `accompaniment_completed` for the same `hymn_number`. Look at `progress_percent` on
  pauses for drop-off points.
- **Church mode in real use**: distribution of `duration_seconds`, and how many sessions
  run more than 10 minutes on a Saturday.

### Paywall conversion (Pro)

- Funnel (per install, 1-day window): `paywall_viewed` → `purchase_started` →
  `purchase_completed`. Break down by `feature` (player or AirPlay), `context` and `product`.
- **Which feature sells Pro?** `purchase_completed` by `feature`. And reach: how many
  installs ever hit the player gate versus the AirPlay gate.
- `paywall_dismissed` by `outcome`. A high `closed` share for `player` means people want to
  hear the tune but won't pay. Compare with `accompaniment_completed` among Pro users to
  see if the player keeps its value.
- `purchase_cancelled` / `purchase_started`: App Store sheet abandonment.
- `purchase_failed` by `reason`. `unavailable` means the product isn't set up (or ready)
  in App Store Connect, or the device is offline; `not_activated` or `unverified` point
  at a StoreKit problem; `pending` and `not_allowed` are the buyer's device settings.
- `restore_completed` by `pro_active` and `found_purchases`. Many `found_purchases` with
  `pro_active` false means 6.x hymnal buyers expecting Pro (see UI2_STATUS open items).
- Time from first `app_opened` to `purchase_completed`.
- Pro retention: weekly retention for `is_pro` = true against false.
- Revenue isn't sent. Take it from App Store Connect and divide by paywall
  viewers from PostHog for a rough revenue per viewer.

### Language usage

- Weekly active installs by `hymnal` (super property, unique users).
- `hymn_opened` by `hymnal`: where reading happens, not just where people start.
- `hymnal_switched` from → to, as a table. What do people switch to and back from? Bilingual
  pairs (English ↔ Shona) suggest a side-by-side feature.
- `$locale` against `hymnal`: people whose phone language has a hymnal but who read English.
  That's a discovery gap for the picker.
- Requests: `feature_board_opened` and `feature_board_closed` (the content stays on the
  board).

### Quality

- `error_occurred` by `domain` and `code`, per 1,000 `app_opened`. Alert if it doubles.
- `intent_run` with `succeeded` = false share. People asking Siri for a number the hymnal
  doesn't have.

## 4. PostHog setup to create

### Cohorts

1. **New this week**: first `app_opened` in the last 7 days.
2. **Activated**: did a keeper action, or 3+ `hymn_opened` within 1 day of first seen.
3. **Church mode users**: `church_mode_entered` in the last 30 days.
4. **Planners**: `playlist_created` or `service_plan_created` ever.
5. **Accompaniment users**: `accompaniment_played` in the last 30 days.
6. **Pro**: super property `is_pro` = true on their latest event.
7. **Paywall seen, not bought**: `paywall_viewed` in the last 30 days and not Pro.
8. **Siri users**: `intent_run` ever.

### Actions (in Data management → Actions)

- **Keeper action**: `church_mode_entered` OR `favourite_toggled` (is_favourite = true) OR
  `playlist_created` OR `service_plan_created` OR `accompaniment_played`.
- **Found a hymn**: `hymn_opened` where source ≠ `playlist_advance`.

### Insights

| # | Name | Type | Definition |
|---|---|---|---|
| 1 | Weekly active installs | Trends | `app_opened`, unique users, weekly |
| 2 | WAU by hymnal | Trends | `app_opened`, unique users, weekly, breakdown `hymnal` |
| 3 | Weekly retention | Retention | `app_opened` → `hymn_opened`, weekly, 8 periods |
| 4 | Retention by first-week habit | Retention | as 3, filtered by cohorts 3, 4, 5, 8 (four insights or one with cohort breakdown) |
| 5 | Activation funnel | Funnel | first-time `app_opened` → Found a hymn → Found a hymn → Keeper action, 1 day |
| 6 | Time to first hymn | Funnel | first-time `app_opened` → `hymn_opened`, time to convert |
| 7 | How hymns are found | Trends | Found a hymn, total count, weekly, breakdown `source`, % stacked |
| 8 | Feature adoption | Trends | one series per row of the adoption table, unique users, weekly, formula ÷ series 1 |
| 9 | Stickiness | Stickiness | `hymn_opened`, weekly |
| 10 | Sabbath shape | Trends | `hymn_opened`, hourly, last 14 days (or a day-of-week × hour heat map via SQL) |
| 11 | Search quality | Trends | `search_performed` count, and with `result_count` = 0, breakdown `scope` |
| 12 | Search → open | Funnel | `search_performed` → `search_result_opened`, 2 minutes |
| 13 | Church mode duration | Trends | `church_mode_exited`, property `duration_seconds`, median and p90, weekly |
| 14 | Church mode sources | Trends | `church_mode_entered`, breakdown `source` |
| 15 | Projection | Trends | `church_mode_cast_changed` is_connected = true, unique users, breakdown `shows_hymn` |
| 16 | Accompaniment completion | Funnel | `accompaniment_played` (resumed = false) → `accompaniment_completed`, 30 minutes |
| 17 | Paywall funnel | Funnel | `paywall_viewed` → `purchase_started` → `purchase_completed`, 1 day, breakdown `feature` |
| 18 | Paywall outcomes | Trends | `paywall_dismissed`, breakdown `feature` and `outcome` |
| 19 | Purchases by product | Trends | `purchase_completed`, breakdown `product`, monthly |
| 20 | Purchase failures | Trends | `purchase_failed` breakdown `reason`, and `purchase_cancelled` |
| 21 | Restore outcomes | Trends | `restore_completed` breakdown `pro_active` and `found_purchases`, and `restore_failed` |
| 22 | Hymnal switches | Trends (table) | `hymnal_switched`, breakdown `from_hymnal` then `to_hymnal` |
| 23 | Locale vs hymnal | Trends (table) | `app_opened` unique users, breakdown `$locale` and `hymnal` |
| 24 | What's New funnel | Funnel | `whats_new_viewed` → `whats_new_dismissed` (primary) → `church_mode_entered` (whats_new) |
| 25 | Appearance choices | Trends | `appearance_changed`, breakdown `setting` and `value` |
| 26 | Text size | Trends | `text_size_changed`, breakdown `context` and `method`; property `point_size` distribution |
| 27 | Errors | Trends | `error_occurred`, breakdown `domain` and `code`, formula per 1,000 `app_opened` |
| 28 | Siri | Trends | `intent_run`, breakdown `intent` and `succeeded` |
| 29 | Feedback | Trends | `feature_board_closed`, breakdown `showed_board` |
| 30 | Sharing | Funnel | `share_opened` → `share_finished` (completed = true), breakdown `activity` |

### Dashboards

1. **Health (weekly review)**: 1, 2, 3, 5, 7, 9, 27.
2. **Activation & retention**: 3, 4, 5, 6, 24, cohort sizes for Activated and New this week.
3. **Feature adoption**: 8, 11, 12, 13, 14, 15, 16, 25, 26, 28, plus memory game and pitch pipe
   trends.
4. **Pro & purchases**: 17, 18, 19, 20, 21, 15, plus weekly retention by `is_pro`.
5. **Languages**: 2, 22, 23, `hymn_opened` by `hymnal`, retention by `hymnal`.

Set an alert on 27 (errors per 1,000 opens) and on 17's last step dropping to 0 for a week
(purchases broken).

## 5. Checking events

- In a debug build every event is logged and none are sent. Watch them in Console.app or
  Xcode with subsystem `com.mDev.Advent-Praise`, category `analytics`:
  `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.mDev.Advent-Praise" AND category == "analytics"' --level debug`.
- To send from a debug build to a test PostHog project, run with the launch argument
  `-analytics.debugSend YES` and a token pasted in.
- In PostHog, use **Activity → Live events** filtered by `$app_version` to check a build
  before release.

## 6. Must-do before release

1. Paste the PostHog project token into `Analytics.projectToken`.
2. PostHog project settings: turn on **Discard client IP data**. Set data retention, and
   say what it is in the privacy policy.
3. Make the cohorts, actions, insights and dashboards above.
4. Privacy policy: name PostHog, list the event categories and the switch
   (`docs/appstore/urls-checklist.md`). Decide on opt-in versus opt-out for the EEA
   (`ANALYTICS_AUDIT.md` P2).
