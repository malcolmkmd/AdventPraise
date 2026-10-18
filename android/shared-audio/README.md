# Shared audio

`piano.sf2` (2.9 MB) is the one piano Advent Praise plays on Android: the phone's
accompaniment player and the Cast receiver on the TV both load it. It is FluidR3_GM's
program 0 ("Yamaha Grand Piano", MIT, see `LICENSE-FluidR3.txt`): 20 samples across
the keyboard, nine velocity zones, mixed to mono and resampled to 24 kHz to fit.

Rebuild it (standard library Python; the download goes to a scratch folder, never git):

```sh
python3 -I tools/extract_piano.py --download /tmp/sf2-src piano.sf2
```

The script pins the Debian package URL and the SHA-256 of both the `.deb` and the
`.sf2` inside it, and is deterministic: the output's SHA-256 is
`333c70b45bf7e039cfc7204b594840c5ed87d01767aa544ca295fea8cb613f4b`.

Like iOS (which loads only program 0 into its sampler), every MIDI channel should play
this piano whatever program the file asks for: the Christ In Song files also select
pads (91), choir (52) and organ (16).
