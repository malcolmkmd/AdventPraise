# BARANIM_STATUS — smoothing the Lectern's animations

Branch `baranim`. The "bottom action bar" is the Lectern (`ReaderToolbar`, driven by `LecternView`). This branch makes its parts move continuously between collapsed, hymn tray, number pad / search, library and hymnals. Before, they jumped.

After every commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeded with no warnings. Screenshots were taken on a dedicated iPhone 17 Pro simulator (iOS 27.0, "AP Baranim 17 Pro").

The reader header (`HymnReaderView.swift`) was not touched; the `header` branch is working there.

## What was causing the jumps

- **Four implicit `.animation(_:value:)` modifiers on the bar's containers.** One was in `ReaderToolbar`; three were in `LecternView`, keyed on `lectern`, `libraryTab` and `showsTransport`. Anything else that changed in the same update was animated too, and state changed outside them snapped.
- **`if` insertions of views that exist in every state.** These covered the play button, the divider, the playback bars and the Reduce Motion chevron (an `if/else` between two Images). They popped in and out, and the title shifted when the play button came or went.
- **Panels slid across the row.** `.move(edge: .bottom)` moved an incoming panel up from the bottom of the whole capsule, so mid-transition the new panel was drawn over the title row. This was seen in a screenshot: number pad keys over the title.
- **The number pad's `LazyVGrid`.** Lazy containers stop drawing while being removed, so the keys vanished at the start of a transition while the rest of the pad faded.

## Changes (3 commits)

### 1. One animated transaction (`deebb45`)
- `ReaderModel.lectern` is now `private(set)`. Every write goes through `setLectern(_:)`, which wraps only that write in `withAnimation(DS.Motion.lecternTransition)`. That covers `openLectern`, `closeLectern`, `show` and `edit`. The page behind isn't animated by it.
- `DS.Motion.lectern` is now `spring(duration: 0.35, bounce: 0)`: calm, no overshoot. A spring keeps its velocity when a tap retargets it mid-move.
- `DS.Motion.lecternTransition` gives the same spring, or a 0.2 s cross-fade under Reduce Motion (it reads `UIAccessibility.isReduceMotionEnabled`).
- `LecternView` lost its three implicit animations.
  - The player changes its own state outside any transaction (playback ends, a hymn loads). So `LecternView` keeps a presentation copy (`shownPlayer`: transport strip shown, play button shown). An `onChange` updates it inside the same animation. `model.lectern` remains the one source of truth for panel state.
- The library's Favourites / Playlists picker animates through `$model.libraryTab.animation(...)`.

### 2. `ReaderToolbar`: stable identity and a shared highlight (`1f79179`)
- **Matched geometry.** The open highlight (tint wash) is one shape, shared through a `@Namespace` with `matchedGeometryEffect`. It slides between the title, the jump button and the library button.
  - Under Reduce Motion each button gets its own ID, so the wash fades in place.
  - On iPad the library button is lit by the sidebar, which can show alongside an open panel, so it keeps its own ID there. That avoids two sources for one ID.
- **Stable identity:**
  - One chevron view. It rotates normally; under Reduce Motion it swaps to `chevron.down` with a symbol replace.
  - The divider fades instead of being inserted.
  - The play button is always in the row. Without accompaniment it folds to zero width, fades and ignores touches, so the title slides instead of jumping.
  - `DSPlaybackBars` always stays in the status line, hidden by opacity, and now restarts its breathing when playback starts.
- **Clipped panel slot.** Panels sit in a slot that clips, so they rise out of the row's top edge and never cross it.
- **Glass (iOS 26).** The Lectern's glass is inside a `GlassEffectContainer`. iOS 17–25 keep the existing `dsGlass` fallback.
- **Layout.** No implicit animation on the container. `fixedSize` on the title lines and hymn number stops reflow while the row resizes.

### 3. `HymnNumberPad`: plain `Grid` (`c68d959`)
- 3×4 `Grid` instead of `LazyVGrid`, so the keys fade with the rest of the panel.
- Church mode's standalone pad was checked by screenshot: same layout.

## Why there is no `glassEffectID`
`.glassEffectID` was tried on the Lectern's glass. Mid-transition, its morph moved the content's clip about 40 pt out of step with the layout, and the bottom of the title row was cut off. Two frames from the same moment, with and without the ID, confirmed it. There is only one glass shape, so there's nothing for the ID to merge or split. It was removed; the container stays.

## How it was checked
No touches are possible here, so I used a temporary DEBUG probe (removed before committing). It stepped the Lectern through hymn → pad → library → collapsed → library → hymn → collapsed on a timer, with the spring slowed to 12 s. I then took simulator screenshots mid-transition:

- **Collapsed → hymn tray:** the glass grows, the divider fades in, the chevron turns and the title wash appears.
- **Hymn tray → pad:** the wash slides from the title to the jump button. The pad rises inside the slot while the tray fades out, and the row is untouched.
- **Pad → library:** the keys fade and slide out with the panel. The bookmark swaps to filled and the library fades in.
- **Collapsed → library:** the chevron is caught mid-turn and the bookmark wash fades in.
- **Library → hymn tray:** the wash morphs from the bookmark to the title.
- **Reduce Motion on** (simulator `com.apple.Accessibility ReduceMotionEnabled`): panels cross-fade in place, washes fade in place without sliding, and the chevron uses the `chevron.down` glyph.
- **Real speed (0.35 s):** the settled pad, library and collapsed states look as before.

## Not tested
- **By touch:** swipe-to-expand and interrupting a transition by tapping mid-move.
- **The transport strip appearing and disappearing** (needs Pro playback), and **the play button folding away** when a hymn without accompaniment opens. Both now run in the Lectern's animation through `shownPlayer`, but neither was seen on screen.
- **iPad and the iOS 17–25 fallback** were not run in this pass.
