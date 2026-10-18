# Sheet music pipeline

Builds the app's sheet music (`AdventPraise/Resources/SheetMusic/`) from The
Cyber Hymnal's NoteWorthy Composer scores. Everything runs at build time on a
dev machine; the app only ships the finished vector pages and reads them with
`SheetMusicCatalog`. No LGPL code (verovio) goes into the app.

## Requirements

Python 3.11+ with `music21`, `verovio` (6.x), `mido`, `pyphen`, `pronouncing`,
`cairosvg`, `Pillow`; `pdftoppm` (poppler) for proofs.

## Steps

    python download.py      # src/nwc, src/pdf (Wayback copies of hymntime.com; sources.json lists the URLs)
    python convert.py       # src/nwc -> build/xml/NNN.musicxml + build/report/NNN.json
    python render.py        # build/xml -> build/svg/{phone,pad}/NNN.svg (verovio, inked in currentColor)
    python check.py         # build/checks.json + checks.csv: score vs the app's MIDI, lyrics vs the app text
    python proof.py NNN     # build/proof/NNN.png: the Cyber Hymnal PDF above our page, for proofreading
    python sync.py          # build/sync/NNN.json: timing against the app's MIDI, measure/note/syllable boxes per page
    python bundle.py        # build/bundle/SheetMusic: page packs, sync pack + manifest; copy into AdventPraise/Resources/SheetMusic
    python verify_slim.py   # optional: every shipped page rasterises identically before and after slim.py

`bundle.py` refuses to run while a hymn that `check.py` marked `proofread` is
neither held (`hold.json`) nor cleared after a visual check (`proofread_ok.json`).

## What convert.py does

- Parses NWC 2.75 text (zlib after the `[NWZ]` header), two voices per staff,
  triplets (Dur and Dur2), ties, slurs, fermatas, repeats, endings, key and time
  changes, and the score's own `Lyric=Never` / `Lyric=Always` flags.
- Repairs bars the source got wrong, using the other staff as the reference
  (split bars, missing rests, refrain pickups, 2× and 3× bars), and per-hymn
  fixes in `overrides.json` (each with a `_why`).
- Lyrics: matches each Cyber Hymnal verse to the app's verse and swaps in the
  app's words where the syllables fit, so the music shows what the app shows.
  Lines that can't be swapped keep the Cyber Hymnal wording (listed per hymn in
  `checks.csv`). App verses the score lacks are added when they fit. Scores with
  no words get the app's text underlaid when it fits syllable for syllable;
  otherwise they are held (`no_words` in hold.json).
- Cosmetic clean-up of app text quirks for display (backtick apostrophes,
  punctuation stuck to the next word, a lone "i").

## Held hymns

`hold.json`: the 12 whose rights are unclear, and those that can't ship
confidently (different hymn on the Cyber Hymnal, a tune that doesn't fit the
app's metre, engraving collisions, no public-domain setting for #85).

## Output format

`sheet-music-{phone,pad}.pack`: each page's SVG as raw DEFLATE, back to back.
`sheet-music-manifest.json`: `{"hymnal", "packs", "hymns": {"N": {"phone": {"w","h","o","n"}, "pad": {...}}}}`
(page size, offset and length in the pack). Two packs instead of one file per
page because the app target's synced folders copy resources flat.

## Following the accompaniment (sync.py)

The app plays each hymn's MIDI file once per verse, and the viewer marks what
it is playing. `sync.py` unfolds the score's repeats and 1st/2nd endings,
matches the melody (staff 1, voice 1) to the MIDI's top line by pitch with
dynamic time warping (allowing a transposition), and turns the matched notes
into a piecewise-linear map from score beats to MIDI seconds, so the MIDI's
tempo changes and held notes are followed. Every measure start and note onset
gets a time within one pass. Geometry comes from the un-slimmed verovio SVG:
staff lines give each measure's box, noteheads and syllables are read in score
order and checked one for one against the notes (a hymn that doesn't pair up
follows by measure only). `build/sync.json` lists, per hymn, the share of the
melody matched and where the score's last beat lands against the file length.
