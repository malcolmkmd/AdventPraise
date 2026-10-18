# Church mode on Cast: protocol v1

The Android phone (the Cast **sender**) and the TV (this custom Web Receiver) talk
over one custom namespace, JSON messages both ways:

```
urn:x-cast:com.mDev.AdventPraise.church
```

Every message is a JSON object with `v` (the protocol version, `1`) and `type`.
The receiver ignores fields it does not know and answers an unknown `type` or a
newer `v` with an `error`. Strings are UTF-8; a Cast message is at most 64 KB.

**Who owns what.** The phone owns *what is on screen*: the hymn, which page,
Blank, the theme and text size. It follows the sung timing itself from the
TV's reported position and sends `page` when the verse changes. The TV owns
*audio time*: it plays the hymn's MIDI with the piano SoundFont, and its
`positionMs` is the one clock. While casting the phone plays nothing.

## Pages, as iOS has them

A hymn on the TV is its **sung sequence** (iOS `Hymn.sungSequence`): the blocks
in the order a congregation sings them, so a hymn with exactly one chorus has
that chorus after every verse (and first, when the hymn starts with it). The
phone sends the pages already in that order; the receiver never reorders them.

`pageIndex` is an index into `pages`, or `-1` for the **title card** (iOS shows
it when church mode is closed: the hymn about to be sung, with its number large).

## Audio time, as iOS has it

The accompaniment plays the MIDI file once per verse (iOS
`HymnMIDIEngine` / `Hymn.accompanimentPasses`): `passes` times through the tune,
the chorus inside each pass. All times are **performance time at the written
tempo**, the unit of iOS's `elapsed`, `duration` and `seek(to:)`:

- `passDurationMs`: one pass, the MIDI's length to its last End of Track
  (the longest track, through the tempo map), exactly as iOS measures it.
- `durationMs = passDurationMs × passes`.
- `positionMs = (pass - 1) × passDurationMs + offset into the pass`.
- `rate` (0.8 slow, 1 medium, 1.2 fast, iOS `PlaybackTempo`) speeds the clock:
  while playing, `positionMs` grows by `rate` ms every wall-clock ms.

So the phone's verse and line following is the iOS arithmetic on `positionMs`.

## Sender → receiver

### `load`
Puts a hymn on the TV. Send it when casting starts and whenever the hymn
changes (next hymn, number pad, translation).

```json
{
  "v": 1, "type": "load",
  "hymnalKey": "english",
  "hymnalName": "Christ In Song",
  "number": 1,
  "title": "Watchman Blow The Gospel Trumpet",
  "pages": [
    { "kind": "verse",  "label": "Verse 1 of 4", "lines": ["Watchman, blow the gospel trumpet,", "…"] },
    { "kind": "chorus", "label": "Chorus",       "lines": ["Blow the trumpet, trusty watchman,", "…"] }
  ],
  "pageIndex": 0,
  "blank": false,
  "theme": { "appearance": "dark", "worshipPointSize": 42, "largePrint": false },
  "midi": "hymn-001.mid",
  "passes": 4,
  "tempo": 1,
  "autoplay": false,
  "startMs": 0
}
```

| Field | Required | Meaning |
|---|---|---|
| `hymnalKey` | yes | The hymnal's key (`hymnals.json`), e.g. `english`, `sdah`. |
| `hymnalName` | yes | Shown on the title card (iOS `hymnal.name`), e.g. "Christ In Song". |
| `number` | yes | The hymn number in that hymnal. |
| `title` | yes | The hymn title. |
| `pages` | yes | The sung sequence. `kind` is `verse` or `chorus`. `label` is the localized position text for the footer: "Verse 2 of 4" for a verse, the hymnal's chorus label ("Chorus", "Refrain", "Coro"…) for a chorus, which is also the eyebrow over the chorus. `lines` are the lines as printed. |
| `pageIndex` | no (0) | Page to show, `-1` for the title card. |
| `blank` | no (false) | Blank: only the ground and a faint mark. |
| `theme` | no | See `theme`. Missing fields keep their current values. |
| `midi` | no (null) | The accompaniment's file name in `midi/` on the receiver (the app's `Resources/Midi`, e.g. `hymn-001.mid`; for an SDA Hymnal hymn, its Christ In Song tune's file). `null`: no accompaniment. |
| `passes` | no | Times through the tune: the number of verse blocks (minimum 1), iOS `accompanimentPasses.count`. Default: the number of `verse` pages (each verse appears once in the sung sequence), at least 1. |
| `tempo` | no | `rate`, see `tempo`. |
| `autoplay` | no (false) | Start playing as soon as the audio is ready. |
| `startMs` | no (0) | Where to start, performance ms. |

If `hymnalKey`, `number` and `midi` are all unchanged from the current hymn, the
audio carries on untouched (iOS: loading the loaded hymn does nothing) and only
the words, page, Blank and theme update. Any other `load` stops the old audio
and loads the new file (state `loading`, then `paused` at `startMs`, or
`playing` with `autoplay`).

### `page`
```json
{ "v": 1, "type": "page", "pageIndex": 2 }
```
Shows page 2 (or `-1`, the title card). It does not change Blank: on iOS
turning a verse ends Blank, so the phone sends `blank` `{"on": false}` with it
(a page that changes while blanked, say from verse following, stays hidden).

### `blank`
```json
{ "v": 1, "type": "blank", "on": true }
```

### `theme`
```json
{ "v": 1, "type": "theme", "appearance": "dark", "worshipPointSize": 48, "largePrint": false }
```
- `appearance`: `dark` (default) or `light`. iOS's worship display is always
  dark (the Stage ground); `light` is the paper-coloured variant.
- `worshipPointSize`: church mode's text size on the phone (iOS
  `ReadingSettings.worshipPointSize`, default 42, range 30–80). The TV's verse is
  `84 × worshipPointSize / 42` px on a 1080-high screen, ×1.15 with large print.
  A verse too long for the screen shrinks to fit (down to 30 %).
- `largePrint`: the reader's large print setting.

### `special`
An announcement and/or a picture over the ground (iOS presenter actions).
```json
{ "v": 1, "type": "special", "announcement": "Fellowship lunch after the service", "imageId": null }
```
Both `null` (or a `special` with neither) clears it, back to Blank or the words.
A picture fills the screen (aspect-fit on black); an announcement sits large in
the middle, or at the bottom on a dark scrim over a picture.

### `imageChunk`
Pictures travel in pieces (Cast messages are capped at 64 KB). Downscale to fit
1920 × 1080 and encode JPEG first; send base64 in chunks of at most 48,000
characters, then a `special` with the same `imageId`.
```json
{ "v": 1, "type": "imageChunk", "imageId": "a1b2", "index": 0, "count": 6, "mime": "image/jpeg", "data": "/9j/4AAQ…" }
```
The receiver keeps the last 4 pictures; a `special` naming a picture still
arriving shows it as soon as the last chunk lands.

### `play`
```json
{ "v": 1, "type": "play", "fromMs": 0 }
```
Plays from the current position, or from `fromMs` (performance ms). From
`ended`, plays from the start.

### `pause`, `stop`
```json
{ "v": 1, "type": "pause" }
{ "v": 1, "type": "stop" }
```
`pause` holds the place. `stop` silences, rewinds to 0 and goes `idle`
(the hymn stays loaded: `play` starts it again from the top).

### `seek`
```json
{ "v": 1, "type": "seek", "ms": 61250 }
```
Performance ms, clamped to `[0, durationMs]`. Keeps playing if it was playing.

### `tempo`
```json
{ "v": 1, "type": "tempo", "rate": 0.8 }
```
`0.8`, `1` or `1.2` (any value in 0.5–2 is accepted).

### `getStatus`, `ping`
```json
{ "v": 1, "type": "getStatus" }
{ "v": 1, "type": "ping", "id": 17 }
```
`getStatus` asks for a `status` now (send it on connect and after a reconnect).
`ping` is answered at once with `pong`, for measuring the round trip.

## Receiver → sender

Sent to every connected sender.

### `status`
```json
{
  "v": 1, "type": "status",
  "state": "playing",
  "positionMs": 61250, "durationMs": 196000, "passDurationMs": 49000,
  "pass": 2, "passes": 4, "rate": 1,
  "sentAtEpochMs": 1760781600123,
  "hymnKey": "english-1", "pageIndex": 2, "blank": false,
  "midi": "hymn-001.mid", "seq": 812
}
```
- `state`: `idle` (nothing loaded, no accompaniment, or stopped), `loading`
  (fetching or decoding the MIDI or the SoundFont), `playing`, `paused`,
  `ended` (the last pass finished; position back at 0, like iOS).
- Sent about every 250 ms while playing, and at once on every change of state,
  hymn, page, Blank, tempo or a seek, and in answer to `getStatus`.
- `hymnKey` is `"<hymnalKey>-<number>"` (iOS's page key), `null` before a `load`.
- `seq` counts up; drop a status whose `seq` is lower than the last one seen.
- **Extrapolating.** While `state` is `playing`, the position now is
  `positionMs + (now − receivedAt) × rate`, where `receivedAt` is the phone's own
  clock when the status arrived (less half the `ping` round trip, if you
  measure it). `sentAtEpochMs` is the TV's wall clock; use it only if you trust
  the two clocks to agree (both are usually NTP-synced to within ~50 ms).

### `pong`
```json
{ "v": 1, "type": "pong", "id": 17, "receivedAtEpochMs": 1760781600120 }
```

### `error`
```json
{ "v": 1, "type": "error", "code": "midi_not_found", "message": "midi/hymn-999.mid: 404", "request": "load" }
```

| `code` | When |
|---|---|
| `bad_message` | Not JSON, no `type`, or a field of the wrong type. |
| `unsupported_version` | `v` is newer than 1. |
| `unknown_type` | A `type` this receiver doesn't know. |
| `no_hymn` | `page`, `play` or `seek` before any `load`. |
| `no_accompaniment` | `play` on a hymn loaded with `midi: null`. |
| `midi_not_found` | The MIDI file isn't on the receiver. |
| `midi_load_failed` | The file couldn't be read. |
| `soundfont_failed` | The piano didn't load; accompaniment is off for the session. |
| `audio_failed` | The audio engine failed to start. |
| `image_failed` | A picture couldn't be decoded. |

After an error the receiver stays up and keeps showing the words.

## The receiver page

- Hosted on Cloudflare Pages (project `advent-praise-cast`); registered in the
  Cast SDK Developer Console as a Custom Receiver. The sender launches it by its
  application ID.
- `index.html?harness=1` runs without the Cast SDK and takes the same messages
  through `window.postMessage({namespace, senderId, data})` from its parent
  (`harness/index.html`), answering the same way.
- Files: `midi/*.mid` + `midi/midi-manifest.json` (the app's), `piano.sf2` (shared
  with the phone player), `fonts/`, `vendor/`.
- Lifetime: the Cast idle timeout is off, so the words stay up between hymns. A
  `status` goes out whenever a sender connects. When every sender has been gone
  for 10 minutes (the phone app killed rather than casting stopped), the receiver
  closes itself.
