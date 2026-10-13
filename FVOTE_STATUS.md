# Features.Vote — status

Branch `fvote`. More → Help us improve now has a **Vote on features** row ("Or request one"). It opens the Features.Vote board in a sheet. This follows Klippa's pattern (ADR-0124 there), but uses **Advent Praise's own board**.

**The row is hidden in this commit.** The board slug is empty, so the app shows no row, never configures the SDK and makes no Features.Vote network calls until you complete the setup below.

## What you need to do

1. **Create the board.** Sign in at <https://features.vote> and create a new project/board for Advent Praise. Klippa's `myklippa` board is a separate product: **do not reuse it**. The app refuses the slug `myklippa` even if someone pastes it in (`FeatureBoardConfig.refusedSlugs`).
2. **Note the board's slug.** That's the subdomain in `https://<slug>.features.vote/board`, e.g. `adventpraise`. The iOS SDK (`FeaturesVote.configure(with:)`) needs only this slug. There is no separate secret key, and REST/MCP `fv_live_` keys are **not** used. Don't put one in the app.
3. **Board settings in the Features.Vote admin**, to match what the app sends:
   - Allow anonymous voting: **on**
   - Allow anonymous comments: **on**
   - Require email to post: **off**
   - Watermark: the app leaves it on (Lite plan). If you're on a paid plan, the server-side setting can still hide it.
   - Optional: board title "Vote on features". The admin's custom title overrides the app's.
   - Optional: brand colour Evergreen `#1F7466`. In the app, the board already uses the reading surface's colours. The admin colour only affects the web board.
4. **Put the slug in the build.** The Info.plist key `FEATURES_VOTE_API_KEY` reads `$(FEATURES_VOTE_API_KEY)`. Its build setting is `""` on the AdventPraise target (Debug and Release). Choose one of these:
   - In Xcode: target → Build Settings → `FEATURES_VOTE_API_KEY` = `<slug>`, for Release, Debug or both. Commit that change if you want it shipped. A slug is public (it's in the board's URL), so committing it is fine.
   - Or per build: `xcodebuild … FEATURES_VOTE_API_KEY=<slug>`. For fastlane, add `xcargs: "FEATURES_VOTE_API_KEY=<slug>"` to `build_app` in `fastlane/Fastfile`.
5. **Privacy.** The privacy policy (`AppInfo.privacyPolicyURL`) should say that feature requests, comments and votes typed into Vote on features go to Features.Vote with a random per-install ID, and that no name or email is sent. Update the App Store privacy label if needed. Features.Vote receives "User Content", not linked to identity.

## What's in the app

| Piece | Where |
|---|---|
| SPM `https://github.com/features-vote/features-vote-sdk.git`, pinned to revision `a280a9d` (the same as Klippa; it's the first commit with `updateMetadata`, after 2.0.1). Min iOS 16, and our target is 17 | `project.pbxproj`, `Package.resolved` |
| Config, with no SDK import: slug from Info.plist, trimmed. Empty, an unexpanded `$(…)` or `myklippa` → disabled. Anonymous flags, metadata, first-open record | `AdventPraise/Services/FeatureBoardConfig.swift` |
| SDK setup (configured lazily on the first open, never at launch), Vesper theme from the reading surface, the sheet, the first-open notice, and the glass close button | `AdventPraise/Features/FeatureBoard.swift` |
| Row in More (only when enabled). With a board, the mail row is relabelled "Request a hymnal" so feature asks have one door | `AdventPraise/Reader/MoreDrawer.swift` |
| Sheet attached at the root; closing it goes back to More at the row | `RootView.swift`, `ReaderModel.showFeatureBoard` |
| DEBUG: `-uiDebugFeatureBoard YES` opens it (add `-featureBoard.disclosedAt 0` to skip the notice) | `DebugLaunch.swift` |

**Identity:** anonymous only. The SDK generates `anon_<UUID>` per install. We never call `updateUser(…)`, `setToken` or a custom ID. `post_metadata` on new requests is `app_version` and `platform=ios` only.

**First open:** before the board loads, a notice explains that requests, comments and votes go to Features.Vote with a random ID, and asks people not to type their name or email. The board, and its first network call, waits for **Continue**. That choice is stored as `featureBoard.disclosedAt`.

**Design:** the sheet uses the reading surface (`ToolSheetChrome`). The SDK theme is mapped from `DSSurface`: tint, brass, background, elevated, foreground/secondary, Vesper typefaces, tile radius. The close button is `GlassButton(.icon)`: Liquid Glass on iOS 26, the Vesper fallback on 17–25. Same placement as the drawers'.

**Analytics** (in `ANALYTICS_PLAN.md`): `feature_board_opened {disclosed}`, `feature_board_disclosure_accepted`, `feature_board_closed {duration_seconds, showed_board}`, and screen `feature_board`. No titles, text, votes or vendor IDs are sent.

**Haptics** (in `HAPTICS_STATUS.md`): opening the board → softImpact. Continue → lightImpact. Close → none.

## Verified

- iOS Simulator build (`generic/platform=iOS Simulator`), **0 warnings, 0 errors**, with the empty placeholder.
- Simulator (iPhone 17 Pro), built with a throwaway slug that was **not committed**:
  - the row shows in More, and the mail row reads "Request a hymnal";
  - the first-open notice renders on Paper;
  - the board renders inside our chrome on Muted.
  - That slug has no board behind it, so the SDK showed its own error ("no rows returned"). That's expected. Live voting has not been exercised until a real board exists.
- With an empty key, the row is absent (the `isEnabled` gate).

## Known limits

- The SDK's error/empty views hard-code some colours (for example, a purple "Try Again"). Fixing that would need a fork.
- There is no test target in this project yet, so Klippa's `FeaturesVoteContractTests` equivalent wasn't added. `FeatureBoardConfig.slug(from:)` and `metadata(appVersion:)` are pure and ready for one.
