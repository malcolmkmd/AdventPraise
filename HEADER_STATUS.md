# Header — status

Branch `header`. The hymn reader has a scroll-driven header: at rest the number and title sit large at the top of the text, and as you scroll they collapse into a compact number + title capsule pinned in the navigation bar. After every commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise` built for the iOS Simulator with no Swift warnings (Xcode 27.1, Swift 6). Screenshots were taken on an iPhone 17 Pro and an iPad Air 11-inch (M3) simulator, both iOS 27.0. This harness can't send touches, so anything that needs a finger is marked **not tested by touch**.

## What it does

### At rest

- **Left-aligned:**
  - The hymn number is large (46 pt New York, regular weight, brass, scales with Dynamic Type).
  - The title is below it, in the existing `hymnTitle` style.
  - Below that is an eyebrow: hymnal name · other hymnals' numbers. The number left the eyebrow because it now has its own line.
- **Centred:** a title page, top to bottom:
  - the hymnal name (brass eyebrow),
  - the big number,
  - the balanced title,
  - the other hymnals' numbers.

### Scrolling

- **The large header** shrinks to 86 %, lifts 10 pt and fades. It shrinks toward the top leading corner, or the top centre when centred.
- **The compact header** fades into the bar about halfway through. It starts slightly large and 8 pt low, and settles into place.
  - Its weight runs continuously from regular to semibold as it lands. The system serif is variable, so the in-between weights are real ones, quantised to 12 steps.
  - Its glass capsule fades in over the last stretch: Liquid Glass on iOS 26, `DSGlass` material + hairline on iOS 17–25.
- **Collapse distance:** the large header's own height, so the compact header lands as the title leaves.
- **Scrolling back** reverses it exactly. Every value is a function of the scroll offset; there are no timed animations.

### Placement

- **Left-aligned:** the compact header is the bar's leading item, hugging its content.
- **Centred:** it is the principal item.
- **Width:** never wider than the bar minus room for the globe (both sides when centred). Long titles truncate with "…"; there is no marquee.

### Tapping the compact header

Scrolls back to the top, with the header at rest.

## Requirements

### Alignment

Left and centred both checked by screenshot, on iPhone and iPad. The two placements are separate toolbar items, so flipping the setting moves the header.

### Dynamic Type

- The large header follows Dynamic Type freely; checked at AX XL.
- The compact header follows it up to `accessibility1` and then stops, because the bar's height is fixed. Checked at AX XXXL: it fits.

### Long titles

"Redeemed! How I Love To Proclaim It!" truncates inside the capsule, clear of the globe.

### Church mode

Untouched. `ChurchModeView` and the church presentation files have no changes.

### Swiping between hymns

- When a page swipe starts, the compact header fades out with the old hymn.
- The new hymn opens fully at rest, with nothing left over.
- **Bug found and fixed:** the "top" scroll anchor was the header, which sits below the column's 12 pt top padding. So every new hymn opened a few points into the collapse. The anchor is now the padded column.
- **How it was checked:** a temporary, uncommitted trigger called the real `page(.forward)` after scrolling. I took screenshots before and after.

### Reduce Motion

- The large header doesn't scale or fade; it just scrolls.
- The compact header crossfades in (0.2 s) once the collapse passes 60 %.
- Checked by screenshot before and after the threshold.

### Performance (60/120 fps)

- **Who reads the progress:** it lives in an `@Observable` `HeaderMorph`. Only two small views read it: the large header's `HeaderCollapseEffect` modifier and the compact header. The reader itself never re-renders while scrolling.
- **No updates deep in the text:** progress is clamped, and updates under 0.002 are dropped. Once you're past the header, scrolling sets nothing.
- **No layout changes:** the large header moves by scale, offset and opacity only, so the text never re-lays out.
- **The bar never re-measures:** the compact header's width comes from a hidden semibold copy of its line. The weight steps draw over that copy, so the bar never re-sizes the item while you scroll.

### Scroll tracking

- **iOS 18+:** `onScrollGeometryChange` (`contentOffset.y + contentInsets.top`).
- **iOS 17:** `onGeometryChange` on the scroll content's `.scrollView` frame. It is 0 at rest, because the insets are already applied.
  - The first version also subtracted the top inset, which was wrong. I logged the real values and simplified it.
  - With `-uiDebugLegacyHeader YES` (forces this path on any OS), it matches the iOS 18 path frame for frame at the same offset.

### Navigation bar

- **Edge style:** a custom title view switches the iOS 26 bar to its hard edge, an opaque band with a hairline. The reader sets `scrollEdgeEffectStyle(.soft, for: .top)`, so the soft fade stays and the capsule's glass is the only backdrop.
- **Bar title:** the hymn title still names the window on iPad (Stage Manager, app switcher). It is no longer drawn in the bar, because the compact header is the title now:
  - left-aligned: `toolbar(removing: .title)`, iOS 18+;
  - centred: the principal item replaces it.

### Accessibility

- **VoiceOver:** reads the large header as before ("Hymn n, title", adjustable for next/previous hymn). The big numeral and the compact header are hidden from it, so nothing is read twice.
- **Focus mode:** the compact header goes with the rest of the chrome.

## Files

- `AdventPraise/Reader/HymnHeaderMorph.swift` (new) contains:
  - the `HeaderMorph` progress model,
  - scroll tracking for iOS 18 and iOS 17,
  - the large-header effect,
  - `CompactHymnHeader` and its toolbar item,
  - the soft scroll edge and title helpers,
  - the DEBUG scroll launch argument.
- `AdventPraise/Reader/HymnReaderView.swift`:
  - the new rest header (big numeral),
  - wiring the morph in,
  - the scroll-to-top anchor,
  - hiding the compact header while paging.
- `AdventPraise/App/DebugLaunch.swift`: `-uiDebugScroll 120` (open the reader scrolled 120 pt) and `-uiDebugLegacyHeader YES`.

## Commits

1. Reader: scroll-driven header that collapses into the bar
2. Reader: scroll-to-top lands with the header fully at rest
3. Reader: compact header leads for left-aligned text, sizes once
4. Reader: centred compact header shows; Dynamic Type cap reaches its font
5. HEADER_STATUS (this file)

## Not verified

- **Real scrolling with a finger, and the frame rate.** There is no touch injection here, so every screenshot is a fixed offset set with `-uiDebugScroll`. The structure is built to avoid per-frame layout (see Performance), but I haven't profiled it in Instruments. On a device, please check:
  - a fast flick through the header,
  - a slow drag that stops mid-collapse,
  - the rubber band at the top.
- **Not tested by touch:**
  - tapping the compact header to scroll to the top,
  - a page swipe while collapsed (the paging path itself was exercised in code, see above).
- **iOS 17 and iOS 18–25:** there are no such runtimes here (only iOS 27).
  - The iOS 17 tracking path was checked on iOS 27 by forcing it.
  - The material fallback for the capsule is the existing `DSGlass` fallback, so I didn't screenshot it.
  - On iOS 17 the bar's title is cleared rather than removed, so iPad's window title there is the app name.
- **The two titles overlap briefly.** At the midpoint of the morph, the fading large title and the arriving compact one share the bar for a few points of scroll. This is by design: it is a crossfade, not a shared-element flight.
- **Screenshots** are in `build/shots/` (git-ignored): `header-rest.png`, `header-mid.png`, `header-collapsed.png`. Earlier rounds (centred, Black, AX sizes, iPad, Reduce Motion, iOS 17 path) are in `build/`.
