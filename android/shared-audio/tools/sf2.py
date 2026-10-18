"""Minimal SoundFont 2 reader and writer (standard library only).

Enough of the SF2.01/2.04 format to pull one preset, with the instruments and
samples it uses, out of a big General MIDI bank and write it as a small bank.
Used by extract_piano.py.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field

# Generator operators we need by number (SF2 spec, section 8.1.2).
GEN_PAN = 17
GEN_KEY_RANGE = 43
GEN_VEL_RANGE = 44
GEN_INSTRUMENT = 41
GEN_SAMPLE_ID = 53
GEN_START_ADDRS_OFFSET = 0
GEN_END_ADDRS_OFFSET = 1
GEN_STARTLOOP_ADDRS_OFFSET = 2
GEN_ENDLOOP_ADDRS_OFFSET = 3
GEN_START_ADDRS_COARSE = 4
GEN_END_ADDRS_COARSE = 12
GEN_STARTLOOP_ADDRS_COARSE = 45
GEN_ENDLOOP_ADDRS_COARSE = 50

# Sample types (section 7.10).
MONO, RIGHT, LEFT, LINKED = 1, 2, 4, 8


@dataclass
class Gen:
    oper: int
    amount: int  # raw unsigned 16-bit

    @property
    def signed(self) -> int:
        return self.amount - 0x10000 if self.amount >= 0x8000 else self.amount


@dataclass
class Mod:
    raw: bytes  # 10 bytes, copied through untouched


@dataclass
class Zone:
    gens: list[Gen] = field(default_factory=list)
    mods: list[Mod] = field(default_factory=list)

    def get(self, oper: int) -> Gen | None:
        return next((g for g in self.gens if g.oper == oper), None)


@dataclass
class Preset:
    name: str
    preset: int
    bank: int
    library: int
    genre: int
    morphology: int
    zones: list[Zone]


@dataclass
class Instrument:
    name: str
    zones: list[Zone]


@dataclass
class Sample:
    name: str
    start: int
    end: int
    loop_start: int
    loop_end: int
    rate: int
    pitch: int
    correction: int
    link: int
    type: int


@dataclass
class SoundFont:
    info: list[tuple[bytes, bytes]]
    smpl: bytes
    presets: list[Preset]
    instruments: list[Instrument]
    samples: list[Sample]


def _chunks(data: bytes, offset: int, end: int):
    while offset + 8 <= end:
        cid, size = struct.unpack_from("<4sI", data, offset)
        body = offset + 8
        yield cid, body, size
        offset = body + size + (size & 1)


def _name(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("latin-1")


def read(path: str) -> SoundFont:
    with open(path, "rb") as f:
        data = f.read()
    riff, size, form = struct.unpack_from("<4sI4s", data, 0)
    if riff != b"RIFF" or form != b"sfbk":
        raise ValueError("not a SoundFont 2 file")
    lists: dict[bytes, tuple[int, int]] = {}
    for cid, body, csize in _chunks(data, 12, 8 + size):
        if cid == b"LIST":
            lists[data[body:body + 4]] = (body + 4, body + csize)
    info = [(cid, data[b:b + s]) for cid, b, s in _chunks(data, *lists[b"INFO"])]
    smpl = b""
    for cid, b, s in _chunks(data, *lists[b"sdta"]):
        if cid == b"smpl":
            smpl = data[b:b + s]
    pdta = {cid: data[b:b + s] for cid, b, s in _chunks(data, *lists[b"pdta"])}

    def records(cid: bytes, fmt: str):
        raw = pdta[cid]
        n = struct.calcsize(fmt)
        return [struct.unpack_from(fmt, raw, i) for i in range(0, len(raw), n)]

    phdr = records(b"phdr", "<20sHHHIII")
    pbag = records(b"pbag", "<HH")
    pmod = [Mod(pdta[b"pmod"][i:i + 10]) for i in range(0, len(pdta[b"pmod"]), 10)]
    pgen = [Gen(o, a) for o, a in records(b"pgen", "<HH")]
    inst = records(b"inst", "<20sH")
    ibag = records(b"ibag", "<HH")
    imod = [Mod(pdta[b"imod"][i:i + 10]) for i in range(0, len(pdta[b"imod"]), 10)]
    igen = [Gen(o, a) for o, a in records(b"igen", "<HH")]
    shdr = records(b"shdr", "<20sIIIIIbbHH")

    def zones(bags, gens, mods, first, last):
        out = []
        for i in range(first, last):
            g0, m0 = bags[i]
            g1, m1 = bags[i + 1]
            out.append(Zone(gens[g0:g1], mods[m0:m1]))
        return out

    presets = [
        Preset(_name(r[0]), r[1], r[2], r[4], r[5], r[6],
               zones(pbag, pgen, pmod, r[3], phdr[i + 1][3]))
        for i, r in enumerate(phdr[:-1])
    ]
    instruments = [
        Instrument(_name(r[0]), zones(ibag, igen, imod, r[1], inst[i + 1][1]))
        for i, r in enumerate(inst[:-1])
    ]
    samples = [Sample(_name(r[0]), *r[1:]) for r in shdr[:-1]]
    return SoundFont(info, smpl, presets, instruments, samples)


def _chunk(cid: bytes, body: bytes) -> bytes:
    pad = b"\0" if len(body) & 1 else b""
    return struct.pack("<4sI", cid, len(body)) + body + pad


def _list(kind: bytes, body: bytes) -> bytes:
    return _chunk(b"LIST", kind + body)


def _zstr(text: str, size: int = 20) -> bytes:
    return text.encode("latin-1")[:size - 1].ljust(size, b"\0")


def write(sf: SoundFont, path: str) -> None:
    info = b"".join(_chunk(cid, body) for cid, body in sf.info)
    sdta = _chunk(b"smpl", sf.smpl)

    phdr = bytearray(); pbag = bytearray(); pmod = bytearray(); pgen = bytearray()
    bag = gen = mod = 0
    for p in sf.presets:
        phdr += struct.pack("<20sHHHIII", _zstr(p.name), p.preset, p.bank, bag, p.library, p.genre, p.morphology)
        for z in p.zones:
            pbag += struct.pack("<HH", gen, mod)
            for g in z.gens:
                pgen += struct.pack("<HH", g.oper, g.amount); gen += 1
            for m in z.mods:
                pmod += m.raw; mod += 1
            bag += 1
    phdr += struct.pack("<20sHHHIII", _zstr("EOP"), 0, 0, bag, 0, 0, 0)
    pbag += struct.pack("<HH", gen, mod)
    pmod += bytes(10)
    pgen += struct.pack("<HH", 0, 0)

    ihdr = bytearray(); ibag = bytearray(); imod = bytearray(); igen = bytearray()
    bag = gen = mod = 0
    for inst in sf.instruments:
        ihdr += struct.pack("<20sH", _zstr(inst.name), bag)
        for z in inst.zones:
            ibag += struct.pack("<HH", gen, mod)
            for g in z.gens:
                igen += struct.pack("<HH", g.oper, g.amount); gen += 1
            for m in z.mods:
                imod += m.raw; mod += 1
            bag += 1
    ihdr += struct.pack("<20sH", _zstr("EOI"), bag)
    ibag += struct.pack("<HH", gen, mod)
    imod += bytes(10)
    igen += struct.pack("<HH", 0, 0)

    shdr = bytearray()
    for s in sf.samples:
        shdr += struct.pack("<20sIIIIIbbHH", _zstr(s.name), s.start, s.end, s.loop_start, s.loop_end,
                            s.rate, s.pitch, s.correction, s.link, s.type)
    shdr += struct.pack("<20sIIIIIbbHH", _zstr("EOS"), 0, 0, 0, 0, 0, 0, 0, 0, 0)

    pdta = b"".join([
        _chunk(b"phdr", bytes(phdr)), _chunk(b"pbag", bytes(pbag)), _chunk(b"pmod", bytes(pmod)),
        _chunk(b"pgen", bytes(pgen)), _chunk(b"inst", bytes(ihdr)), _chunk(b"ibag", bytes(ibag)),
        _chunk(b"imod", bytes(imod)), _chunk(b"igen", bytes(igen)), _chunk(b"shdr", bytes(shdr)),
    ])
    body = b"sfbk" + _list(b"INFO", info) + _list(b"sdta", sdta) + _list(b"pdta", pdta)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sI", b"RIFF", len(body)) + body)
