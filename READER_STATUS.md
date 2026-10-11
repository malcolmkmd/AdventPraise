# Reader: chorus style, hymn swipes, pinch to zoom

Branch `reader`. `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with no warnings (Xcode 27.1, Swift 6). I installed it on the "AP Reader 17 Pro" simulator (iOS 27.0) and took screenshots of the reader in Paper (serif), Black (sans, saved pinch size) and Sepia (large print, centred), and of church mode on a chorus. No tests, as briefed.

## 1. Chorus / refrain

- **Typeface:** the chorus is bold italic in a different family from the verses, and both families ship with iOS and have a real bold italic (`DS.ReadingFont.chorusFace`):
  - Serif (New York) verses → **Avenir Next Bold Italic** chorus.
  - Sans (SF) verses → **Baskerville Bold Italic** chorus.
  - `chorusSizeRatio` (0.92 / 1.06) evens out the x-height, so the chorus doesn't look bigger or smaller than the verses. Leading uses the same formula as the verses.
- **Treatment (no box):**
  - Left-aligned: a thin brass rule (`ChorusRule`) runs down the chorus's leading edge. The rule lines up with where the verse text starts (past the numerals, and it grows with the badge in large print). The chorus text is indented past the rule, with the hymnal's own label ("Chorus", "Coro", "Ciindululo", …) as a brass eyebrow above it.
  - Centred: the rule becomes a short brass dash above the label.
- **Contrast:** the lyric uses the surface's full foreground colour. The label and rule use `surface.brass`, which is the AA-tuned brass for each surface (`brassDeep` on Sepia, `brassOnDark` on Muted/Black).
- **Dynamic Type:** the chorus goes through `DSLyricText`, so it scales by the step × Dynamic Type multiplier (capped per scale). It uses `Font.custom(_, fixedSize:)` so the scaling isn't applied twice.
- **VoiceOver:** reads "Chorus" in the system language, followed by the lyric, whatever the hymnal calls it. Church mode does the same.
- **Church mode:** the chorus slide uses the same face (bold italic Avenir Next against the semibold New York verses), with a 3 pt brass-on-dark rule beside the label and text.
- **Design reference:** I couldn't read `../design/Components/` from this session (outside the sandbox). I worked from the in-app copies in `AdventPraise/Design/`, which STATUS.md says came from there.

## 2. Swiping between hymns (reader)

- **Direction:** swipe left for the next hymn, right for the previous. The text follows your finger, slides out, and the new hymn slides in from the other side, with a light haptic. With Reduce Motion it cross-fades instead.
- **Order:** follows the running playlist. `ReaderModel.upcomingHymn` / `precedingHymn` move through the playlist, and fall back to number order at the ends. `goToPreviousHymn` now steps back through the playlist instead of dropping it.
- **At the end of the hymnal or playlist:** the text pulls only slightly (rubber band), springs back, and gives a rigid haptic.
- **Not conflicting with:**
  - Vertical scrolling: the axis is fixed on the first movement (horizontal must be at least 1.4× vertical).
  - The system edge: swipes that start within 24 pt of the leading edge are ignored (back swipe, iPad sidebar).
  - Pinching.
  - Church mode: it is a separate full-screen cover and keeps its own verse swipes.
  - Text selection: the reader has none.
- **VoiceOver:** the hymn title is adjustable (swipe up = next hymn, down = previous). "Next hymn" / "Previous hymn" actions are on every verse and chorus, and the new hymn is announced. The existing "Read full screen" and "Church mode" actions moved onto the elements too. Before, they were on the text column, which isn't an accessibility element.

## 3. Pinch to zoom (reader and church mode)

- **Live and persisted:** `MagnifyGesture` changes the lyric size as you pinch, then keeps it on release.
  - Reader: saved in the existing reading-settings snapshot as `pointSize`, alongside `sizeIndex`. `DSReadingStyle.pinchedPointSize` holds it, and the Appearance slider shows the nearest step. Moving the slider, the ± buttons or the print scale clears the pinched size.
  - Church mode: saved as `worshipPointSize`.
- **Limits:** `DS.LyricScale.pinchRange` sets them: standard 14–32, large print 24–48, worship 30–80 pt, before Dynamic Type. You get a light haptic each time the pinch reaches a limit.
- **Double-tap resets to the default size.** The double-tap only listens while the size isn't the default, so the single tap (focus mode, or tapping through verses in church) isn't delayed in normal use.
- **Gesture conflicts:** pinching uses two fingers, so it never competes with scrolling. Swipes and taps are ignored while pinching and for 300 ms after.
- **Church-mode fix:** the A−/A+ buttons used to change a value nothing read. They now move `worshipPointSize` to the next worship step (36/42/48/56/64). Church text still shrinks to fit the space between the controls, so zooming in on a long verse may not make it look bigger.

## Not verified

- I couldn't perform swipes, pinches or double-taps in the simulator: there's no touch-injection tool (idb/axe) here. I checked the gesture code by reading it and checked layout with screenshots. On a device, check:
  - Paging while scrolling.
  - Pinch inside the ScrollView on iOS 17 and on iOS 26+.
  - VoiceOver adjustable on the title.
- For the screenshots I set UserDefaults on the simulator, and briefly used a temporary launch argument to open church mode on a chorus. It has been removed and is not in the commit.
- Build output and screenshots are in `build/` (git-ignored).
