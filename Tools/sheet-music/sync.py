"""MIDI <-> sheet music timing. For each rendered hymn, works out when every note of the score
sounds in the accompaniment MIDI (one pass through the tune, as the app plays it once per verse),
and where each measure, note and syllable sits on the phone and pad pages.

Timing: the score's melody (staff 1, voice 1, repeats unfolded) is aligned with the MIDI's top
line by pitch (difflib, allowing a transposition); matched notes become anchors of a piecewise
linear map from score beats to MIDI seconds (MIDI tempo map applied), so tempo changes and
fermatas in the MIDI are followed. Geometry: the un-slimmed verovio SVG (build/svg) is read
measure by measure: staff lines give each measure's box, noteheads and syllables are taken in
score order, so they line up with the music21 notes 1:1 (checked; a hymn whose counts differ
keeps measure-level sync only).

Writes build/sync/NNN.json and build/sync.json (summary). Usage: sync.py [NNN ...]"""
import sys, os, re, glob, json, bisect, difflib
import xml.etree.ElementTree as ET
import mido
import music21 as m21

ROOT = os.path.dirname(os.path.abspath(__file__))
MIDI = os.environ.get('AP_MIDI', os.path.join(ROOT, '..', '..', 'AdventPraise', 'Resources', 'Midi'))
if not os.path.isdir(MIDI):
    MIDI = '/workspace/advent-praise/AdventPraise/AdventPraise/Resources/Midi'
SVGNS = '{http://www.w3.org/2000/svg}'
LAYOUTS = ('phone', 'pad', 'line')


# ---------------- MIDI ----------------
def midi_melody(path):
    """[(seconds, pitch)] for the top note at each onset of the first channel, and the file length in seconds."""
    mf = mido.MidiFile(path)
    tpb = mf.ticks_per_beat
    tempo = 500000
    tick = 0; sec = 0.0
    on = {}; notes = []
    for msg in mido.merge_tracks(mf.tracks):
        if msg.time:
            sec += mido.tick2second(msg.time, tpb, tempo); tick += msg.time
        if msg.type == 'set_tempo':
            tempo = msg.tempo
        elif msg.type == 'note_on' and msg.velocity > 0:
            on[(msg.channel, msg.note)] = sec
            notes.append((sec, msg.channel, msg.note))
    end = sec
    chans = sorted(set(c for _, c, _ in notes))
    if not chans: return [], end
    by = {}
    for s, c, p in notes:
        if c != chans[0]: continue
        k = round(s, 2)
        by[k] = max(by.get(k, 0), p)
    # onsets within 30 ms are one chord
    out = []
    for s in sorted(by):
        if out and s - out[-1][0] < 0.03:
            out[-1] = (out[-1][0], max(out[-1][1], by[s]))
        else:
            out.append((s, by[s]))
    return out, end


# ---------------- score ----------------
def unfold_order(ms, part):
    """Measure indices in performance order (repeats and 1st/2nd endings)."""
    ending = {}
    for rb in part.recurse().getElementsByClass(m21.spanner.RepeatBracket):
        try: num = int(str(rb.number).split(',')[0])
        except ValueError: num = 1
        for m in rb.getSpannedElements():
            if m in ms: ending[ms.index(m)] = num
    # a repeat that opens and never closes (the source ends without the closing barline) runs to the end
    opens = [i for i, m in enumerate(ms) if isinstance(m.leftBarline, m21.bar.Repeat) and m.leftBarline.direction == 'start']
    closes = [i for i, m in enumerate(ms) if isinstance(m.rightBarline, m21.bar.Repeat) and m.rightBarline.direction == 'end']
    open_end = bool(opens) and (not closes or max(closes) < max(opens))
    order = []; i = 0; start = 0; jumped = set(); passno = 1; guard = 0
    while i < len(ms) and guard < 10 * len(ms):
        guard += 1
        m = ms[i]
        lb = m.leftBarline
        if isinstance(lb, m21.bar.Repeat) and lb.direction == 'start' and i not in jumped:
            if passno == 1: start = i
        e = ending.get(i)
        if e is not None and e != passno:
            i += 1; continue
        order.append(i)
        rb_ = m.rightBarline
        closes_here = (isinstance(rb_, m21.bar.Repeat) and rb_.direction == 'end') or (open_end and i == len(ms) - 1)
        if open_end and i == len(ms) - 1 and i not in jumped: start = max(opens)
        if closes_here and i not in jumped:
            jumped.add(i); passno += 1; i = start; continue
        if e is None and passno > 1 and i > max(jumped or {-1}):
            passno = 1
        i += 1
    return order


def score_notes(num):
    """Notes of staff 1 in score order: dicts with measure, layer, offset in measure, pitch, tie continuation."""
    sc = m21.converter.parse(f'{ROOT}/build/xml/{num:03d}.musicxml')
    part = sc.parts[0]
    ms = list(part.getElementsByClass(m21.stream.Measure))
    notes = []
    lens = []
    for mi, m in enumerate(ms):
        lens.append(float(m.duration.quarterLength))
        voices = list(m.voices) or [m]
        for li, v in enumerate(voices):
            for n in v.getElementsByClass(m21.note.GeneralNote):
                if n.isRest or n.duration.isGrace: continue
                pitch = max(p.midi for p in n.pitches)
                cont = n.tie is not None and n.tie.type in ('stop', 'continue')
                notes.append({'m': mi, 'l': li, 'q': float(n.offset), 'p': pitch, 'c': cont,
                              'lyr': sorted(l.number for l in n.lyrics if l.text)})
    return ms, part, notes, lens


# ---------------- geometry ----------------
def floats(d):
    return [float(x) for x in re.findall(r'-?[\d.]+', d)]


def svg_geometry(num, layout):
    root = ET.parse(f'{ROOT}/build/svg/{layout}/{num:03d}.svg').getroot()
    W = float(root.get('viewBox').split()[2])
    inner = root.find(f'.//{SVGNS}svg')
    iw = float(inner.get('viewBox').split()[2])
    k = W / iw
    margin = inner.find(f'{SVGNS}g')
    mx, my = floats(margin.get('transform') or 'translate(0,0)')[:2]
    X = lambda v: round((v + mx) * k, 1)
    Y = lambda v: round((v + my) * k, 1)
    measures = []; notes = []; spaces = []; msys = []
    systems = [g for g in margin.iter(f'{SVGNS}g') if g.get('class') == 'system']
    in_system = []
    for si, sg in enumerate(systems):
        for mg in sg.iter(f'{SVGNS}g'):
            if mg.get('class') == 'measure': in_system.append((si, mg))
    for si, mg in in_system:
        staves = [g for g in mg if g.get('class') == 'staff']
        ys = []; xs = []
        for st in staves:
            for p in st.findall(f'{SVGNS}path'):
                f = floats(p.get('d'))
                if len(f) == 4 and abs(f[1] - f[3]) < 0.5:
                    xs += [f[0], f[2]]; ys.append(f[1])
        if not xs: continue
        if staves:
            ly = sorted(floats(p.get('d'))[1] for p in staves[0].findall(f'{SVGNS}path') if len(floats(p.get('d'))) == 4)
            if len(ly) >= 5: spaces.append((ly[4] - ly[0]) / 4)
        x0, x1 = min(xs), max(xs)
        y0 = min(ys); y1 = max(ys)
        measures.append([X(x0), Y(y0), round((x1 - x0) * k, 1), round((y1 - y0) * k, 1)])
        msys.append(si)
        mindex = len(measures) - 1
        if not staves: continue
        for li, layer in enumerate([g for g in staves[0] if g.get('class') == 'layer']):
            for ng in layer.iter(f'{SVGNS}g'):
                if ng.get('class') != 'note': continue
                head = ng.find(f'{SVGNS}g[@class="notehead"]/{SVGNS}use')
                hx, hy = (floats(head.get('transform'))[:2] if head is not None else (0, 0))
                syl = []
                for vg in ng.findall(f'{SVGNS}g[@class="verse"]'):
                    t = vg.find(f'{SVGNS}title')
                    try: vn = int(t.text) if t is not None else 1
                    except ValueError: vn = 1
                    for sg in vg.findall(f'{SVGNS}g'):
                        if not (sg.get('class') or '').startswith('syl'): continue
                        tx = sg.find(f'{SVGNS}text')
                        if tx is None: continue
                        text = ''.join(tx.itertext()).strip()
                        if not text: continue
                        fs = 432.0
                        for ts in tx.iter(f'{SVGNS}tspan'):
                            if ts.get('font-size') and ts.get('font-size') != '0px':
                                fs = float(ts.get('font-size').rstrip('px'))
                        w = len(text) * fs * 0.52
                        syl.append([vn, X(float(tx.get('x'))), Y(float(tx.get('y'))), round(w * k, 1), round(fs * k, 1)])
                notes.append({'m': mindex, 'l': li, 'x': X(hx), 'y': Y(hy), 's': syl})
    ss = round(sorted(spaces)[len(spaces) // 2] * k, 2) if spaces else 0
    # systems: bands split halfway between one system's staves and the next, so text above
    # (Refrain, endings, measure numbers) and verses below (refrains under the bass) stay in
    # their system; the first runs from the top of the page, the last to the bottom
    H = float(root.get('viewBox').split()[3])
    used = sorted(set(msys))
    remap = {s_: i for i, s_ in enumerate(used)}
    msys = [remap[s_] for s_ in msys]
    spans = []
    for i in range(len(used)):
        bs = [b for b, s_ in zip(measures, msys) if s_ == i]
        spans.append((min(b[0] for b in bs), min(b[1] for b in bs), max(b[0] + b[2] for b in bs), max(b[1] + b[3] for b in bs)))
    bands = []
    for i, (x0, y0, x1, y1) in enumerate(spans):
        top = 0 if i == 0 else (spans[i - 1][3] + y0) / 2
        bottom = H if i == len(spans) - 1 else (y1 + spans[i + 1][1]) / 2
        pad = ss * 1.2
        left = max(0, x0 - pad); right = min(W, x1 + pad)
        bands.append([round(left, 1), round(top, 1), round(right - left, 1), round(bottom - top, 1)])
    return measures, notes, ss, bands, msys


# ---------------- alignment ----------------
def build(num):
    ms, part, notes, lens = score_notes(num)
    order = unfold_order(ms, part)
    starts = [0.0]
    for mi in order: starts.append(starts[-1] + lens[mi])
    # performance events: each note occurrence (score beat position)
    perf = []  # (beat, noteIndex)
    mstarts = []  # (beat, measureIndex)
    for oi, mi in enumerate(order):
        mstarts.append((starts[oi], mi))
        for ni, n in enumerate(notes):
            if n['m'] == mi: perf.append((starts[oi] + n['q'], ni))
    perf.sort()
    total_beats = starts[-1]
    mel = [(b, notes[ni]['p']) for b, ni in perf if notes[ni]['l'] == 0 and not notes[ni]['c']]
    # collapse simultaneous (shouldn't happen in voice 1)
    midi, mlen = midi_melody(f'{MIDI}/hymn-{num:03d}.mid')
    a = [p for _, p in mel]; b = [p for _, p in midi]
    best = (0, 0, None)
    for shift in range(-12, 13):
        sm = difflib.SequenceMatcher(None, [x + shift for x in a], b, autojunk=False)
        r = sm.ratio()
        if r > best[0]: best = (r, shift, sm)
    ratio, shift, sm = best
    anchors = []
    if sm is not None:
        # dynamic time warping on pitch: monotonic, so local reorderings or extra notes in the MIDI
        # don't pull whole phrases out of place the way longest-block matching can
        A = [x + shift for x in a]; n_, m_ = len(A), len(b)
        INF = float('inf')
        D = [[INF] * (m_ + 1) for _ in range(n_ + 1)]; D[0][0] = 0
        for i in range(1, n_ + 1):
            Ai = A[i - 1]; Di = D[i]; Dp = D[i - 1]
            for j in range(1, m_ + 1):
                c = 0 if Ai == b[j - 1] else (0.6 if abs(Ai - b[j - 1]) <= 2 else 1)
                Di[j] = c + min(Dp[j - 1], Dp[j] + 0.5, Di[j - 1] + 0.5)
        i, j = n_, m_; path = []
        while i > 0 and j > 0:
            path.append((i - 1, j - 1))
            dg, up, lf = D[i - 1][j - 1], D[i - 1][j] + 0.5, D[i][j - 1] + 0.5
            if dg <= up and dg <= lf: i, j = i - 1, j - 1
            elif up <= lf: i -= 1
            else: j -= 1
        path.reverse()
        used_a = set(); used_b = set()
        for ia, jb in path:
            if A[ia] == b[jb] and ia not in used_a and jb not in used_b:
                used_a.add(ia); used_b.add(jb); anchors.append((mel[ia][0], midi[jb][0]))
    # keep strictly increasing
    clean = []
    for bt, s in anchors:
        if not clean or (bt > clean[-1][0] and s > clean[-1][1]): clean.append((bt, s))
    matched = len(clean) / max(len(a), 1)
    if len(clean) < 2:
        # no usable alignment: spread the score evenly over the file
        clean = [(0.0, 0.0), (total_beats, mlen)]
    bts = [c[0] for c in clean]; ss = [c[1] for c in clean]
    # global rate for extrapolation
    rate = (ss[-1] - ss[0]) / (bts[-1] - bts[0]) if bts[-1] > bts[0] else mlen / max(total_beats, 1)

    def at(beat):
        if beat <= bts[0]: return max(0.0, ss[0] - (bts[0] - beat) * rate)
        if beat >= bts[-1]: return ss[-1] + (beat - bts[-1]) * rate
        i = bisect.bisect_right(bts, beat)
        b0, b1, s0, s1 = bts[i - 1], bts[i], ss[i - 1], ss[i]
        return s0 + (beat - b0) * (s1 - s0) / (b1 - b0)

    ev = []
    for bt, ni in perf:
        if notes[ni]['c']: continue
        ev.append([round(at(bt), 3), ni])
    mev = [[round(at(bt), 3), mi] for bt, mi in mstarts]
    end_t = at(total_beats)
    geo = {}
    ok_geo = True
    for layout in LAYOUTS:
        boxes, gnotes, ss, bands, msys = svg_geometry(num, layout)
        if len(boxes) != len(ms):
            raise RuntimeError(f'{layout}: {len(boxes)} measures in SVG vs {len(ms)} in score')
        same = len(gnotes) == len(notes) and all(g['m'] == n['m'] and g['l'] == n['l'] for g, n in zip(gnotes, notes))
        if not same: ok_geo = False
        geo[layout] = {'ss': ss, 'sy': bands, 'ms': msys, 'm': boxes, 'n': [[g['x'], g['y'], g['s']] for g in gnotes] if same else []}
    out = {
        'len': round(mlen, 3),               # MIDI pass length (s), as the engine measures it
        'end': round(end_t, 3),              # where the score's last beat lands
        'match': round(matched, 3),          # share of melody notes matched to the MIDI
        'shift': shift,
        'm': mev,                            # [t, measure] in performance order
        'e': ev if ok_geo else [],           # [t, note] note onsets (staff 1, both voices), sorted
        'l': [n['l'] for n in notes] if ok_geo else [],  # voice of each note (0 melody)
        'nm': [n['m'] for n in notes] if ok_geo else [], # measure of each note
        'geo': geo,
    }
    rep = json.load(open(f'{ROOT}/build/report/{num:03d}.json'))
    out['v'] = rep.get('verse_numbers_in_score') or []
    return out


if __name__ == '__main__':
    nums = [int(a) for a in sys.argv[1:]] or sorted(int(os.path.basename(p)[:3]) for p in glob.glob(f'{ROOT}/build/svg/phone/*.svg'))
    os.makedirs(f'{ROOT}/build/sync', exist_ok=True)
    summ = json.load(open(f'{ROOT}/build/sync.json')) if os.path.exists(f'{ROOT}/build/sync.json') else {}
    for n in nums:
        try:
            d = build(n)
            json.dump(d, open(f'{ROOT}/build/sync/{n:03d}.json', 'w'), separators=(',', ':'))
            summ[str(n)] = {'match': d['match'], 'len': d['len'], 'end': d['end'], 'notes': bool(d['e']), 'measures': len(d['geo']['phone']['m']), 'perf_measures': len(d['m'])}
            print(n, summ[str(n)], flush=True)
        except Exception as e:
            summ[str(n)] = {'error': repr(e)}; print(n, 'FAIL', repr(e), flush=True)
    json.dump(summ, open(f'{ROOT}/build/sync.json', 'w'), indent=1)
