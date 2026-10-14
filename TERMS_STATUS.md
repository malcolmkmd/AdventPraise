# Terms of Use, credits clean-up, StoreKit file (terms) — status

Branch `terms`, merged into `main`, not pushed. Builds and tests ran in the foreground on one simulator
(iPhone 17 Pro, iOS 27.0), and the build output (`build/dd`) was deleted afterwards:

- `xcodebuild … -configuration Debug -destination 'generic/platform=iOS Simulator' build`: succeeded, no warnings
- `xcodebuild test …`: **28 tests in 5 suites pass** (PurchaseStoreTests now loads `StoreKit/Products.storekit`)

Screenshots are in `build/shots/terms/`: `01-terms-of-use`, `02-privacy-content-we-include`, `03-support`,
`04-about-this-hymn-scripture`, `05-about-advent-praise`.

## What changed

1. **Tinashe / cis-hymnals removed.** The only user-visible mention was the Hymn texts credit in the Privacy Policy
   (name and GitHub link). The texts are now credited to "earlier versions of Advent Praise" only. Nothing else in
   the app (Swift, resources, plist) mentions Tinashe, TinasheMzondiwa or cis-hymnals.
2. **The Software credit and the credits list are gone.** The Privacy Policy no longer ends in a "Credits &
   Attribution" card list. The Software row (PostHog SDK, Features.Vote SDK) is removed. The hymn-text, scripture
   index and collections sources are now plain paragraphs in a new **Content we include** section.
3. **MIDI credit.** It is one small sentence in footnote-size secondary text (`PolicySectionCopy.note`) inside
   *Content we include*, in the middle of the policy and not under its own heading: "The piano accompaniment uses
   MIDI files from The Cyber Hymnal (hymntime.com)." It has been removed from About this hymn (the Accompaniment
   section) and from the reader menu's About panel. The MIDI player and What's New had no source mentions.
   `AppInfo.cyberHymnalURL` and the `cyber_hymnal` analytics link value are gone (`ANALYTICS_PLAN.md` and
   `docs/appstore/urls-checklist.md` are updated).
4. **Terms of Use** (`Features/TermsOfUseView.swift`), in the Privacy Policy's style (it reuses `PolicyHeader` and
   `PolicySection`): Malcolm Kumwenda / MDEVSA (PTY) LTD, South Africa; hymn texts for personal and congregational
   worship; Pro is a one-time purchase through Apple, with refunds through Apple; tips unlock nothing; no warranty;
   limitation of liability; South African law; terms may change. No email addresses. It opens from **More → About →
   Terms of Use** (right after Privacy Policy, `ExtraSheet.terms`, `-uiDebugSheet terms`) and from About Advent Praise.
   Its screen view is `terms`.
5. The More row "Privacy & credits" is now **Privacy Policy** (in About Advent Praise too).
6. **Support sheet:** "Advent Praise is built by one solo developer, Malcolm Kumwenda, in his spare time. …"
7. **About this hymn:** the scripture footer starts "Opens in the Bible app." (the ≈ note and the source still
   follow it).
8. **StoreKit:** the local configuration is `StoreKit/Products.storekit`: `ap_pro_lifetime` R199.99 non-consumable,
   and `ap_tip_amen` R19.99, `ap_tip_hallelujah` R49.99 and `ap_tip_hosanna` R99.99 consumables, with a ZAF storefront.
   It is the former `AdventPraise.storekit`, renamed rather than duplicated. It is attached only to the shared
   scheme's Run action (Debug); Test, Profile and Archive don't use it, and it isn't in any target. References are
   updated in the scheme, the tests, `scripts/storekit-shot.sh`, `PurchaseConfig.swift` and
   `docs/appstore/screenshots.md`. `AdventPraise-USD.storekit` is unchanged.

## Notes

- The Terms text is a plain-language draft, not legal advice; have it checked before relying on it.
- The App Store Connect EULA/Terms field and any website copy of the privacy policy aren't touched. If the website
  still credits CIS Hymnals, update it to match.
- Older `*_STATUS.md` files are history and still mention the old credits.
