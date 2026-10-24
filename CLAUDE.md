# Advent Praise iOS: notes for coding agents

SwiftUI, Swift 6 (complete strict concurrency), iOS 17 minimum. Build with Xcode 27.0
(`DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer`), not the 27.1 beta SDK.
Commit straight to main. Never change build numbers or upload without being asked.

## Design system
- All spacing, type, colour and radii come from `DS` in `AdventPraise/Design/DesignTokens.swift`.
  No magic numbers in views; add a token if one is missing.
- Reading surfaces are applied with `.dsSurface(...)`. Lyrics are capped by `DS.Space.readingMeasure`.
- Liquid Glass only behind `#available(iOS 26, *)`, with the `dsGlass` material fallback for 17–25.
  Never glass on glass.
- Dynamic Type: lyrics scale freely; chrome (Lectern, number pad, worship controls) is capped.
- Models are `@MainActor @Observable`.

## Adaptive layout and iPhone Duo principles
Follow Apple's iPhone Duo / foldable design guidance. In practice:
1. **One narrow layout and one wide layout**, flexing between them. Decide from the size class or
   the measured container, never from the device model. `RootView` is a single
   `NavigationSplitView` for every size, so nothing is rebuilt when the Duo opens or closes.
2. **Lean on system components** (`NavigationSplitView`, `List`, toolbars, menus, sheets). They move to
   the right place on fold and rotate for free.
3. **A path of screens, from general to specific:** library, then hymn, then extras. Narrow shows the last
   screen and wide shows the last two, always in the same order. Think in journeys: what someone was
   doing on the closed screen must still be there, unchanged, when they unfold.
4. **Side by side and full screen**, with one button that switches between them and back
   (the system sidebar toggle or the Lectern library button), remembered per window.
5. **Reachability:** on narrow, the most important actions sit at the bottom, by the thumb (the Lectern).
   On an open Duo the bottom-right corner is hidden by the hand, so keep key controls out of it.
6. **Predictable panels:** side by side is always library and reader. Picking a hymn in the library
   updates the reader and leaves the library where it is.
7. **Intentional toolbars:** show only the most useful buttons. Destructive actions go only in a "…"
   or context menu, or behind a confirmation. Never use a bare toolbar button or a full swipe for them.
8. **Backgrounds may run under bars; text and buttons never do.** Respect safe areas for content and
   ignore them only for background colour.
9. **Judge asymmetric layouts by eye, not just maths:** gutters, margins, and the closed Duo's sensor
   housing on the trailing edge, where `insets.top` can be about 0.
10. **Watch it move:** check the closed, open, rotated and split states, ideally on a device, at full speed
    and slowed down. Try a few variants side by side before choosing.

See `AUDIT_DUO_LAYOUT.md` for the earlier audit and its open items.
