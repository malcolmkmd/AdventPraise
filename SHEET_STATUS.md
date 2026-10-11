# Drawer (branch `sheet`) — status

What's New, Appearance and More now open in our own drawer, `AdventPraise/Drawer/AdventDrawer.swift`, in place of system sheets. The drawer's behaviour follows the Family app's: a floating, inset card with concentric corners that rises from the bottom and sizes itself to its content.

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` (clean) succeeds with **no warnings** (Xcode 27.1, Swift 6, iOS 17 deployment target).

## Reference and licence

The reference repo (`cristicretu/family-drawer`) has no licence. It was cloned to `/tmp/fd` for reading, but the session wasn't allowed to read files outside the worktree, so none of its source was read. The drawer was written from scratch, from the Family drawer's known behaviour and the brief. Nothing in this branch comes from that repo.

## How it works

- **One value drives everything.** `extent` is the height of the card's top edge above its resting line.
  - Between detents it is the card's height.
  - Below the smallest detent the card keeps that height and slides down.
  - Above the largest detent it rubber-bands (UIScrollView's formula, capped at 90 pt).
  - The backdrop dim and a 0.94→1 scale (anchored at the bottom) follow the same value, so they never drift out of step.
- **Interruptible.** `DrawerStage` is `Animatable`. Its body runs every frame and records the on-screen value in `DrawerProbe`, so a drag that starts mid-animation catches the card exactly where it is, with no jump.
  - Drags write `extent` without animation (the card stays under the finger).
  - On release, an `interpolatingSpring` starts at the finger's velocity.
- **Snapping.** A flick (> 350 pt/s) moves one stop in its direction: the next detent, or dismissal if it starts below the smallest. A slow release settles on the nearest detent; below 55 % of the smallest detent it dismisses. Changing detent plays a soft haptic.
- **Detents:** `.fitted` (content height), `.fraction(f)`, `.large`. Each is capped below the status bar, and near-duplicates are merged. If the content or the screen size changes, the drawer springs to follow the detent it's resting on.
- **Opening waits for measurement.** The drawer mounts off screen and opens once the content has reported its height (with a 150 ms fallback), so `.fitted` never jumps. It stays mounted until the close animation finishes.
- **Dismiss:** swipe down, tap the backdrop, the close button (top trailing, `GlassButton` `.icon`), or the VoiceOver escape gesture.
- **Bottom actions** sit in a `safeAreaInset` slot whose height is always reserved, so revealing them never moves the content.
  - They fade and slide in over the first 56 pt of scrolling (iOS 18: `onScrollGeometryChange`; iOS 17: a `PreferenceKey` in a named coordinate space).
  - Once fully shown they stay pinned (latched).
  - They show straight away when nothing is hidden. Overflow that is only the reserved slot counts as nothing to scroll; without that rule, What's New opened with an empty gap and no buttons.
  - They always show when VoiceOver is on.
  - A gradient scrim in the surface colour (Stage for What's New) sits behind them.
- **Content drags (iOS 18+).** A `UIGestureRecognizerRepresentable` pan on the ScrollView takes over only when the content is at its top and the drag is mostly vertical: downward to shrink or dismiss, upward while a taller detent remains. The scroll view waits for it to decline, so the two never move together. Horizontal drags (the text-size slider) aren't affected.
- **iOS 17** drags by the top handle band only. The band is a drag handle on every version.
- **Glass:** `dsGlass(.sheet)`, so Liquid Glass on iOS 26 and Vesper sheet material (opaque when Reduce Transparency is on) on iOS 17–25.
- **Reduce Motion:** open and close cross-fade instead of spring, no scale, and actions fade without sliding. Drags still track the finger; releases settle with a short ease-out.
- **VoiceOver:**
  - The card is a modal container labelled with the drawer's title, and the screen-changed notification is posted on open and close.
  - The grabber and backdrop are hidden from VoiceOver.
  - Hidden actions are hidden from VoiceOver too, and with VoiceOver on the drawer opens at its largest detent.
- **Dynamic Type:** every height is measured, nothing is fixed. Content beyond the cap scrolls.
- **iPad / regular width:** the card is centred, at most 540 pt wide, 20 pt+ off the bottom, and covers both split-view columns. The drawers hang off `RootView`, inside `dsSurface`, so they read the current reading surface.

## Applied to

| Drawer | Detents | Dim | Actions |
|---|---|---|---|
| What's New (`whatsNewDrawer`, show-once kept on the same key) | fitted, large | 0.5 | Try Worship Mode, Continue |
| Appearance (`appearanceDrawer`) | 60 %, large | 0.12 (live preview of the lyrics above) | Done |
| More (`moreDrawer`, new `Reader/MoreDrawer.swift`) | fitted | 0.36 | none (every row is an action) |

- More used to be a Lectern panel. It is now a drawer: the More tile closes the Lectern and opens it, and `LecternState.more` is gone. Rows that go elsewhere (Appearance, Church mode, Hymnals, Mail) close the drawer first. Recommend opens the share sheet over it.
- `AppearanceControls` no longer has its own ScrollView (the drawer provides it), and its header Done button isn't passed any more.
- **Behaviour change:** Appearance used to allow scrolling the reader behind it. Now a tap outside dismisses it, as the brief asks; the lyrics above still preview live.
- Still system sheets, which were out of scope: the Hymnals picker (iPad toolbar / sidebar), Mail, Share, the iPad number-pad popover, and the church-mode full-screen cover.

## Checked in the simulator (iOS 27.0)

- iPhone 17 Pro: What's New on a fresh install, with its buttons shown because nothing is hidden. More fits its content over the dimmed reader. Appearance opens at 60 % with lyrics readable above and Done hidden until scrolling; the close button no longer crowds "19 pt" after moving it up 4 pt.
- iPad Pro 11": What's New is centred at 540 pt over both columns.
- A temporary debug log showed scroll offset ≈ 0 at rest and the expected content height. The log and a temporary launch-argument hook were removed before committing.
- **Not exercised:** the simulator tooling here can't send touches, so swipes, flicks, rubber-banding, catching mid-flight, tap-outside, the action reveal while scrolling, Reduce Motion and VoiceOver were not tried by hand. Worth a pass on a device.

## Known limits / follow-ups

- No hand-off from the drawer's drag into scrolling within one gesture: after growing to the top detent, the same drag doesn't continue as a scroll.
- iOS 17: content drags don't move the drawer (handle band only).
- A drawer can't be caught while it is closing (hit-testing is off). Setting `isPresented` back to true mid-close re-opens it from where it is.
- The corner radius is a fixed 44 pt on Face ID iPhones, not derived from the display.
