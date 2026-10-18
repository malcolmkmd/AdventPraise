import convert, sys
for a in sys.argv[1:]:
    n = int(a); info, st = convert.parse(f'src/nwc/{n:03d}.nwc', convert.OVERRIDES.get(str(n), {}).get('patch'))
    lines = convert.load(f'src/nwc/{n:03d}.nwc')
    for si, s in enumerate(st):
        t = convert.staff_timeline(s)
        b = [0.0] + t['bars'] + [t['total']]
        ts = t['ts0']; L = int(ts.split('/')[0]) * 4 / int(ts.split('/')[1])
        for i in range(1, len(b) - 2):
            if abs((b[i + 1] - b[i]) - L) > 1e-6 and not t['ts_events'][1:]:
                print(n, 'staff', si + 1, 'bar', i + 1, b[i], b[i + 1], 'len', b[i + 1] - b[i], 'ts', ts)
