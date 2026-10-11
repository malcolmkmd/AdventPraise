# AdventPraise 7.0: polish pass (branch `polish`)

A SwiftUI and design audit of the whole app. The focus was Liquid Glass usage, motion, hit targets and view structure. It also adds the Lectern handle and makes the hymn title more obviously tappable. Features work as before; any small visible differences are listed under **Behaviour notes**.

**Build:** a clean `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeds with **0 warnings**, package targets included (Xcode 27.1).

**Simulator check:** iPhone 17 Pro, iOS 27.0, on a dedicated simulator ("AP Polish 17 Pro"). Screens checked:
- What's New.
- The reader with the Lectern collapsed.
- The hymn tray open.
- The library panel.
- Church mode.

There's no touch-injection tool on this machine, so open states were shown by temporarily changing `ReaderModel`'s initial state. Those changes were reverted and not committed.

Skill rules cited below come from the installed skills: swiftui-expert-skill, swiftui-liquid-glass, swiftui-view-refactor, apple-design, better-interface and better-accessibility.

## Changes, and the rule behind each

### Motion: the Lectern is no longer bouncy (`DesignTokens.swift`)
- **Motion tokens.**
  - What changed: `DS.Motion.lectern` was `spring(0.45, bounce 0.25)` and is now `easeOut(0.3)`. `focus` and `select` are now ease-out. `press` was `spring(0.2, bounce 0.35)` and is now `easeOut(0.12)`.
  - Rule: no overshoot on frequent, small chrome changes; use short, critically damped or ease-out curves. Springs with bounce are for gestural throws, not taps (apple-design motion; swiftui-expert *Animations*).
- **`DSPressStyle`.**
  - What changed: press scale went from 0.94 to 0.97, plus a 0.75 dim. Under Reduce Motion only the dim remains.
  - Rule: subtle press feedback (better-interface). Respect Reduce Motion (better-accessibility).
- **GlassButton's iOS 17–25 fallback.**
  - What changed: the same subtle press, 0.97 scale.
  - Rule: consistent feedback across the system.

### Glass only on the control layer, never on content
- **Glass removed from content:**
  - The current-verse badge (`ChapterVerseBlock`).
  - The current chorus label (`ChorusBlock`).
  - The lock/price pill in hymnal rows (`PaywallLanguageRow`).

  Each now uses the opaque brass wash on every OS version. Rule: Liquid Glass belongs to the navigation/control layer that floats above content, not to the content itself (swiftui-liquid-glass *Review: where glass should not be used*; apple-design *materials hierarchy*).
- **What's New feature tiles.**
  - What changed: they were `GlassCard`s and are now opaque raised Stage cards with a hairline. Only the pinned actions (Try Worship Mode, Continue) stay glass.
  - Rule: same as above. The tiles are informational content.
- **`HymnRow.floating`.**
  - What changed: the interactive-glass row style was removed (only a preview used it). The doc comment says rows are never glass.
  - Rule: list rows are content.
- **`GlassCard` doc comment.** It now restricts the component to transient control-layer HUDs.

### No glass on glass
- **New `\.dsOnGlass` environment flag.**
  - Who sets it: `DSGlass`, the Lectern (`LecternGlass`) and the iPad number-pad popover.
  - What it does: `GlassButton` reads it. Inside glass, iOS 26 uses `.borderedProminent` / `.bordered` instead of `.glassProminent` / `.glass`. On iOS 17–25 it uses plain fills instead of a second material.
  - Buttons affected: the pad's **Go**, the Lectern's **New playlist**, and **Unlock all** in the Hymnals panel.
  - Rule: never stack glass on glass; controls inside a glass surface use non-glass styles (swiftui-liquid-glass, swiftui-expert *Liquid Glass*).
- **Lectern.** Removed the `GlassEffectContainer` wrapping its single glass shape. A container only matters when several glass shapes sit near each other.
  - Rule: use `GlassEffectContainer` when multiple glass elements coexist.
- **iPad number-pad popover.**
  - What changed: the pad no longer draws its own glass panel inside the popover; the popover is the chrome.
  - Rule: no glass on glass.
- **`LanguageMenuButton` (iPad toolbar).**
  - iOS 26: the label no longer draws its own interactive glass capsule. The navigation toolbar already wraps items in glass.
  - iOS 17–25: a quiet inset capsule instead of a second material on the bar.
  - Rule: toolbars own their glass (swiftui-expert *Toolbars*).
- **Standalone `HymnNumberPad` and `LanguagePicker`.** They now go through `dsGlass`, so they get the flag and the Reduce Transparency fallback automatically.

### Native glass button styles and ButtonBorderShape
- **Worship controls (`WorshipModeControls`).**
  - What changed: previous, next, leave and text size are now `Button`s with the system `.glass` / `.glassProminent` styles and `.buttonBorderShape(.circle)`. Before, they were plain buttons with hand-applied `glassEffect` circles.
  - Sizing: the label is sized so the circles still measure 72 pt (previous/next) and 52 pt (the rest). This was checked in the simulator.
  - Rule: prefer native glass button styles and `ButtonBorderShape` over hand-rolled glass backgrounds (swiftui-liquid-glass *Implementation checklist*).
- **Tint semantics.**
  - What changed: only **Next verse** is `.glassProminent`, as the one primary action on that screen. Elsewhere `.glassProminent` / `.borderedProminent` is kept for one action per screen: Go, Unlock all, and Try Worship Mode.
  - Rule: prominence marks the single primary action.
- **Grouping.**
  - What changed: the worship controls sit in one `GlassEffectContainer` with 8 pt spacing. The two text-size buttons (4 pt apart) blend into one pill; leave, the title pill and previous/next stay separate.
  - Rule: group nearby glass controls in a container and tune its spacing.
- **Disabled worship controls.** Dimmed explicitly, because the system's disabled glass was too faint to read (checked on "Verse 1 of 4").
- **Title pill.** It is informational, so it uses non-interactive glass (`.interactive()` was removed).
  - Rule: use `.interactive()` only where there's interaction.
- **`GlassButton` internals.**
  - Shape now comes from a single `buttonBorderShape`.
  - The icon label is sized so the circle lands at about 44 pt in either style: about 50 pt measured inside the Lectern.

### Reduce Transparency and the iOS 17–25 fallback
- **Appearance sheet.** On iOS 17–25 it uses the opaque `surface.elevated` instead of `.regularMaterial` when Reduce Transparency is on. iOS 26 keeps the system sheet, which handles this itself.
- **What's New.** With Reduce Transparency on iOS 26, the Stage presentation background and the action scrim go opaque.
- **Already correct, kept as is:**
  - `DSGlass` (opaque `elevated` fill on iOS 17–25).
  - `GlassButton`'s fallback (now via one `raisedFill` helper).
  - Worship controls' fallback (always opaque).
  - System glass on iOS 26, which adapts to Reduce Transparency on its own.

### Lectern: expand handle (new)
- **The handle.** A `chevron.up` handle sits at the top of the capsule (`LecternHandle` in `ReaderToolbar.swift`).
  - Tap: expands to the hymn tray (the fuller settings view), or collapses whatever panel is open.
  - Swipe: up expands, down collapses.
  - Animation: the chevron rotates to point down with the Lectern's ease-out. Under Reduce Motion the glyph swaps instead of rotating.
- **Hit area.** The visible strip is 18 pt, but the content shape is 114 × 44 pt.
  - Rule: 44 pt minimum hit targets (apple-design, better-accessibility).
- **VoiceOver.** The handle reads as "Settings panel", value Collapsed/Expanded. Its hint mentions the swipe, and named **Expand** / **Collapse** accessibility actions are provided.
  - Rule: give custom controls a label, value, hint and actions (better-accessibility).
- **Swipes reach the handle.** The handle has its own simultaneous swipe gesture, so a drag that starts on it isn't swallowed by the button.
- **Duplicate swipes are harmless.**
  - The new `onExpand` callback only opens the tray when the Lectern is collapsed.
  - `ReaderModel.closeLectern()` now does nothing when the Lectern is already collapsed.

### Lectern: the hymn title says it opens settings
- **New `HymnHandleButton`.**
  - Affordance: an `ellipsis.circle` sits at the trailing edge of the title. It fills and takes the tint while the tray is open.
  - Pressed state: `LecternRowPressStyle` adds a quiet fill and a 0.98 dip with a 0.12 s ease-out.
  - VoiceOver: the button trait is now explicit. It was lost to `.accessibilityElement(children: .ignore)`.
  - Hint: "Opens hymn settings: save, church mode, hymnal, text size and more".
  - Rule: make hidden affordances visible; tappable things look and announce as buttons (better-interface, better-accessibility).

### View structure and data flow
- **`LecternView` split up (swiftui-view-refactor).**
  - Before: 500 lines, with every panel a computed property.
  - Now: the panels are separate views in `Reader/LecternPanels.swift`: `LecternHymnTray`, `LecternSearchPanel`, `LecternLibraryPanel` (with `PlaylistRow`) and `LecternMorePanel`.
  - Rule: split large bodies into subviews; each view is an invalidation boundary that only reads what it needs (swiftui-expert *View composition*).
- **Search focus.** The `@FocusState` moved into the search panel and is set on appear. Before, the parent held it and set it from an `onChange` on the Lectern state. The panel only exists while search is open, so the behaviour is the same.
- **Shared hymnal picker.**
  - Before: three copies of the LanguagePicker wiring and its access/select logic (reader sheet, iPad sidebar sheet, Lectern Hymnals panel).
  - Now: one `HymnalStorePicker`, plus `PurchaseStore.access(for:current:)` and `ReaderModel.select(_:store:then:)`.
  - Each caller keeps its own close timing: the reader sheet closes on tap, the sidebar sheet after the switch, and the Lectern doesn't close.
  - `HymnSidebar` no longer needs `@Bindable` or the store.
- **Lyric block identity.**
  - Before: `ForEach(Array(blocks.enumerated()), id: \.offset)`.
  - Now: `ReaderBlock` ids, where the nth verse is `v n` and the nth chorus is `c n`. Turning on "Chorus after every verse" no longer shifts the identity of every later block.
  - Rule: never use `.offset` / `.indices` for ForEach identity (swiftui-expert correctness checklist).
- **Church mode auto-hide.**
  - Before: a detached `Task` with a manual generation check.
  - Now: `.task(id: hideGeneration)`, which SwiftUI cancels and restarts.
  - Rule: tie async work to view lifetime with `.task` (swiftui-expert, swift-concurrency).

### Hit targets, spacing, symbols
- **Chips.** The Lyrics/Titles chips and the number pad's recent-hymn chips keep their 32 pt capsule look but get a 44 pt tall hit area.
- **Tray tiles.** The icons sit in a fixed-height `@ScaledMetric` slot, so the five labels line up; before, the ellipsis and "Aa" made them sit at different heights. The icon font is now `.title3` (Dynamic Type) instead of a fixed 20 pt. `.isSelected` is announced on the Save tile.
- **Playlist rows.** They use `DSPressStyle` for press feedback, with a matching content shape.
- **More panel.** The title is marked as a header.
- **List heights.** `DSFittingScroll` (a tiny `Layout`) makes favourites and search results only as tall as their content, capped as before at 300 / 260 pt. Previously a ScrollView under `.frame(maxHeight:)` always grew to the cap, so an empty favourites list left about 250 pt of blank glass.

## Behaviour notes (intentional, small)
- **Haptics.** `closeLectern()` no longer plays a haptic when the Lectern is already collapsed. On iPad, closing the number-pad popover with the jump button used to fire one anyway.
- **Panel sizes.** The Lectern grows by the handle's 18 pt. Short favourites and search lists make the panel shorter than before.
- **Disabled worship controls on iOS 26.** They now use the system glass button's disabled appearance plus the dim, instead of a dimmed custom circle.

## Not done / not verified
- **Morphing with `glassEffectID`.** Not added. No glass element in the app is inserted or removed with animation where morphing would help: the worship controls fade as a group and the Lectern is a single shape that reshapes. Adding conditional insertion just to morph would change behaviour.
- **Gestures and VoiceOver.** Swipe-to-expand/collapse, the handle's VoiceOver actions and press states weren't exercised by touch or VoiceOver in the simulator, because no touch-injection tool was available. Layout and states were checked through screenshots only.
- **iPad and iOS 17–25.** The iPad layout (popover, toolbar menu) wasn't re-checked, and the iOS 17–25 fallback path wasn't run: only the iOS 27 runtime is installed. Both paths compile.
- **Skill reference files.** The skills' long-form reference files couldn't be opened under this session's permissions. The rules above come from the skills' main instructions and checklists.
