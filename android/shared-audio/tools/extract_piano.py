#!/usr/bin/env python3
"""Builds android/shared-audio/piano.sf2: FluidR3_GM's acoustic grand piano
(General MIDI program 0, bank 0, "Yamaha Grand Piano") as a bank of its own.

Source: the Debian package fluid-soundfont-gm 3.1-6 (FluidR3_GM.sf2, MIT,
Frank Wen 2000-2002, 2008):

    https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont-gm_3.1-6_all.deb
    .deb   SHA-256 9965fbcc6acee17d6f72b685d28c7f968ec64eba14645445b476d5c6cc2eee4c
           (matches dists/sid/main/binary-all/Packages)
    .sf2   SHA-256 74594e8f4250680adf590507a306655a299935343583256f3b722c48a1bc1cb0
           (usr/share/sounds/sf2/FluidR3_GM.sf2 inside it)

The preset in FluidR3 is 20 stereo pairs at 32 kHz (7.8 MB of sample data).
To fit the phone and a Chromecast (target <= 3 MB) each pair becomes one mono
sample (L + R, the same loudness as the pair panned +-50 % plays at) and is
resampled to 24 kHz (windowed-sinc, 3:4 polyphase). Key ranges, loops,
envelopes, filter and the nine velocity zones are kept as Frank Wen set them.

Usage (standard library only; run with -I as the source is downloaded data):

    python3 -I tools/extract_piano.py FluidR3_GM.sf2 ../piano.sf2

or let it fetch and verify the package itself into a scratch directory:

    python3 -I tools/extract_piano.py --download /tmp/sf2-src ../piano.sf2
"""

from __future__ import annotations

import argparse
import array
import hashlib
import io
import lzma
import math
import os
import sys
import tarfile
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sf2  # noqa: E402

DEB_URL = "https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont-gm_3.1-6_all.deb"
DEB_SHA256 = "9965fbcc6acee17d6f72b685d28c7f968ec64eba14645445b476d5c6cc2eee4c"
SF2_SHA256 = "74594e8f4250680adf590507a306655a299935343583256f3b722c48a1bc1cb0"
SF2_MEMBER = "./usr/share/sounds/sf2/FluidR3_GM.sf2"

UP, DOWN = 3, 4           # 32 kHz -> 24 kHz
TAPS_PER_PHASE = 24       # filter length = UP * TAPS_PER_PHASE
ATTENUATION = 48          # initialAttenuation generator
TAIL = 46                 # zero samples the SF2 spec asks for after each sample


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def download(folder: str) -> str:
    """Fetches the .deb, checks it, and pulls FluidR3_GM.sf2 out of it."""
    os.makedirs(folder, exist_ok=True)
    deb = os.path.join(folder, os.path.basename(DEB_URL))
    if not os.path.exists(deb) or sha256(deb) != DEB_SHA256:
        print(f"downloading {DEB_URL}")
        urllib.request.urlretrieve(DEB_URL, deb)
    if sha256(deb) != DEB_SHA256:
        sys.exit(f"checksum mismatch for {deb}")
    out = os.path.join(folder, "FluidR3_GM.sf2")
    if os.path.exists(out) and sha256(out) == SF2_SHA256:
        return out
    with open(deb, "rb") as f:
        data = f.read()
    # A .deb is an `ar` archive; data.tar.xz is one of its members.
    offset = 8
    while offset < len(data):
        name = data[offset:offset + 16].decode().strip().rstrip("/")
        size = int(data[offset + 48:offset + 58].decode().strip())
        body = data[offset + 60:offset + 60 + size]
        if name.startswith("data.tar"):
            raw = lzma.decompress(body) if name.endswith(".xz") else body
            with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
                member = tar.extractfile(SF2_MEMBER)
                with open(out, "wb") as f:
                    f.write(member.read())
            break
        offset += 60 + size + (size & 1)
    if sha256(out) != SF2_SHA256:
        sys.exit(f"checksum mismatch for {out}")
    return out


def lowpass(cutoff: float, length: int) -> list[float]:
    """Kaiser-windowed sinc, cutoff as a fraction of the (upsampled) rate."""
    beta = 8.0

    def i0(x: float) -> float:
        total, term, k = 1.0, 1.0, 1
        while term > 1e-12 * total:
            term *= (x / (2 * k)) ** 2
            total += term
            k += 1
        return total

    mid = (length - 1) / 2
    taps = []
    for n in range(length):
        t = n - mid
        sinc = 2 * cutoff if t == 0 else math.sin(2 * math.pi * cutoff * t) / (math.pi * t)
        w = i0(beta * math.sqrt(1 - (2 * n / (length - 1) - 1) ** 2)) / i0(beta)
        taps.append(sinc * w)
    return taps


FILTER = lowpass(0.5 / DOWN * 0.92, UP * TAPS_PER_PHASE)
PHASES = [[UP * c for c in FILTER[p::UP]] for p in range(UP)]


def resample(x: list[float]) -> list[float]:
    """3:4 polyphase resampling: out[m] samples the input at m * 4/3."""
    n_in = len(x)
    n_out = (n_in * UP) // DOWN
    delay = (len(FILTER) - 1) // 2
    out = [0.0] * n_out
    for m in range(n_out):
        pos = m * DOWN + delay          # position in the virtual upsampled stream
        phase = pos % UP
        base = pos // UP
        taps = PHASES[phase]
        acc = 0.0
        for k, c in enumerate(taps):
            i = base - k
            if 0 <= i < n_in:
                acc += c * x[i]
        out[m] = acc
    return out


def build(src: str, dst: str) -> None:
    font = sf2.read(src)
    pcm = array.array("h")
    pcm.frombytes(font.smpl)
    if sys.byteorder == "big":
        pcm.byteswap()

    preset = next(p for p in font.presets if p.preset == 0 and p.bank == 0)
    inst_ids = sorted({z.get(sf2.GEN_INSTRUMENT).amount for z in preset.zones if z.get(sf2.GEN_INSTRUMENT)})
    assert len(inst_ids) == 1, inst_ids
    inst = font.instruments[inst_ids[0]]

    out_pcm = array.array("h")
    samples: list[sf2.Sample] = []
    zones: list[sf2.Zone] = []
    by_range: dict[int, list[sf2.Zone]] = {}
    for zone in inst.zones:
        sample_gen = zone.get(sf2.GEN_SAMPLE_ID)
        if sample_gen is None:
            zones.append(zone)          # the global zone
            continue
        key = zone.get(sf2.GEN_KEY_RANGE).amount
        by_range.setdefault(key, []).append(zone)

    # Resample every pair first: one gain for all of them keeps the
    # notes' relative levels if L + R would clip anywhere.
    mixes = []
    for key, pair in by_range.items():
        left = next(z for z in pair if font.samples[z.get(sf2.GEN_SAMPLE_ID).amount].type == sf2.LEFT)
        right = next(z for z in pair if font.samples[z.get(sf2.GEN_SAMPLE_ID).amount].type == sf2.RIGHT)
        ls = font.samples[left.get(sf2.GEN_SAMPLE_ID).amount]
        rs = font.samples[right.get(sf2.GEN_SAMPLE_ID).amount]
        assert (ls.end - ls.start, ls.loop_start - ls.start, ls.loop_end - ls.start) == \
               (rs.end - rs.start, rs.loop_start - rs.start, rs.loop_end - rs.start), (ls, rs)
        n = ls.end - ls.start
        # Panned +-50 % (equal-power), a correlated pair plays at about
        # 1.37x one channel per side; a centred mono sample at 0.71x. L + R
        # keeps the loudness.
        mixed = [float(pcm[ls.start + i]) + float(pcm[rs.start + i]) for i in range(n)]
        mixes.append((left, ls, n, resample(mixed)))
    peak = max(max(abs(v) for v in res) for *_, res in mixes)
    scale = min(1.0, 32767 / peak)
    # Made up in the preset's own attenuation (centibels, never below 0).
    makeup = round(200 * math.log10(1 / scale)) if scale < 1 else 0

    for left, ls, n, res in mixes:
        start = len(out_pcm)
        out_pcm.extend(max(-32768, min(32767, round(v * scale))) for v in res)
        end = len(out_pcm)
        out_pcm.extend([0] * TAIL)
        loop_end = min(start + round((ls.loop_end - ls.start) * UP / DOWN), end - 1)
        loop_len = round((ls.loop_end - ls.loop_start) * UP / DOWN)
        name = ls.name.replace("(L)", "").strip()
        samples.append(sf2.Sample(name, start, end, loop_end - loop_len, loop_end,
                                  ls.rate * UP // DOWN, ls.pitch, ls.correction, 0, sf2.MONO))
        gens = [g for g in left.gens if g.oper not in (sf2.GEN_PAN, sf2.GEN_SAMPLE_ID)]
        gens.append(sf2.Gen(sf2.GEN_SAMPLE_ID, len(samples) - 1))
        zones.append(sf2.Zone(gens, left.mods))
        print(f"{name:20s} {n:7d} -> {end - start:7d} frames")

    preset_zones = []
    for z in preset.zones:
        gens = []
        for g in z.gens:
            if g.oper == sf2.GEN_INSTRUMENT:
                g = sf2.Gen(g.oper, 0)
            elif g.oper == ATTENUATION and makeup:
                g = sf2.Gen(g.oper, max(0, g.signed - makeup))
            gens.append(g)
        preset_zones.append(sf2.Zone(gens, z.mods))

    info = [
        (b"ifil", b"\x02\x00\x01\x00"),
        (b"isng", b"E-mu 10K1\x00"),
        (b"INAM", b"Fluid R3 GM Yamaha Grand Piano\x00"),
        (b"ICRD", b"Feb 24. 2008\x00"),
        (b"IENG", b"Frank Wen\x00"),
        (b"ICOP", b"Frank Wen 2000-2002, 2008; Toby Smithe 2008\x00"),
        (b"ICMT", b"Licensed under the MIT License. Program 0 of FluidR3_GM.sf2, "
                  b"stereo pairs mixed to mono and resampled to 24 kHz for Advent Praise.\x00"),
        (b"ISFT", b"extract_piano.py\x00"),
    ]
    if sys.byteorder == "big":
        out_pcm.byteswap()
    out = sf2.SoundFont(info, out_pcm.tobytes(),
                        [sf2.Preset(preset.name, 0, 0, 0, 0, 0, preset_zones)],
                        [sf2.Instrument(inst.name, zones)], samples)
    sf2.write(out, dst)
    print(f"wrote {dst}: {os.path.getsize(dst):,} bytes, {len(samples)} samples, "
          f"gain {scale:.3f} (attenuation -{makeup} cB), sha256 {sha256(dst)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", help="FluidR3_GM.sf2, or a scratch folder with --download")
    parser.add_argument("output", help="where to write piano.sf2")
    parser.add_argument("--download", action="store_true", help="fetch and verify the Debian package into SOURCE")
    args = parser.parse_args()
    src = download(args.source) if args.download else args.source
    if sha256(src) != SF2_SHA256:
        sys.exit(f"{src} is not the expected FluidR3_GM.sf2 (sha256 {SF2_SHA256})")
    build(src, args.output)


if __name__ == "__main__":
    main()
