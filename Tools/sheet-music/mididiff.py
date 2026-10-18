import json, sys, mido, collections
import os
MIDI = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../AdventPraise/Resources/Midi'))
def top(path):
    m = mido.MidiFile(path); tpb = m.ticks_per_beat; t = 0; ev = []
    for x in mido.merge_tracks(m.tracks):
        t += x.time
        if x.type == 'note_on' and x.velocity > 0: ev.append((t / tpb, x.channel, x.note))
    ch = sorted(set(e[1] for e in ev))[0]
    by = collections.OrderedDict()
    for a, c, n in ev:
        if c == ch: by[round(a, 2)] = max(by.get(round(a, 2), 0), n)
    return list(by.items())
for a in sys.argv[1:]:
    n = int(a); r = json.load(open(f'build/report/{n:03d}.json'))
    ns = [(round(x, 2), p) for x, _, p in r['soprano']]
    ms = top(f'{MIDI}/hymn-{n:03d}.mid')
    # compare first pass (MIDI may repeat verses / repeats)
    import difflib
    sm = difflib.SequenceMatcher(None, [p for _, p in ns], [p for _, p in ms[:len(ns) + 20]], autojunk=False)
    diffs = [(op, ns[i1:i2][:4], ms[j1:j2][:4]) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != 'equal']
    print(n, 'nwc', len(ns), 'midi', len(ms), 'diffs', diffs[:5])
