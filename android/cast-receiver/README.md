# Advent Praise Cast receiver

Church mode's worship display for Google Cast: a custom Web Receiver the Android app
casts to a TV (Chromecast, Google TV, Cast-enabled TVs). It is the iOS worship display
(`ExternalHymnView` in `AdventPraise/Features/ExternalDisplay.swift`) ported to the web:
the brand ground, the hymn number and title, the verse large, "Verse 2 of 4" and a dot
per block, the chorus in its own face, the title card between hymns, Blank,
announcements and pictures, and the same 0.45 s cross-fade.

Unlike AirPlay on iOS, **the TV is the clock**: it plays the hymn's MIDI accompaniment
itself on the shared piano SoundFont (`../shared-audio/piano.sf2`) and reports its
position about four times a second. The phone goes silent and follows that position for
its verse following and sheet music highlights.

The messages between phone and TV are in [`PROTOCOL.md`](PROTOCOL.md) (v1).

## What's here

| Path | What |
|---|---|
| `src/` | The receiver: `index.html`, `receiver.css`, `main.js` (Cast or harness bus, the protocol), `display.js` (the worship display), `transport.js` (the accompaniment), `smf.js` (a MIDI file's length, measured like iOS), `sda-logo.js` (generated from the iOS `SDALogoShape`) |
| `deploy.sh` | Assembles `dist/` and deploys it to Cloudflare Pages |
| `harness/` | A desktop harness that plays the phone, and the headless check (`shots.mjs`) |
| `tools/make_logo.py` | Regenerates `src/sda-logo.js` from the iOS shape |

`dist/` and `node_modules/` are never committed. `deploy.sh` copies in, at deploy time:

- the MIDI files and `midi-manifest.json` from the app's `AdventPraise/Resources/Midi`;
- `piano.sf2` from `../shared-audio` (the same file the phone's player loads);
- the synth, [spessasynth_lib](https://github.com/spessasus/spessasynth_lib) 4.3.14
  (Apache-2.0): its main-thread half bundled into `receiver.js` with esbuild, its
  AudioWorklet half (`spessasynth_processor.min.js`) as published;
- the faces, from Fontsource (OFL), and every licence into `dist/licenses/`.

### Faces

iOS draws the display in New York, SF and Avenir Next (the chorus). Apple's licence
doesn't allow serving them on the web, so the nearest open faces stand in:
**Source Serif 4** (semibold) for New York, **Inter** (bold) for SF and **Nunito Sans**
(bold italic) for Avenir Next. Sizes, weights, tracking and line spacing are iOS's;
line heights use the iOS faces' own metrics, so the lines keep iOS's rhythm.

### Light and dark

iOS's worship display is always dark (the Stage ground). The receiver also has a light
variant (the reader's Paper ground, ink and brass) for when the phone sends
`theme.appearance: "light"`; dark is the default.

### Size on a Chromecast

| File | Size | gzip |
|---|---|---|
| `receiver.js` (app + synth main thread) | 297 KB | 111 KB |
| `vendor/spessasynth_processor.min.js` (AudioWorklet) | 403 KB | 136 KB |
| `piano.sf2` | 2.9 MB | (fetched once, at start-up) |
| one hymn's MIDI | 1–5 KB | |
| `dist/` in all, with 245 MIDI files and fonts | 4.7 MB | |

To spare the Chromecast's CPU: the piano is mono at 24 kHz, the synth's reverb and
chorus are off (iOS's sampler is dry too), at most 64 voices (a hymn uses about 16), the
audio context asks for `latencyHint: "playback"` (bigger buffers), no media element or
player library is loaded (`skipPlayersLoad`), and the page only redraws when the page
changes. The worklet needs Chrome 66 or later and the bundle targets Chrome 80; current
Chromecast and Google TV firmware is well past both.

## Run it locally

Node 20 or later.

```sh
cd android/cast-receiver
npm ci
./harness/serve.sh          # assembles dist/, serves the worktree root on :8787
```

Open the printed URL in Chrome. The left side is the real receiver page at 1920 × 1080;
the right side plays the phone: pick a hymnal and number and Load (the pages are built
from the app's own hymnal JSON, as the phone builds them), step pages, Blank, title card,
theme and text size, play / pause / stop / seek / tempo, an announcement or a picture.
"Follow verses" turns pages from the TV's position, like the phone will. The status
stream shows what the TV reports, extrapolated on the "phone's" clock. Click once
anywhere first so Chrome allows audio.

Headless check (screenshots into `harness/shots/`, then a transport test against the
real MIDI and piano: clock rate, the pass boundary, tempo, end, pause, stop, errors):

```sh
npx playwright install chromium      # once
./deploy.sh --no-upload && node harness/shots.mjs
```

## Deploy (Cloudflare Pages)

Once, on the Mac that deploys:

```sh
npx wrangler login
npx wrangler pages project create advent-praise-cast --production-branch main
```

Then, from `android/cast-receiver`, every time:

```sh
./deploy.sh
```

The receiver is live at **https://advent-praise-cast.pages.dev/**. Deploy again after the
app's MIDI files change (a new hymn's accompaniment must be on the TV too).

## Register it with Google Cast

1. Open the [Google Cast SDK Developer Console](https://cast.google.com/publish) with the
   Google account that should own it (a one-time US$5 registration fee if the account
   isn't registered yet).
2. **Add New Application** → **Custom Receiver**. Name: *Advent Praise*. Receiver
   Application URL: `https://advent-praise-cast.pages.dev/`. Save.
3. Copy the **Application ID** (eight characters, e.g. `A1B2C3D4`). The Android app's
   Cast options provider needs it as the receiver application ID.
4. Leave it **Unpublished** while testing: it then only runs on registered test devices.

### Register a test device

1. In the console: **Add New Device**. Enter the device's **serial number** and a
   description.
   - Chromecast: the serial is printed on the device (and on its box).
   - Chromecast with Google TV / Google TV: *Settings → System → About → Status*, or the
     label on the device.
   - In the Google Home app: the device → *Settings* → *Device information*.
2. Wait about 15 minutes for the status to read *Ready for testing*, then **restart the
   Cast device** (unplug it, or *Settings → System → Restart*).
3. While it's registered you can debug the receiver from desktop Chrome at
   `http://<device-ip>:9222`.

When it's ready for everyone: **Publish** in the console (live within about 15 minutes).
A published app runs on any Cast device; nothing changes in the app.

## On-TV test script

On the same Wi-Fi as a registered Cast device, with the Android app built against the
Application ID and signed in to Pro:

1. Open a hymn with accompaniment (Christ In Song 1) and enter church mode. Cast to the
   TV: within a few seconds the TV shows the brand ground and mark, then verse 1 with
   "1 Watchman Blow The Gospel Trumpet" across the top and "VERSE 1 OF 4" with eight dots.
2. Turn verses on the phone: the TV cross-fades; the chorus shows its eyebrow and italic
   face, and the footer reads "CHORUS".
3. Blank: only the ground and the faint mark; turn a verse and the words come back.
4. Press play: the piano comes from the **TV**, the phone stays silent. The phone's
   verses and sheet music highlights follow the TV. Pause, seek and change the tempo:
   the TV follows within a quarter of a second.
5. Let the last verse end: the TV stops, the phone shows the hymn finished.
6. Next hymn from the phone: the TV shows the new hymn; play starts its own MIDI.
7. Change the text size on the phone: the TV's verse grows or shrinks; a long verse
   still fits.
8. Announcement, then a picture, then Clear.
9. Stop casting from the phone: the TV goes back to its home screen. Kill the app while
   casting instead: the TV holds the last page and closes itself after 10 minutes.
10. A hymn without accompaniment (a translation): words only; play reports
    `no_accompaniment`.
