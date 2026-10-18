import json, glob, convert
out = {}
for p in sorted(glob.glob('build/report/*.json')):
    r = json.load(open(p)); n = r['num']
    if 'underlay' not in r: continue
    info, st = convert.parse(f'src/nwc/{n:03d}.nwc', convert.OVERRIDES.get(str(n), {}).get('patch'))
    t = convert.staff_timeline(st[0])
    targets = [x for x in t['voices'][0] if x[2] is not None and x[3]]
    T = len(targets)
    # repeated section
    rs, re_ = None, None
    for b, s in zip(t['bars'], t['barstyles']):
        if s == 'MasterRepeatOpen' and rs is None: rs = b
        if s == 'MasterRepeatClose': re_ = b
    if re_ is not None:
        rs = rs or 0.0
        Trep = T + sum(1 for x in targets if rs - 1e-6 <= x[0] < re_ - 1e-6)
    else: Trep = T
    f = r['underlay_fit']; vs = f['verse_syllables']; R = f['refrain_syllables']
    cands = {T, Trep}
    best = min(abs(v - c) for v in vs for c in ({x - R for x in cands} | cands))
    out[n] = dict(T=T, Trep=Trep, verses=vs, refrain=R, best=best, underlaid=bool(r['underlay']))
    if not r['underlay']: print(n, r['title'], out[n])
json.dump(out, open('build/meterfit.json', 'w'), indent=1)
