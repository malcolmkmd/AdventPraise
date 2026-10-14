# Memorise

Memorise turns a stanza into a word game. Some words are hidden (A few, Half, Most, All, one round each), and the singer fills the blanks in order by tapping one of the word chips. Blanks give nothing away (fixed width, no first letter). A right chip drops in and builds a streak. A wrong one shakes, is ruled out and ends the streak, and a second miss on one blank shows its first letter. Hints are earned: one to start, then one per three right in a row (three at most). A hint shows the next letter and rules out chips that can't fit. A finished stanza earns 1–3 stars, revealed one by one. The best stars per level show on the level chips, and finishing with All hidden marks the verse "learned by heart".

## Sub-features

- `mem-open` the tray's Memorise tile (or About this hymn → Memorise a verse) opens the game on verse 1, A few hidden.
- `mem-blanks` blanks give nothing away; there's no First letters toggle.
- `mem-wrong` a wrong chip is ruled out ("ruled out") and the streak resets to 0.
- `mem-hint` one hint at the start; using it decrements hints and reveals the next letter ("next blank starting …").
- `mem-streak` every 3 in a row shows a note and earns a hint (capped at 3).
- `mem-complete` filling every blank shows the card "Verse 1, round 1 of 4", stars, Next round: half hidden, Play again.
- `mem-best` the best stars persist on the level chip ("A few hidden, best N stars").
- `mem-learned` finishing All hidden marks the verse tab "learned by heart" (not in the journey: four rounds).

## How to get to it (user POV)

- Lectern handle (`Hymn actions`) → hymn tray → **Memorise**.
- Reader menu → About this hymn → drawer → Tools → **Memorise a verse**.
- Debug shortcuts only: `-uiDebugSheet memory`, plus `-uiDebugMemoryMoves N` (N right picks then a wrong one; 99 finishes).

## Driving it with the APVerify harness

Preconditions:

- DEBUG build installed; 191 open via base arguments. Earlier Memorise stars on 191 don't break the journey (it reads the label).

- **Run.** `xcodebuild test-without-building … -only-testing:APVerifyUITests/MemoriseJourney`. Evidence in `../verify-evidence/<run>/memorise/`.
- **Open.** `lectern.handle` → the tray's `Memorise`. The navigation bar reads `Memorise`, and the scoreboard label starts `Score 0, streak 0, 1 hints, 0 of N words found`. The verse label has `next blank` without `starting`. Shot `round-start`.
- **Play.** Tap the first enabled chip below `Which word comes next?` and re-read the scoreboard. If the found count rose, it was right; if not, it was wrong. The first wrong chip must read `ruled out`, with streak 0 (shot `wrong-chip-ruled-out`). On the second blank, tap `Hint`: hints drop by one and the verse label gains `next blank starting` (shot `hint-used`). Shot `streak-3` at each streak of 3.
- **Finish.** All blanks are filled. A static text containing `round 1 of 4`, a `N stars` element, and the buttons `Next round: half hidden` and `Play again` show. Shot `round-complete-stars`.
- **Best kept.** A button labelled `A few hidden, best N stars` exists. Tap `Next round: half hidden` and a fresh round starts. Shot `next-round-half`.
- **The journal** records every chip tapped, right or wrong, with the scoreboard after it. That's the play-by-play proof.

## Gotchas

- Chips are dealt to tempt (same first letter, similar length, rhyme). There's no way to know the answer from the UI, so the journey tries chips in order. The number of wrong picks varies from run to run. Rarely, a round has no wrong pick, which the journal records.
- The reader's Lectern buttons stay in the accessibility tree under the Memorise sheet, below the "Which word comes next?" header too. The chip filter keeps only one-word labels, and must keep doing so.
- A right word after misses on its blank scores 5 and leaves the streak at 0. That's the rule, not a bug.
- Look at the shots, not only the journal. The 2026-10-14 run found layout slips (the scoreboard's STREAK caption wrapping, a stale note) that no label check catches.
- The scoreboard and verse are single accessibility elements with composed labels. Parse the numbers and don't look for child texts.
- The journey is slow: each chip tap costs ~15–20 s because `chips()` walks every button in the tree, so a 7-blank round with misses takes 3–5 min. The journal shows it advancing. Don't stop it as hung while lines keep appearing.
- Chips re-render for each blank. Re-query after every tap, never keep element references across picks.
- Stars reveal one by one (~0.5 s, then 0.32 s each). Wait ~2 s before the completion shot.
- The game posts VoiceOver announcements and haptics, which a screenshot can't show. The journal's scoreboard values stand in for them.
