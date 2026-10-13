# REDESIGN_STATUS — the reader menu at the top, a cleaner Lectern

Branch `redesign`. In the normal reader, the globe now grows into a top action bar: the **reader menu**. It holds Translation, Theme, Text and About. Those settings have left the bottom bar, so the Lectern's tray is now about doing things with the hymn: Church, Memorise, Playlist, Save, More.

After every commit, `xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'generic/platform=iOS Simulator' build` succeeded with no warnings. Screenshots were taken on dedicated simulators, "AP Redesign 17 Pro" and "AP Redesign iPad" (iPad Air 11-inch M3), both iOS 27.0. This harness can't send touches, so anything that needs a finger is marked **not tested by touch**.

## What changed for the user

### The reader menu (top)

- **Closed:** the globe sits where it always did, top right in the navigation bar, in its own glass circle.
- **Opening:** the glass grows out of the globe, leftward and down, into a bar across the top. The ✕ lands where the globe was, so the same spot opens and closes it.
  - The globe glyph flies to the Translation tab.
  - The tab highlight slides between tabs.
  - Panels unfold downward inside the same glass, as the Lectern's unfold upward.
- **The bar:** `[🌐 English] [◐ Theme] [Aa Text] [ⓘ About]  [✕]`. Each tab is a glyph over a short caption. The Translation tab's caption is the current language.
- **The globe opens on Translation**, so switching translation takes the same number of taps as the old popover.
  - Tapping another tab switches panel.
  - Tapping the open tab folds its panel away and leaves the bar.
  - The ✕, a tap anywhere outside (a light dim), Esc on a keyboard and the VoiceOver escape gesture all close it.
- **Panels:**
  - **Translation:** "Hymn N in…" and every hymnal, the same `TranslationSwitcher` church mode uses. Choosing one switches and closes the menu.
  - **Theme:** the five reading surfaces as swatches.
  - **Text:** text size, Serif / Sans, print size, spacing and alignment.
  - **About:** the hymn's eyebrow and title, then:
    - words / music / year;
    - the first five lines of its story, or "No story has been added…";
    - scripture chips (open bible.com / YouVersion);
    - its collections;
    - the accompaniment credit ("MIDI from The Cyber Hymnal (hymntime.com)", which opens hymntime.com), when the hymn has accompaniment;
    - "Read the full story" / "More about this hymn", which opens the existing About this hymn sheet.
- **Live preview:** Theme and Text sit over the lyrics under a light dim, so changes can be judged on the page as they're made.
- **Panel height:** panels stop above the Lectern and scroll past that.
- **One piece of chrome at a time:** opening the menu closes the Lectern, and opening a Lectern panel closes the menu. Tapping the text with the menu open closes it rather than entering focus mode. In focus mode the globe fades with the rest of the chrome.

### The Lectern (bottom)

- **Collapsed row:** unchanged — play, title, jump, library.
  - **Play** is still paywall-gated. For free users it now wears a small brass lock, and VoiceOver hears "Advent Praise Pro. Shows what Pro includes."
- **Hymn tray:** was Save · Church · Playlist · Hymnal · Text · More. Now it is **Church · Memorise · Playlist · Save · More**.
  - Hymnal and Text moved to the top.
  - **Memorise** is new here: it opens the memory game for the hymn on screen, two taps from the reader. It used to be More → Tools → Memorise a verse.
- **More:** lost Appearance, Large print and Hymnals (all in the reader menu now). Tools lost About this hymn (now in the menu) and Memorise (now in the tray).
- **Removed:** the Lectern's Hymnals panel state (`LecternState.hymnals`) and the Appearance drawer (`showAppearance`, `appearanceDrawer`). The iPad sidebar's Hymnals sheet still uses `HymnalStorePicker`.

### About this hymn (sheet)

New Accompaniment section with the Cyber Hymnal credit and link, for hymns that have accompaniment.

## How it's built

### Files

- `Reader/ReaderMenu.swift` (new):
  - the toolbar slot;
  - the overlay that draws the globe and the menu;
  - the morph shape and glass;
  - the bar and its tabs.
- `Reader/ReaderMenuPanels.swift` (new): the Translation, Theme, Text and About panels.
- `Design/AppearanceControls.swift`: the old drawer's sections are now standalone views (`ReadingSizeControl`, `ReadingFontPicker`, `ReadingLayoutControls`, `ReadingSurfacePicker`). The menu's panels lay them out.
- `Reader/ReaderModel.swift`: `isMenuOpen`, `menuPanel`, `menuAnchor`; `openMenu`, `toggleMenuPanel`, `closeMenu`.

### Why an overlay, not a toolbar item

The navigation bar keeps an empty 44 pt slot where the globe was (`ReaderMenuGlobeSlot`, shared background hidden on iOS 26). The slot keeps the compact header's room for the globe, and it reports its frame in window coordinates. RootView's `.readerMenu(model)` overlay draws the real globe on top of that frame.

The overlay sits above the navigation bar and below the drawers, sheets and church mode. Toolbar items live in UIKit's bar, so nothing there can grow into a bar or share a matched geometry with content. In one SwiftUI hierarchy, the globe and the bar can.

### The morph

1. **First attempt: one view whose frame changed between the globe and the bar.** The bar's content was inserted in the transaction, and an inserted view takes its final position *relative to its animating parent*. So the row rode the glass's moving leading edge, and the ✕ stayed clipped until the end. A frame slowed 40× showed it.
2. **Now: the bar stays laid out at its final frame**, at opacity 0 while closed. Only an animatable `MenuMorphShape` changes: it goes from the globe's 44 pt circle at the top trailing corner to the whole bar, corners from 22 to 26.
   - The same shape is the clip, the glass and the hit area. While closed, only the circle takes touches, not the hidden bar.
   - Nothing slides, so the glass uncovers the tabs leftward from the globe, and the ✕ is where the globe was from the first frame.
3. **matchedGeometryEffect** flies the globe glyph between the closed globe and the Translation tab. It is the source on whichever side is showing. The tab wash is one shape matched across the four tabs.
4. **Animation:** one `withAnimation(DS.Motion.lecternTransition)` in `ReaderModel.setMenu`. It is the Lectern's calm spring (0.35 s, bounce 0), so both bars feel like one system.
5. **glassEffectID isn't used.** As in BARANIM_STATUS, there's only ever one glass shape, which reshapes inside a `GlassEffectContainer`. It is interactive Liquid Glass on iOS 26.
   - **iOS 17–25:** the closed globe is a bare tinted icon, as bar buttons are there. A thin-material fill, hairline and shadow fade in as the bar opens (opaque `elevated` under Reduce Transparency). **Not run:** there are no such runtimes here.

### Reduce Motion

No morph and no glyph flight. The globe and the open bar are separate views that cross-fade in place (0.2 s), the tab highlight fades per tab, and panels fade.

**Bug found and fixed:** a stray half-globe showed above the ✕ mid-fade. The fading globe's glyph had lost its matched-geometry source. The closed copy had also kept a hidden bar, which re-laid itself out with the newly opened panel.

### Haptics (through `Haptics`)

- `.softImpact` when the menu opens and closes, like the Lectern.
- `.selection` when a tab switches panel, and on every theme or text change (the panels' `.haptic(.selection, trigger:)`).
- Free users tapping Play: the paywall, no play haptic (unchanged).

### Analytics

- **New events:**
  - `reader_menu_opened` (`panel`);
  - `reader_menu_panel_opened` (`panel`);
  - `tool_opened` (`tool`, `source`: `more` / `tray` / `reader_menu`).
- **New values:**
  - `scripture_opened.surface = reader_menu`;
  - screen `about_hymn_panel`.
- **Screens on the panels:** Translation and Theme / Text send their existing screens (`translations`, `appearance`).
- **Unchanged:** `appearance_changed` and `text_size_changed` are still sent by `ReadingSettings`.
- **No longer sent:** `hymnal_switched.source = lectern`, because the panel is gone. The reader's switches are `translation`.
- `ANALYTICS_PLAN.md` is updated.

### VoiceOver

- **The globe:** "Reading options", value "English, Christ In Song", hint saying what's inside.
- **When the menu opens:**
  - focus moves to the open tab;
  - the bar is a modal container, so VoiceOver stays in it;
  - escape closes it.
- **Tabs** are single elements with values: the language, the surface, the font and size. The open tab carries Selected.
- **The dim** is hidden from VoiceOver.
- **While closed,** the hidden bar is hidden from VoiceOver.
- **Tray hints** are new (Church, Memorise), and the handle's label and hints now describe the hymn's actions.
- **Not tested** with VoiceOver running: this harness has no touch or rotor.

### Dynamic Type

- The menu caps at accessibility2, like the Lectern.
- The 52 pt bar's captions stop at xxLarge.
- Panels follow Dynamic Type further and scroll.
- **Checked at AX XL:** the Text panel reflows (font cards stack their detail). The tray truncated its five captions ("Chu…", "Me…"), so they now stop at xxxLarge, and the glyphs keep growing.
- Tray tiles and menu tabs offer the large content viewer.

### iPad

- The bar anchors on the detail column's globe, trailing-aligned, capped at the Lectern's 560 pt and kept clear of the sidebar (the reader reports its frame).
- **Checked by screenshot:** About open beside the sidebar.
- When the anchor moves (rotation, sidebar toggle), the globe glides there over 0.35 s rather than jumping. **Not tested by touch.**

## Header and Lectern animations

- **HEADER_STATUS:** the compact header still collapses into the bar beside the globe. Screenshot with `-uiDebugScroll 220`. The slot keeps the globe's room in the bar, so the header's width cap is unchanged.
- **BARANIM_STATUS:** the Lectern's code paths are untouched apart from the tray's tiles, the play badge (an overlay with opacity, so no layout change) and the removed hymnals state. Its single transaction, matched highlight and clipped panel slot are as they were. The tray with the new tiles was screenshotted open.

## Debug launch arguments (DEBUG only)

- `-uiDebugMenu translation|theme|text|about|bar` opens the reader menu, a second after launch, so it morphs from the globe.
- `-uiDebugTranslations YES` now opens the menu on Translation.
- `-uiDebugMotionSpeed 0.025` slows the Lectern and menu spring, to catch mid-morph frames.

## Screenshots

In `build/shots/redesign/` (git-ignored):

- **Closed:** `closed.png`.
- **Panels:** `menu-translation.png`, `menu-text.png`, `menu-about.png`, `menu-theme-black.png`.
- **The morph, slowed:** `morph-a.png` (just leaving the globe), `morph-b.png` (mid-grow, glyph in flight).
- **Reduce Motion:** `rm-mid.png`.
- **Dynamic Type:** `ax-text.png`, `ax-tray.png` (AX XL).
- **The free tray, with the lock:** `tray-free.png`.
- **iPad:** `ipad-closed.png`, `ipad-about.png`.
- **The header:** `header-collapsed.png`.

## Not tested

- **By touch:**
  - opening and closing by tapping;
  - switching tabs;
  - the dim closing the menu;
  - choosing a translation;
  - dragging the size slider;
  - Memorise from the tray;
  - the closing morph (it is the same transaction reversed, but no frame of it was captured);
  - interrupting a morph mid-way.
- **iOS 17–25 fallback:** no runtimes.
- **VoiceOver and the large content viewer**, live.
- **Keyboard Esc** on iPad.
- **Simulators:** the process limit on this machine was full of other sessions' booted simulators. I shut down the idle "AP Baranim 17 Pro" (that branch was merged long ago) to boot mine. I shut the iPad down again after its screenshots.

## Merge into main

- **Merged** into `main` in `../AdventPraise` as `ff9827d`, with no conflicts. Main hadn't moved since this branch started from `bc34206` (collections merge notes).
- **Build:** the merged `main` builds for iOS Simulator with no warnings.
- **Launch test:** on "AP Redesign 17 Pro", the merged build opened hymn 30 with the reader menu on About (`main-merged.png`).
- **Not pushed.**
