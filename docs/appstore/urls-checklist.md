# Support / privacy URL checklist — Advent Praise 7.0

App Store Connect rejects the submission if the Support URL or Privacy Policy URL is
missing or doesn't load. App Review also opens them by hand.

The privacy policy itself now lives **in the app**: More → About → *Privacy & credits*
(`Features/PrivacyPolicyView.swift`), also opened by the paywall's *Privacy Policy*
link. App Store Connect still needs a public Privacy Policy URL, so publish the same
text on the web.

The app has **no email address** in it: no Send a correction, no Request a hymnal, no
`mailto:` link (see `MORE_STATUS.md`). Requests go to the Features.Vote board (More →
Vote on features) when the build has one.

## URLs in the build

| Where | Value in code | Status |
|---|---|---|
| `AppInfo.appStoreURL`: Recommend Advent Praise share sheet | `https://apps.apple.com/app/id1015021132` | OK, this is the live app |
| `AppInfo.writeReviewURL`: More → Rate on the App Store | `…/id1015021132?action=write-review` | OK |
| `Analytics.host` | `https://eu.i.posthog.com` | Must match the PostHog project's region |

## App Store Connect fields

- [ ] **Support URL** (required): a page that loads without a login and shows a way to
      get help that isn't a personal email (a form or the feature board), plus a short
      FAQ: restoring purchases, changing hymnal, using Church mode.
- [ ] **Privacy Policy URL** (required): a public page with the same text as the
      in-app Privacy Policy.
- [ ] **Marketing URL** (optional).
- [ ] All three use HTTPS, have a valid certificate, and are not geo-blocked (several of
      the target markets are in Africa, so test from a non-EU/US network or a VPN).
- [ ] They work on a phone. App Review checks them on a device.

## What the privacy policy says (keep the web copy and the app in step)

The in-app screen already covers each of these; the web page must say the same.

- [x] Who makes the app: Malcolm Kumwenda, an independent developer in South Africa.
- [x] No account, no ads, no tracking, and no sale of data.
- [x] **Analytics:** PostHog (EU region). Anonymous events about how the app is used
      with app version, OS version, device model, locale, timezone and screen size. No
      IP-based location. Not linked to a person. Search words, playlist names and hymn
      text are never sent. How to turn it off: More → *Share anonymous usage*.
- [x] **Purchases:** through Apple's App Store (StoreKit). We don't see payment details.
- [x] **Data on the device:** favourites, playlists, service plans and settings stay on
      the device; the free-play count is also in the Keychain.
- [x] **Feature board** (only when the build has one): Features.Vote, a random ID,
      posts are public.
- [x] Children, links to other sites, and changes.
- [ ] Say how long PostHog keeps data (its retention setting). See `ANALYTICS_AUDIT.md`
      P2 on religious-belief data before publishing.
- [ ] How to ask for deletion or a copy of your data (GDPR/POPIA: many users are in
      South Africa). Analytics can't be tied to a person and everything else is on the
      device; decide with counsel whether a non-email contact route is needed.

## Before you press Submit

- [ ] Open every URL above on a phone on cellular data.
- [ ] In the 7.0 build: More → Privacy & credits and the paywall's Privacy Policy open
      the in-app policy.
- [ ] More → Rate on the App Store opens the review sheet for the live listing.
