# PLBTN — sticky add-to-playlist button in the Lectern

Bug (Malcolm, real iPhone): the tray's Playlist tile often needed several taps.

## Root cause

The Playlist tile was the only tray control built as a SwiftUI `Menu`; Church,
Memorise, Save and More are plain `Button`s and were fine. On iOS a `Menu` is
UIKit-backed: its tap is a UIKit gesture recognizer (the context-menu
primary action), not a SwiftUI gesture. Inside the Lectern it had to win
against two things that cover the whole capsule:

1. **Interactive Liquid Glass.** `LecternGlass` applied
   `.glassEffect(.regular.interactive())` to the entire Lectern. Interactive
   glass is meant for controls; on a container it tracks every touch, flexing
   the whole capsule under the finger, and its touch tracking competes with
   the UIKit recognizer of a Menu inside it.
2. **The capsule's swipe.** `ReaderToolbar` puts a `DragGesture` (expand /
   collapse) on the whole capsule with `.gesture(swipe)`. SwiftUI `Button`s
   beat a parent SwiftUI gesture by design; a UIKit-backed `Menu` doesn't take
   part in that arbitration, so a tap with a little finger drift was lost.

A tap that didn't land cleanly therefore did nothing, which felt "sticky".
The tempo control in the player strip was the same pattern (a `Menu` in the
same glass, under the same swipe).

Note: I couldn't reproduce the multi-tap behaviour in the Simulator (no
device, and no tap tool here). The cause is inferred from the code: the only
tray tile that misbehaves is the only one that differs (Menu vs Button), and
both whole-capsule touch handlers sit above it. Please confirm on the iPhone.

## Fix

- **Playlist tile** (`LecternPanels.swift`): now a `TrayTile` `Button`, like its
  neighbours (72 pt tile, content shape across the whole tile). Tapping it
  opens a `confirmationDialog` anchored to the tile: "Add hymn N to" with
  each playlist the hymn isn't in yet, plus New Playlist…; the message lists
  the playlists it is already in. With no playlists, the tap goes straight to
  New Playlist.
- **Lectern glass** (`ReaderToolbar.swift`): `.glassEffect(.regular)`, no
  longer `.interactive()`. The capsule no longer flexes on touch; buttons
  inside keep their own press feedback (DSPressStyle).
- **Tempo** (`LecternPlayer.swift`): a `Button` that steps Slow → Medium →
  Fast; VoiceOver can swipe up/down to adjust it. No longer a Menu.

## Audit of the other bottom-bar buttons

| Control | Finding | Change |
| --- | --- | --- |
| Handle chevron | 114 × 44 content shape | none |
| Play | 44 × 44 label | none |
| Hymn title | ≥ 48 pt, content shape | none |
| Jump / Library icons | 44 × 44, but hit area came from the fill, which is clear when the button is on | content shape added |
| Tray tiles | full-tile content shape | none |
| Restart, Loop (player) | 44 pt `.frame` was **outside** the Button, so only the glyph took taps | frame and content shape moved into the label |
| "123" (search panel), "Abc" (number pad) | padding/frame/fill **outside** the Button: only the text took taps | moved into the label, with a content shape and DSPressStyle |
| Library "New playlist" (GlassButton) | system bordered button, 44 pt | none |
| Pad keys, rows | full-frame labels / content shapes | none |

The reader menu at the top (`ReaderMenu.swift`) also uses interactive glass.
It wasn't part of this bug, so I left it as it was.

## Build

`xcodebuild` for the iOS Simulator (iPhone 17 Pro): BUILD SUCCEEDED, no
warnings. Launched with `-uiDebugLectern hymn`; the tray draws correctly.
