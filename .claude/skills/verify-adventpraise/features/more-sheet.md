# More sheet: a navigation stack inside a sheet

More is a standard sheet holding a `NavigationStack` (Pro card, Reading switches, Tools, Support, About). Its detail pages (About Advent Praise → Privacy/Terms, Privacy Policy, Terms of Use, Scripture index → a passage, Collections → a collection, Service planner → a plan, the pitch pipe) push under a standard inline navigation bar. The system **Back** button (and the edge swipe) pops one level. **Done**, top right on every page, closes the whole of More. Closing More any way (Done, a swipe down) resets it, so the next open starts at the root. Support (paywall chrome), Vote on features and Recommend open as sheets over More. Church mode and the Pro paywall start once More has gone. More is not an AdventDrawer any more: About this hymn is (see `about-this-hymn.md`).

## Sub-features

- `more-open` the tray's More tile opens the sheet at its root: bar titled `More`, Done, no Back.
- `more-support` Support Advent Praise opens over More in the paywall's chrome; its Close returns to More's root.
- `more-push-2` About Advent Praise → Privacy Policy pushes two levels; Back pops one level at a time.
- `more-done` Done on a pushed page (the Scripture index) closes More; reopening starts at the root.
- `more-swipe` a swipe down from a pushed page (the pitch pipe) closes More; reopening starts at the root.
- `more-church` Church mode opens only after More has gone.
- `more-close` Done on the root dismisses More.
- `more-tools-deep` Collections → a collection and Service planner → a plan push a second level (not yet in the journey).

## How to get to it (user POV)

- Lectern handle (`Hymn actions`) → hymn tray → **More** tile.
- Debug shortcut only: `-uiDebugMore YES` opens the root.

## Driving it with the APVerify harness

Preconditions:

- DEBUG build installed on `AP Verify iPhone`; any prior state is fine.

- **Run.** `xcodebuild test … -only-testing:APVerifyUITests/MoreSheetJourney`. Evidence in `../verify-evidence/<run>/more-sheet/`.
- **Open.** Tap `lectern.handle`, then the tray's `More`. `navigationBars["More"]` with `Done`, and one bar button (no Back). Shot `more-root`.
- **Support.** Tap `Support Advent Praise`; `A one-off thank you` shows. Shot `support-over-more`. Tap its hittable `Close`; More is still at its root. Shot `back-from-support`.
- **Two levels.** Push `About Advent Praise` (bar `About`, shot `about-app-page`), then its Privacy row (bar `Privacy`, shot `privacy-from-about`). Back → `About`, Back → `More`. Shot `back-at-root`.
- **Done from a page.** Push `Scripture index`, tap its `Done`: the bar goes. Shot `closed-by-done`. Reopen: bar `More`, not `Scripture index`.
- **Swipe from a page.** Push `Pitch pipe`, drag from its bar to the bottom of the screen: the bar goes. Shot `closed-by-swipe`. Reopen at the root. Shot `reopened-at-root`.
- **Church mode.** Tap `Church mode`: `Leave worship mode` appears and the `More` bar is gone. Shot `church-mode`. Leave worship mode.
- **Done on the root.** Reopen, tap `Done`. Shot `closed`.

## Gotchas

- Find More's pages by navigation-bar title (`app.navigationBars["More"]`, `["About"]`, `["Privacy"]`, `["Scripture index"]`, `["Pitch pipe"]`). Scope `Done` to the bar. The system back button's label is the parent's title, so find it as the bar's one button that isn't `Done`.
- The tray tile is also labelled `More`. Scope it to `lectern.hymnTray`.
- The reader menu keeps a `Close` button of its own in the tree, so for Support's Close pick the last hittable `Close`.
- About Advent Praise is long: swipe up if a row isn't hittable.
- Vote on features only shows when the build has a `FEATURES_VOTE_API_KEY` (empty in the repo), so it is absent locally.
