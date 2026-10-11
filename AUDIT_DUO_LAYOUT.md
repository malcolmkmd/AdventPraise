# Duo / dual-pane layout audit — Advent Praise 7

Branch `duo`, 11 Oct 2026. Xcode 27.1 (iOS 27.1 SDK), Swift 6 language mode, complete strict concurrency, iOS 17.0 deployment target.

**Scope:** the code that decides between one pane and two, and everything that depends on that decision:

- `App/RootView.swift`: the split view or stack, and the sidebar
- `Reader/HymnReaderView.swift`, `Reader/LecternView.swift`, `Design/ReaderToolbar.swift`
- `Drawer/AdventDrawer.swift`, `Features/ChurchModeView.swift`
- the app scene (`App/AdventPraiseApp.swift`) and the generated Info.plist

The audit covers size-class and width gating, iPad windowing (Split View, Slide Over, Stage Manager, free-form windows), rotation, Dynamic Type, keyboard and pointer, glass, safe areas, Swift 6 concurrency, iOS 17 vs 26+ fallbacks, and the new iPhone Duo foldable.

**Verified on:**

- iPad Pro 11-inch (M5), iOS 27.0
- iPhone 17 Pro, iOS 27.0
- iPhone Duo, iOS 27.1, cover display only. The simulator stayed folded, and `simctl` can't unfold it.

Screenshots were taken after the fixes below.

## What's already right

- **No deprecated layout APIs.** There's no `NavigationView`, `UIScreen.main`, `UIDevice.userInterfaceIdiom`, orientation lock or `UIRequiresFullScreen`. All orientations are allowed on iPad, and portrait plus both landscapes on iPhone, so the app takes part in Stage Manager and free-form windowing.
- **Layout follows the size class of the window, not the device.** `RootView` switches on `horizontalSizeClass`, so a compact-width iPad window (Slide Over, narrow Split View or Stage Manager window) correctly gets the iPhone layout.
- **The reading column is capped by a measure** (`DS.Space.readingMeasure`), not a device check, so it reads well at any width.
- **The drawer measures its container** with `onGeometryChange` (container size plus safe-area insets), not the screen.
- **Liquid Glass is gated with `#available(iOS 26, *)`** and has `dsGlass` material fallbacks for iOS 17–25. The toolbar language menu deliberately drops its own capsule on iOS 26 to avoid glass on glass (`Design/LanguagePicker.swift:110-121`).
- **Hardware keys already work in some places.** The number pad takes digits, Delete and Return (`Design/HymnNumberPad.swift:59-66`). Church mode takes the arrow keys, Space, Page Up/Down and Esc (`Design/WorshipModeControls.swift:57-69`).
- **Dynamic Type is capped only where chrome must fit:**
  - the Lectern at accessibility2 (`ReaderToolbar.swift:66`)
  - the number pad at accessibility3
  - the worship controls at accessibility2
  - Lyrics scale freely, and `HymnRow` switches layout for accessibility sizes.
- **The sidebar shows which hymn is open:** `HymnRow` exposes `.isSelected` to VoiceOver (`Design/HymnRow.swift:46`).
- **Swift 6:** every model is `@MainActor @Observable`. Layout code has no `Sendable` problems, and the build has no concurrency diagnostics.

## Findings, by priority

Effort: **S** < 1 h · **M** half a day · **L** 1–3 days. ✅ = fixed on this branch.

### P1 — wrong behaviour users will hit

**1. ✅ A size-class change dismissed church mode, Mail and the Extras sheets.**
- **Where:** `App/RootView.swift:30-47`, formerly `Reader/HymnReaderView.swift:135-142`.
- **Why:** `RootView` builds two different trees: `NavigationSplitView` for regular width, `NavigationStack` for compact. Each contains its own `HymnReaderView`, so when the size class flips the reader is destroyed and rebuilt. Every presentation attached to it was dismissed with it, including the church-mode `fullScreenCover`. That happens when someone resizes a Stage Manager window, drags the Split View divider, pulls the app into Slide Over, or rotates a Plus/Max iPhone. An iPad on a lectern in Split View could drop out of worship mode mid-hymn.
- **Fix:** the model-driven presentations (`showChurchMode`, `mail`, `extrasSheets`) now hang off `RootView`, above the branch.
- **Effort:** S. The structural fix is #6.

**2. Every window shares one `ReaderModel`.**
- **Where:**
  - `App/AdventPraiseApp.swift:12-21`, `35`
  - `Extras/Extras.swift:22`
  - `Intents/HymnIntents.swift:30,75,92`
- **Why:** `AppServices.shared.reader` is passed to every scene the `WindowGroup` creates. On iPad a second window (Stage Manager, App Exposé "New Window", dragging the app icon into Split View with itself) shows the same hymn. Paging in one window pages both. Opening church mode in one opens it in both, because `showChurchMode` is a model property. The Lectern state, drawers and Extras sheets are shared the same way. The generated Info.plist includes the `UIApplicationSupportsMultipleScenes` key. Its value wasn't read here because the plist tools were blocked; Xcode's SwiftUI default is YES, so confirm with `plutil -p`.
- **Fix:**
  - Create a `ReaderModel` per scene (`@State private var reader = ReaderModel()` in a scene-root view).
  - Keep favourites, recents and playlists in a shared `Library` store that every reader reads.
  - Route App Intents to the active scene's reader. Register readers in an `@MainActor` registry keyed by scene, and prefer the one whose `scenePhase == .active`.
  - Restore the current hymn per scene with `@SceneStorage` (hymnal id plus number), with the UserDefaults value as the fallback for a new window.
  - Stop-gap if per-scene readers wait: set `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO`. This keeps Split View and Stage Manager resizing but removes the second window.
- **Effort:** L (per-scene), S (stop-gap).
- **Not applied:** it changes the App Intents contract.

**3. ✅ The Lectern's library button did nothing on iPad once the sidebar was showing.**
- **Where:** `Reader/LecternView.swift:102-108`, `App/RootView.swift:38-42`.
- **Why:** the button set `revealSidebar`, which only ever forced `.all`. With the sidebar visible (the default) the tap was a no-op. On iPhone the same button toggles the library panel.
- **Fix:** it is now `toggleSidebar`, and the split view toggles between `.all` and `.detailOnly` with animation.
- **Effort:** S.

**4. ✅ Favourites and playlists were at the bottom of the iPad sidebar.**
- **Where:** `App/RootView.swift:99-146`.
- **Why:** they came after a "Hymns" section listing every hymn in the hymnal (hundreds of rows), so on iPad they were effectively unreachable.
- **Fix:**
  - Favourites, then Playlists, then Hymns.
  - Favourites and Playlists are hidden while searching, so results lead.
  - Favourite membership is a `Set` built once per body; it was rebuilt for every row.
  - The search runs once per body.
- **Effort:** S.

### P2 — resizability and platform polish

**5. ✅ The Lectern width cap was gated on the size class.**
- **Where:** `Design/ReaderToolbar.swift:60`.
- **Why:** the 560 pt cap applied only to regular width. A landscape compact iPhone, a wide compact window or the Duo cover screen in landscape stretched the capsule edge to edge (~800 pt), which put the controls out of thumb reach.
- **Fix:** the cap applies always. It doesn't change anything below 560 pt, so iPhone portrait is unchanged.
- **Effort:** S.

**6. Two trees instead of one adaptive container.**
- **Where:** `App/RootView.swift:30-47`.
- **Why:** this is the root cause of #1, and it loses all reader `@State` on every flip: scroll position, an in-progress pinch, page offset, the reader's own Hymnals sheet. Since iOS 17, `NavigationSplitView` collapses to a stack by itself, and `preferredCompactColumn` picks which column shows when collapsed.
- **Fix:** see the target design below. Keep a single `NavigationSplitView`, bind `preferredCompactColumn` to `.detail`, and push back to `.detail` whenever the sidebar opens a hymn.
- **Effort:** M.
- **Not applied:** in compact the system edge-swipe would pop back to the sidebar, which is new iPhone behaviour. It needs a product decision and device testing.

**7. The sidebar is a list of buttons, not a selection list.**
- **Where:** `App/RootView.swift:99-146`.
- **Why:** without `List(selection:)` there's no hardware-keyboard focus and no arrow-key or Return navigation in the sidebar. There's no system selection highlight that follows focus, and no automatic `preferredCompactColumn` handling once #6 lands.
- **Fix:** `List(selection: $selectedHymnID)` with `.tag(hymn.id)` rows, writing through to `model.open(number:)`. Keep `HymnRow`'s look with `listRowBackground`.
- **Effort:** M.

**8. ✅ The iPad sidebar didn't remember being hidden.**
- **Where:** `App/RootView.swift:18-24`.
- **Why:** column visibility was `@State`, so a reader who hid the sidebar for full-width lyrics got it back on every launch or window restore.
- **Fix:** it's now `@SceneStorage("root.sidebarHidden")`, mapped onto `NavigationSplitViewVisibility`.
- **Effort:** S.

**9. ✅ No keyboard shortcuts for the reader itself.**
- **Where:** `App/AdventPraiseApp.swift`, new file `App/ReaderCommands.swift`.
- **Why:** with a Magic Keyboard there was no way to change hymn, favourite one or start church mode, and nothing appeared in the iPadOS menu bar or the ⌘-hold overlay.
- **Fix:** a **Hymn** `CommandMenu`:

  | Command | Shortcut |
  |---|---|
  | Next Hymn | ⌘] |
  | Previous Hymn | ⌘[ |
  | Add or Remove Favourite | ⌘D |
  | Church Mode | ⌥⌘P (Keynote's "play") |

  The labels are static, and there's no `.disabled` at the ends of the hymnal (the actions are no-ops there). This avoids depending on `Commands` re-evaluating when the `@Observable` model changes, which hasn't been verified on iOS 17.
- **Effort:** S.
- **Follow-up:** ⌘F to focus sidebar search (needs `searchFocused`, iOS 18+, gated), and ⌘L for the number pad.

**10. Drawer and popover metrics key off the size class.**
- **Where:** `Drawer/AdventDrawer.swift:261-275`, `Reader/LecternView.swift:60,94-108`.
- **Why:** the card width (540 / 600), corner radius, side inset, top clearance and pad-as-popover all switch on `horizontalSizeClass`. That's acceptable on iPad. It's wrong on the Duo cover display and on a landscape compact phone, where height, not width, is the constraint.
- **Fix:** derive these from the measured container (`container.size`) and its insets. For example, popover the pad when the container height is under ~500 pt, whatever the width.
- **Effort:** M.

**11. On the Duo cover display the What's New drawer runs into the top edge.**
- **Where:** `Drawer/AdventDrawer.swift:274-276`.
- **Why:** on the Duo cover display the sensor housing sits in a column on the trailing edge, so `insets.top` is about 0. `maxHeight` then leaves only 10 pt of clearance (`- insets.top - 10`). In the simulator the card's top corners and close button sit against the top of the display.
- **Fix:** clear the top by `max(insets.top, DS.Space.l)` and the rounded display corner. Better: read `ReservedRegion` occlusions (iOS 27.1) so the card avoids the housing itself rather than inferring it from insets.
- **Effort:** S–M.
- **Not applied:** it needs on-device checking across iPhone, iPad and Duo.

**12. Reader paging has hard-coded geometry.**
- **Where:** `Reader/HymnReaderView.swift:28,206`.
- **Why:** `pageWidth` starts at 390 (an iPhone width) until the first geometry callback. It is now `onGeometryChange` (✅), so it updates on every resize. The "leading edge belongs to the system" band is a fixed 24 pt measured from the left: it ignores right-to-left layouts, and in the split view's detail column there's no system edge gesture to protect.
- **Fix:** use `layoutDirection` for the edge, and drop the guard when the reader is the detail column.
- **Effort:** S.

**13. Church mode's tap zones are physical left and right.**
- **Where:** `Features/ChurchModeView.swift:50`.
- **Why:** the left third goes back. That's correct for the current left-to-right hymnals, but a right-to-left hymnal would read backwards. The `GeometryReader` here is a legitimate use: it sizes text to the space available.
- **Fix:** flip on `layoutDirection`.
- **Effort:** S.

### P3 — modernisation and hygiene

**14. iPhone Duo (iOS 27.1) layout APIs aren't used.**
- **Where:** `App/RootView.swift`.
- **Why:** the 27.1 SDK (SwiftUICore, `intro 27.1`) adds:
  - `ArrangementView(primary:secondary:)`, styled with `.arrangementViewStyle(_:)` using `AutomaticArrangementViewStyle`, `SplitArrangementViewStyle` or `OverlayArrangementViewStyle` (each with `.axes(_:)`), and sized with `splitArrangementLayoutRatio` / `splitArrangementLayoutSize`
  - `DeviceHinge` / `onHingeChange(isEnabled:_:)` (status `.closed` / `.partiallyOpen` / `.fullyOpen`, plus angle)
  - `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` (kinds `.occlusion`, `.division`)
- **Today on the Duo:**
  - **Folded (checked):** the cover display gets the compact iPhone layout, which is right. Its sensor housing is a column on the trailing edge (see #11).
  - **Unfolded (not checked):** `simctl` can't unfold the simulator. Nothing in the code keeps the reading column off a `.division` region; it centres on the window, so it can straddle the crease.
- **Fix:** see the target design. Gate on `#available(iOS 27.1, *)`.
- **Effort:** M–L.

**15. The Hymnals sheet is built twice.**
- **Where:** `App/RootView.swift:155-171`, `Reader/HymnReaderView.swift:110-125`.
- **Fix:** make it one `HymnalsSheet` view.
- **Effort:** S.

**16. Pointer hover isn't customised on custom chrome.**
- **Where:** `Design/GlassButton.swift`, `Design/ReaderToolbar.swift`.
- **Why:** buttons get the default effect, but the Lectern's title area and handle are `contentShape` hit areas with no `.hoverEffect`. On iPad with a trackpad they don't highlight.
- **Fix:** add `.hoverEffect(.highlight)` on the handle and title button, and `.lift` on the play, jump and library buttons. On iOS 26 glass buttons already respond.
- **Effort:** S.

**17. iPhone Plus/Max in landscape is regular width.**
- **Where:** `App/RootView.swift:30`.
- **Why:** these phones get the iPad split view in landscape: a 280–420 pt sidebar and about 500 pt of lyrics. Fine, and arguably good, but untested.
- **Fix:** check on a Max simulator. If the reading column gets too narrow, prefer `.prominentDetail` there.
- **Effort:** S.

**18. Unstructured `Task`s in reader gestures.**
- **Where:** `Reader/HymnReaderView.swift:186-189,257-266`.
- **Why:** they're main-actor inherited and short, so they're safe under Swift 6, but they aren't cancelled if the view goes away mid-animation (more likely now that #1 shows the reader can be torn down).
- **Fix:** if this ever matters, hold them in `@State var settleTask: Task<Void, Never>?` and cancel on disappear.
- **Effort:** S.

## Target design for the duo layout

```
RootScene (per window)
 └─ ReaderScene(reader: ReaderModel (per scene), library: Library (shared))
     ├─ iOS 27.1+, device has a hinge / division reserved region:
     │    ArrangementView {
     │        HymnSidebar            // primary: library pane
     │    } secondary: {
     │        HymnReaderView         // secondary: lyrics pane
     │    }
     │    .arrangementViewStyle(.automatic)   // split when unfolded, overlay/compact when folded
     │    .onHingeChange { _, new in … }      // .partiallyOpen → "tent"/book posture:
     │                                        //   lyrics on one half, Lectern on the other
     └─ otherwise:
          NavigationSplitView(columnVisibility: $sidebarVisibility (SceneStorage),
                              preferredCompactColumn: $compactColumn (.detail)) {
              HymnSidebar(selection: $reader.selectedHymnID)   // List(selection:)
          } detail: {
              HymnReaderView                                   // one identity at every size
          }
          .navigationSplitViewStyle(.balanced)
     + .sheet / .fullScreenCover for church mode, Mail, Extras at this level
     + .commands { ReaderCommands } routed through @FocusedValue(\.reader)
```

**Principles:**

1. **One identity for the reader at every width.** The split view or arrangement collapses and expands around it, so no state or presentation is lost on resize, rotation, Slide Over or fold.
2. **Width decisions come from the container, not the device.** Size class picks the structure (one pane or two). Component metrics such as the Lectern cap, drawer card width and popover-vs-inline pad come from the measured size (`onGeometryChange`, `containerRelativeFrame`) and reserved regions.
3. **Per-window state:**
   - Each window gets its own reader, with selection restored through `@SceneStorage`.
   - Shared data (favourites, playlists, purchases, settings) lives in app-wide stores.
   - Commands reach the focused window's reader through `@FocusedValue`, so ⌘] pages the window you're in.
4. **Hinge-aware on Duo:**
   - Query `reservedRegions(kind: .division)` and keep the reading measure entirely on one side of the crease.
   - When half-open, use the lower half for the Lectern or church-mode controls and the upper half for lyrics.
   - Query `.occlusion` so drawers and the Lectern avoid the cover display's sensor column.
5. **Glass stays system-owned on iPad.**
   - The sidebar uses `.listStyle(.sidebar)`, which gets iOS 26 glass automatically.
   - Toolbar items don't add their own glass.
   - The Lectern stays the one custom glass surface. On iOS 17–25 the existing `dsGlass` material fallbacks stay.
6. **Fallbacks:**
   - iOS 17–26: `NavigationSplitView` path.
   - iOS 27.1+ with a hinge: `ArrangementView`.
   - Gate with `#available(iOS 27.1, *)` and keep the `NavigationSplitView` path as the tested default.

## Fixes safe to apply now

| # | Change | Status |
|---|---|---|
| 1 | Present church mode, Mail and Extras from `RootView` | ✅ applied (`40d46d8`) |
| 5, 12 | Lectern cap at every width; `onGeometryChange` for page width | ✅ applied (`2949791`) |
| 3, 8 | Library button toggles the sidebar; sidebar visibility in `@SceneStorage` | ✅ applied (`8dc5421`) |
| 4 | Favourites and playlists above the hymn list; per-body search and favourite set | ✅ applied (`d174192`) |
| 9 | Hymn command menu (⌘] ⌘[ ⌘D ⌥⌘P) | ✅ applied (`1670dac`) |
| 15 | Single `HymnalsSheet` | safe, not applied (refactor only) |
| 16 | `.hoverEffect` on the Lectern handle and title | safe, not applied (needs a pointer check on device) |
| 11 | Drawer top clearance `max(insets.top, DS.Space.l)` | needs device check first |

Not safe without a decision or device testing: #2 (per-scene readers / App Intents routing), #6 (single `NavigationSplitView` on iPhone), #7 (selection list), #10 (metrics from container size) and #14 (Duo arrangement).
