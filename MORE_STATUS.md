# MORE_STATUS — Pro card, Privacy & credits, About, no email

Branch `more`, merged into `main`. Not pushed.

## What changed

### 1. Pro at the top of More (`Store/ProMoreCard.swift`)
A card above Reading, with a strip of the paywall's scenery: the church logo glowing
in the gold light over a small crowd of raised hands (`PaywallLight`, `PaywallHands`,
`PaywallLogo`; Reduce Motion is respected the same way as on the paywall).

- **Free:** "Advent Praise Pro / Sing without limits", the paywall's four lines (shared
  through `ProPaywallView.lines`), a meter of free plays of the piano left ("3 of 5 free
  plays of the piano left", or used up), **See Advent Praise Pro** (opens the paywall,
  as the old row did) and "Already bought Pro? Restore".
- **Pro:** "You have Advent Praise Pro", a thank-you line, and **Restore purchases**.

The old "Advent Praise Pro" and "Restore purchases" rows are gone from More.

### 2. Privacy & credits (`Features/PrivacyPolicyView.swift`)
A native policy screen (serif type, reading measure, "In short" box, then sections).
It says what the code does:

- No account; favourites, playlists, service plans, recents, pitch notes and settings
  stay on the device; the free-play count is also in the Keychain.
- Anonymous usage via PostHog (EU): what is and isn't sent, no GeoIP, no crash reports
  or session recordings, random ID, how to switch it off (and that off deletes the ID).
- No ads, no IDFA, no tracking, no ATT prompt.
- Purchases through Apple/StoreKit; analytics never carry price or receipt.
- Feature board (Features.Vote) — this section only appears when the build has a board.
- Links to other sites, children, changes. Game Center and accounts aren't mentioned:
  7.0 has neither.

**Credits & Attribution** at the end: hymn texts (earlier Advent Praise texts and
CIS Hymnals by Tinashe Mzondiwa, linked), piano accompaniment (The Cyber Hymnal,
hymntime.com — the source the app already credited and that `docs/midi-sources.csv`
lists for all 490 files; nothing in the repo mentions traditionalmusic.co.uk, so it
isn't credited), scripture index (hymn words, Christ in Song 1908, Hymnary.org;
passages on Bible.com KJV), collections (SDA Hymnal 1985 sections via Hymnary.org),
software (PostHog iOS SDK, Features.Vote SDK).

Every privacy link points here:
- More → About → *Privacy & credits* (Tools-style sheet; Done returns to More).
- The paywall's *Privacy Policy* link (a sheet over the paywall).
- About Advent Praise → *Privacy & credits* (pushed in the same stack).

`AppInfo.privacyPolicyURL` is removed (nothing uses it). The MIDI credit row is out of
More. The Cyber Hymnal credit in About this hymn and its reader-menu panel stays (that
is the hymn's own accompaniment credit, not More).

### 3. About Advent Praise (`Features/AboutAppView.swift`)
Logo in a soft glow, "Advent Praise", one line on what it is, then "A note from
Malcolm": who he is (independent developer from South Africa, makes the app on his
own), why (the SDA hymns in the languages of Southern Africa), thanks to everyone who
bought translations in earlier versions, whose support made every translation free in
7.0. Signed "Malcolm Kumwenda · Independent developer, South Africa". Then Version,
Build and Privacy & credits. No other facts are claimed; "building in public" isn't
used. Klippa's `FounderNoteView` (letter, signature, attribution) was the reference.

### 4. Email removed
Malcolm's personal address (hi@malcolmk.com) was **not** in the repo: no code,
string, plist, bundled doc or fastlane file contained it. The only address in the app
was the placeholder `support@adventpraise.app`, used by the Mail contact feature. Per
the brief ("replace contact options with nothing or a non-email path already in the
app"), the whole email path is gone:

| Removed | Where |
|---|---|
| `AppInfo.supportEmail = "support@adventpraise.app"` | `App/AppInfo.swift` |
| `mailto:` fallback URL built from it | `Features/MailComposeView.swift` (file deleted) |
| `MFMailComposeViewController` recipient, MessageUI import | same file |
| "Send a correction" row (envelope) | `Reader/MoreDrawer.swift` |
| "Request a hymnal" / "Request a hymnal or feature" row | `Reader/MoreDrawer.swift` |
| `MailRequest`, `ReaderModel.mail` | `Reader/ReaderModel.swift` |
| Mail sheet | `App/RootView.swift` |
| `feedback_mail_opened` / `feedback_mail_finished` events, `MailKind`, `MailResult`, `mail` screen | `Services/AnalyticsEvent.swift`, `ANALYTICS_PLAN.md` |
| `privacy_policy` external link (now in-app) | `Services/AnalyticsEvent.swift`, `ANALYTICS_PLAN.md` |
| "Use Send a correction… opens an email" + "Send a correction straight from any hymn" | `docs/appstore/listing.md` (App Store description) |
| "Contact: Malcolm, with a phone number and email" | `docs/appstore/review-notes.md` (now: use App Store Connect's private App Review contact fields) |
| "Send a correction opens Mail", "support email receives mail" checklist item | `docs/appstore/review-notes.md` |
| `supportEmail` row, "contact email", "Email:" policy item, "send a test email" | `docs/appstore/urls-checklist.md` (rewritten) |
| `supportEmail` placeholder | `docs/appstore/STATUS.md`, `STATUS.md` |
| "correction email" / customer-support-email exemption | `docs/appstore/privacy-label.md` |

The non-email path left is **Vote on features** (Features.Vote), which shows only when
the build sets `FEATURES_VOTE_API_KEY`; with it empty (as in the repo) More has no
feedback section at all. Info.plist and `PrivacyInfo.xcprivacy` had no email. Older
`*_STATUS.md` history files that describe the removed feature were left as history.

## Debug flags added
- `-uiDebugFree YES`: free whatever StoreKit says (this simulator keeps a test Pro
  purchase, so `-uiDebugPro NO` wasn't enough).
- `-uiDebugCredits YES`: Privacy & credits opens scrolled to the credits.

## Verification
- `xcodebuild build` (Debug, iPhone 17 Pro, iOS 27.1): succeeded, **no warnings**.
- `xcodebuild test`: 22 tests in 4 suites passed.
- Screenshots, `build/shots/more/` (iPhone 17 Pro; paper = light, black = dark):
  `more-top-{light,dark}` (free, 3 of 5 plays left), `pro-card-pro-{light,dark}`,
  `about-{light,dark}`, `privacy-{light,dark}`, `credits-{light,dark}`. Taken with
  `simctl launch … -uiDebugNoSplash YES -uiDebugHymn 1 -uiDebugSurface paper|black`
  plus `-uiDebugMore YES -uiDebugFree YES -uiDebugFreePlaysUsed 2`, `-uiDebugPro YES`,
  `-uiDebugSheet aboutApp`, `-uiDebugSheet privacy [-uiDebugCredits YES]`.
- Build output (`build/DD`) deleted afterwards; screenshots kept.

## For Malcolm
- App Store Connect still needs a public Privacy Policy URL and a Support URL: publish
  the in-app text, and a support page with a contact route that isn't your personal
  email (a form, or the feature board). See `docs/appstore/urls-checklist.md`.
- Corrections now have no path unless the Features.Vote board is configured. Consider
  setting `FEATURES_VOTE_API_KEY` for release.
- POPIA/GDPR data requests: everything is on the device or anonymous, but decide with
  counsel whether the policy needs a contact route.
- The policy is dated "Updated October 2026"; change it with the policy.
