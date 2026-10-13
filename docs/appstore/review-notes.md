# App Review notes — Advent Praise 7.0

Paste the block below into **App Store Connect → 7.0 → App Review Information → Notes**.
Set **Sign-in required: No**. Fill in App Store Connect's own App Review contact fields
(Apple requires them and only App Review sees them); nothing in the notes below or in
the app carries contact details.

```
Advent Praise is a hymnal reader. No account or sign-in is needed.

HOW TO TRY IT
1. On first launch, a "Welcome to Advent Praise 7" sheet appears. Tap Continue (or "Try Church Mode").
2. The hymn reader opens on Christ In Song (English), which is free. All navigation is in the floating bar at the bottom of the screen. Tap the grid button (3x3 dots) to open the number pad. Type 12 and tap Go.
3. Church mode: tap the round green button on the left of the bottom bar. Tap the right side of the screen to go to the next verse, then tap the close button to leave.
4. Search: open the number pad, tap "Abc", and type a word such as "jesus".
5. Hymn actions: tap the hymn title in the bottom bar to see Save, Church, Hymnal, Text and More.
6. Siri / Shortcuts: say "Open hymn in Advent Praise", then a number. The Shortcuts app also lists Next Hymn and Start Church Mode.

IN-APP PURCHASES
All hymnals are free. Advent Praise Pro is one non-consumable in-app purchase. It unlocks the accompaniment player after its 5 free plays, and church mode on AirPlay. To test it, play hymns 6 times or tap AirPlay in church mode; the Pro paywall appears. Buy it with your sandbox account. "Restore purchases" is on the paywall and in More. Optional tips (consumable, they unlock nothing) are under More > Support Advent Praise. Purchases are processed by Apple through StoreKit; there is no third-party purchase SDK. There are no subscriptions and no trial.

"PLAY HYMN" SHORTCUT
Version 7.0 does not include audio accompaniment files. The Play Hymn shortcut opens the hymn and says that accompaniment isn't available yet. The app shows no play controls.

PRIVACY
No tracking, no advertising identifier, no account. Anonymous product analytics (PostHog, with IP geolocation off; the user can turn it off in More → About → Share anonymous usage) are not linked to the user. Purchases go only through Apple (StoreKit); no third party sees them. The privacy policy is in the app: More → About → Privacy & credits, and the Privacy Policy link on the Pro screen.

CONTENT
The hymn texts are traditional hymnals used by Seventh-day Adventist congregations. We will provide documentation of our rights to distribute them if you need it.
```

## Before submitting, make these true

- [ ] The four products exist in App Store Connect with exactly the IDs in `PurchaseConfig.swift`
      (STATUS blocker 2): `ap_pro_lifetime` (non-consumable), `ap_tip_amen`, `ap_tip_hallelujah`,
      `ap_tip_hosanna` (consumables). Otherwise the reviewer can't buy anything, and the app is rejected
      under 2.1 (App Completeness).
- [ ] Every product in `PurchaseConfig.allProductIDs` is **Ready to Submit** in App Store Connect and is
      submitted with this build (version page → In-App Purchases section). New IAPs need a review
      screenshot (the Pro paywall, or the Support Advent Praise screen for tips, 640×920 or larger).
- [ ] Paid Applications Agreement, tax and banking are active (otherwise products return empty in review).
- [ ] The public privacy policy page (the App Store Connect URL) is live and shows the same thing as the
      in-app policy and `privacy-label.md`.
- [ ] Decide on the **Play Hymn** shortcut (see STATUS.md). If you remove it, delete the "PLAY HYMN SHORTCUT"
      paragraph above.

## Content rights (Guideline 5.2)

App Store Connect asks: *"Does your app contain, show, or access third-party content?"*
The answer is **Yes**: published hymnals. The reviewer may ask for proof. Have these
ready:

- **Christ In Song** (1908): public domain in most countries. Note the edition used.
- **SDA Hymnal** (1985, Review and Herald): this is under copyright. You need a licence or
  written permission from the publisher, or from the General Conference for the
  Adventist name and logo.
- Each translated hymnal: permission from the union or publisher that owns it.
- "Seventh-day Adventist", "Adventist" and "SDA" are trademarks of the General
  Conference. The listing uses them only to describe the content (the hymnal titles), not
  as the app's name.

If 6.x was approved with the same content, that history helps, but it doesn't
protect you if a rights holder complains.

## Likely rejection risks and the answer to each

| Risk | Guideline | Mitigation in 7.0 |
|---|---|---|
| No app icon | 2.1 / binary validation | **Blocker.** Add a 1024 px icon before upload. Without it, `altool` rejects the build with "Missing app icon" and "CFBundleIconName". |
| IAPs not loadable | 2.1 | The four products created with exactly these IDs and submitted with the build; Paid Apps agreement signed |
| Restore missing | 3.1.1 | Restore purchases is on the Pro paywall and on the Pro card at the top of More (`AppStore.sync()`) |
| Feature that does nothing (Play Hymn) | 2.1 / 2.3.1 | Explained in notes; listing doesn't mention playback |
| No privacy policy in app | 5.1.1(i) | In the app: More → About → Privacy & credits, and the paywall's Privacy Policy link (`PrivacyPolicyView`) |
| Misleading metadata | 2.3 | Listing describes only shipped features; screenshots come from the real build |
| Content rights | 5.2.1 | Documentation above |
