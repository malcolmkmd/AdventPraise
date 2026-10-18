"""Automatic checks: NWC score vs the app's MIDI (soprano + bass pitch sequences), lyrics vs app text, render sanity.
Writes build/checks.json and build/checks.csv."""
import json, os, glob, difflib, collections, csv, sys
import mido
ROOT = os.path.dirname(os.path.abspath(__file__))
MIDI = os.path.normpath(os.path.join(ROOT, '../../AdventPraise/Resources/Midi'))
EPS = 1e-6

def midi_voices(path):
    m = mido.MidiFile(path); tpb = m.ticks_per_beat
    t = 0; on = {}; ev = []
    for x in mido.merge_tracks(m.tracks):
        t += x.time
        if x.type == 'note_on' and x.velocity > 0: on[(x.channel, x.note)] = t
        elif x.type in ('note_off', 'note_on'):
            k = (x.channel, x.note)
            if k in on: s = on.pop(k); ev.append((s / tpb, t / tpb, x.channel, x.note))
    chans = sorted(set(e[2] for e in ev))
    def top(ch, hi=True):
        es = [e for e in ev if e[2] == ch]
        by = collections.defaultdict(list)
        for e in es: by[round(e[0] * 8) / 8].append(e[3])
        # an onset counts for a voice if it is the top (or bottom) note sounding then
        seq = []
        for on_, ps in sorted(by.items()):
            seq.append(max(ps) if hi else min(ps))
        return seq
    if len(chans) < 2: return None, None
    return top(chans[0], True), top(chans[1], False)

def collapse(seq):
    return [p for i, p in enumerate(seq) if i == 0 or p != seq[i - 1]]

def score(a, b):
    """similarity of two pitch sequences, allowing a constant transposition"""
    best = (0, 0)
    for shift in range(-12, 13):
        r = difflib.SequenceMatcher(None, [x + shift for x in a], b, autojunk=False).ratio()
        if r > best[0]: best = (r, shift)
    return best

from music21 import converter
IRREG = {}
def xml_voices(n):
    sc = converter.parse(f'{ROOT}/build/xml/{n:03d}.musicxml')
    bad = []
    ms = list(sc.parts[0].getElementsByClass('Measure'))
    L = None
    for k, m in enumerate(ms):
        tss = list(m.getElementsByClass('TimeSignature'))
        if tss: L = tss[0].barDuration.quarterLength
        ln = max([float(v.highestTime) for v in m.voices] or [0])
        if L and ln - L > 1e-6 and 0 < k < len(ms) - 1:
            bad.append('m%s=%.2f/%.2f' % (m.number, ln, L))
    IRREG[n] = bad
    res = []
    for pi, want in ((0, '1'), (1, '2')):
        seq = []
        part = sc.parts[pi]
        for m in part.getElementsByClass('Measure'):
            for v in m.voices:
                if v.id != want: continue
                for o in v.notesAndRests:
                    if o.isRest: continue
                    p = (max(x.midi for x in o.pitches) if pi == 0 else min(x.midi for x in o.pitches))
                    if o.tie is not None and o.tie.type in ('stop', 'continue'): continue
                    seq.append((round(float(m.offset + o.offset), 3), p))
        res.append(seq)
    return res

rows = []; out = {}
render = json.load(open(f'{ROOT}/build/render.json')) if os.path.exists(f'{ROOT}/build/render.json') else {}
for rp in sorted(glob.glob(f'{ROOT}/build/report/*.json')):
    r = json.load(open(rp)); n = r['num']
    mp = f'{ROOT}/src/mid/085-ellacombe.mid' if n == 85 else f'{MIDI}/hymn-{n:03d}.mid'
    ms, mb = midi_voices(mp)
    # NWC soprano onsets: ties are merged already; repeated same pitch counts separately in both
    ns = [p for _, _, p in r['soprano']]; nb = [p for _, _, p in r['bass']]
    s_sim, s_shift = score(collapse(ns), collapse(ms)) if ms else (0, 0)
    b_sim, b_shift = score(collapse(nb), collapse(mb)) if mb else (0, 0)
    lyr = r['lyrics']
    issues = []
    xs, xb = xml_voices(n)
    fid_s = [(round(a, 3), p) for a, _, p in r['soprano']] == xs
    fid_b = [(round(a, 3), p) for a, _, p in r['bass']] == xb
    if IRREG.get(n): issues.append('irregular measures: ' + ', '.join(IRREG[n]))
    if not fid_s: issues.append('CONVERSION: soprano in score differs from NWC source')
    if not fid_b: issues.append('CONVERSION: bass in score differs from NWC source')
    if s_sim < 0.9: issues.append('soprano vs MIDI %.2f' % s_sim)
    if b_sim < 0.85: issues.append('bass vs MIDI %.2f' % b_sim)
    if s_shift or b_shift: issues.append('MIDI transposed %+d/%+d' % (s_shift, b_shift))
    if r.get('overflow', 0) > 0: issues.append('lyrics overflow by %d syllables' % r['overflow'])
    cyber = [l for l in lyr if l['source'] == 'cyber' and not str(l.get('why', '')).startswith('refrain (app')]
    missing = [l for l in lyr if l['source'] == 'missing']
    w = [x for x in r['warnings'] if x != '3+ note chord']
    if w: issues.append('; '.join(w))
    rend = render.get(str(n), {})
    if 'error' in rend: issues.append('render: ' + rend['error'])
    hard = [i for i in issues if i.startswith(('CONVERSION', 'render', 'lyrics overflow', 'staves differ', 'overlapping', 'octave', 'irregular'))] or (s_sim < 0.9)
    status = 'ok' if not issues else ('proofread' if hard else 'midi-differs')
    out[n] = dict(num=n, title=r['title'], status=status, soprano_sim=round(s_sim, 3), bass_sim=round(b_sim, 3),
                  issues=issues, lyric_lines_cyber_wording=[l['line'] for l in cyber], verses_not_under_music=[l['why'] for l in missing],
                  lyric_detail=lyr)
    rows.append([n, r['title'], status, round(s_sim, 3), round(b_sim, 3), ' | '.join(issues), len(cyber), len(missing)])
json.dump(out, open(f'{ROOT}/build/checks.json', 'w'), indent=1)
with open(f'{ROOT}/build/checks.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['number', 'title', 'status', 'soprano_vs_midi', 'bass_vs_midi', 'issues', 'lines_with_cyber_hymnal_wording', 'app_verses_not_under_music']); w.writerows(rows)
c = collections.Counter(x['status'] for x in out.values())
print(c, len(out))
