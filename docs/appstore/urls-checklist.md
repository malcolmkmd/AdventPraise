# Support / privacy URL checklist — Advent Praise 7.0

App Store Connect rejects the submission if the Support URL or Privacy Policy URL is
missing or doesn't load. App Review also opens them by hand.

## URLs and addresses in the build

| Where | Value in code | Status |
|---|---|---|
| `AppInfo.privacyPolicyURL`: More → About → Privacy policy | `https://adventpraise.app/privacy` | **Placeholder.** Publish the page, or change the constant to wherever the policy really lives |
| `AppInfo.supportEmail`: Send a correction / Request a hymnal | `support@adventpraise.app` | **Placeholder.** Confirm the mailbox exists and is read |
| `AppInfo.appStoreURL`: Recommend Advent Praise share sheet | `https://apps.apple.com/app/id1015021132` | OK, this is the live app |
| `AppInfo.writeReviewURL`: More → Rate on the App Store | `…/id1015021132?action=write-review` | OK |
| `Analytics.host` | `https://eu.i.posthog.com` | Must match the PostHog project's region |

If the domain `adventpraise.app` isn't yours, choose a domain you control and update
**both** constants and App Store Connect in the same change.

## App Store Connect fields

- [ ] **Support URL** (required): a page that loads without a login and shows a way to
      contact you (the email above or a form), plus a short FAQ: restoring purchases,
      changing hymnal, using Church mode, and sending a correction.
      Suggested: `https://adventpraise.app/support`
- [ ] **Privacy Policy URL** (required): exactly `AppInfo.privacyPolicyURL`.
- [ ] **Marketing URL** (optional): `https://adventpraise.app`
- [ ] All three use HTTPS, have a valid certificate, and are not geo-blocked (several of
      the target markets are in Africa, so test from a non-EU/US network or a VPN).
- [ ] They work on a phone. App Review checks them on a device.

## What the privacy policy must say (to match `privacy-label.md`)

- [ ] Who you are: the seller name in App Store Connect, plus a contact email.
- [ ] No account, no ads, no tracking, and no sale of data.
- [ ] **Analytics:** PostHog (EU region). Anonymous events about how the app is used
      (hymn opened, search used, church mode started…) and counts of errors by code,
      with app version, OS version, device model, locale and timezone. No IP-based
      location, and the IP address is discarded (PostHog project setting). Not linked
      to a person. Search words, playlist names and hymn text are never sent. Say how
      to turn it off: More → About → *Share anonymous usage*. Say how long the data is
      kept (PostHog's retention setting). See `ANALYTICS_AUDIT.md` P2 on religious-belief
      data before publishing.
- [ ] **Purchases:** Advent Praise Pro and tips are bought through Apple's App Store
      (StoreKit). Apple handles payment, and the app checks Pro on the device. No third
      party receives your purchases, and we don't see your payment details.
- [ ] **Email:** if you send a correction, we get what you send: your email address
      and the message, including the app/iOS version the draft adds. It is only used to
      reply and fix the hymn.
- [ ] **Data on the device:** favourites, playlists and settings stay on the device
      and are not uploaded.
- [ ] How to ask for deletion or a copy of your data (GDPR/POPIA: many users are in
      South Africa, and POPIA applies). Analytics can't be tied to a person, so say
      that, and give the email address for any other request.
- [ ] Children: the app is rated 4+, is not aimed at children, and doesn't knowingly
      collect personal data from children.
- [ ] Effective date and a note that changes will be posted on this page.

## Before you press Submit

- [ ] Open every URL above on a phone on cellular data.
- [ ] Send a test email to the support address and receive the reply.
- [ ] In the 7.0 build: More → Privacy policy opens the live page.
- [ ] More → Rate on the App Store opens the review sheet for the live listing.
