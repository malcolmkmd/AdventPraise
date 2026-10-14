# More drawer: pages inside the drawer

More is a bottom drawer (Pro card, Reading switches, Tools, Support, About). Support Advent Praise, About Advent Praise (and its Privacy/Terms rows), Privacy Policy, Terms of Use and the pitch pipe push as pages inside the same drawer: they slide in, a **Back** button sits top left, and the card resizes to each page. Only the root shows **Close**. Dragging down or tapping the backdrop closes from any page, and the next open starts at the root. The other tools (Scripture index, Collections, Service planner) and Vote on features still open full screen and return to More.

## Sub-features

- `more-open` the tray's More tile opens the drawer at its root, with Close.
- `more-push` Support / About Advent Praise / Privacy / Terms / Pitch pipe push a page (Back, no Close, root rows hidden).
- `more-push-2` About Advent Praise → Privacy Policy pushes a second level; Back pops one level at a time.
- `more-close-any` drag-down from a page closes the drawer; reopening starts at the root.
- `more-close` Close on the root dismisses More.
- `more-fullscreen-tools` Scripture index, Collections, Service planner open full screen and come back to More at their row (not yet in the journey).

## How to get to it (user POV)

- Lectern handle (`Hymn actions`) → hymn tray → **More** tile.
- Debug shortcut only: `-uiDebugMore YES` opens the root.

## Driving it with the APVerify harness

Preconditions:

- DEBUG build installed on `AP Verify iPhone`; any prior state is fine.

- **Run.** `xcodebuild test-without-building … -only-testing:APVerifyUITests/MoreDrawerJourney`. Evidence in `../verify-evidence/<run>/more-drawer/`.
- **Open.** Tap `lectern.handle`, then the tray's `More`. `Support Advent Praise` row and `Close` show; no `Back`. Shot `more-root`.
- **Support page.** Tap `Support Advent Praise`. `Back` shows, `Close` and `Rate on the App Store` don't. Shot `support-page`. Back → `Close` again.
- **Two levels.** Tap `About Advent Praise` (shot `about-app-page`), then its Privacy row (shot `privacy-from-about`). Back once: About's Privacy row is back and `Back` still shows. Back again: `Close`. Shot `back-at-root`.
- **Pitch pipe page.** Tap `Pitch pipe`; `Back` shows. Shot `pitch-page`.
- **Drag to close.** Drag from the top of the card to the bottom of the screen. `Back` disappears (drawer gone). Shot `closed-by-drag`. Reopen More: `Close`, no `Back`. Shot `reopened-at-root`.
- **Close.** Tap `Close`; it disappears. Shot `closed`.

## Gotchas

- XCUITest reports the drawer card as an **Alert** labelled `More` (the card is `.isModal`), not as an `otherElement`. Scope `Back`/`Close` to it with `drawer("More")`. The reader menu keeps its own `Close` button (top right) in the tree even while the menu is shut, so an unscoped `app.buttons["Close"]` always exists and "a page hides Close" falsely fails.
- The tray tile is also labelled `More`. Scope it to `lectern.hymnTray`.
- Close/Back fade with an opacity transition, so use `waitGone(close, timeout: 2)` rather than an instant `!exists`.
- Pages hide the levels underneath from accessibility, so "root row not found" while on a page is expected, and is itself the check.
- About Advent Praise is long: swipe up if a row isn't hittable.
- **Known finding (2026-10-14, iPhone 17 Pro sim):** when the card is at full height (More's root, About Advent Praise, Privacy Policy), a tap at the centre of `Back`/`Close` (y≈82 pt, under the status bar) does nothing, while a tap at the button's lower edge (y≈102) works. The journey's `tapTopControl` logs a `FINDING … responds to a tap at its centre` with a `…-centre-tap-ignored` shot, then uses the lower edge so the rest still runs. When that finding stops appearing, the bug is fixed. Leave the check in.
- Vote on features only shows when the build has a `FEATURES_VOTE_API_KEY` (empty in the repo), so it is absent locally.
