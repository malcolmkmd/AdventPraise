import json, os, time, urllib.request, urllib.parse, concurrent.futures as cf
ch = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sources.json')))
jobs = []
for n, d in ch.items():
    n = int(n)
    if n == 85:
        base = 'http://hymntime.com/tch/'
        jobs += [(base + 'nwc/e/l/l/a/Ellacombe.nwc', f'src/nwc/{n:03d}.nwc'), (base + 'pdf/en/e/l/l/a/Ellacombe.pdf', f'src/pdf/{n:03d}.pdf'),
                 (base + 'mid/e/l/l/a/ellacombe.mid', f'src/mid/{n:03d}-ellacombe.mid')]
        continue
    jobs += [(d['nwc'], f'src/nwc/{n:03d}.nwc'), (d['pdf'], f'src/pdf/{n:03d}.pdf')]
def get(job):
    url, path = job
    if os.path.exists(path) and os.path.getsize(path) > 200: return path, 'cached'
    q = urllib.parse.quote(url, safe=':/()')
    err = None
    for i in range(5):
        try:
            r = urllib.request.urlopen(urllib.request.Request('https://web.archive.org/web/2024id_/' + q, headers={'User-Agent': 'Mozilla/5.0 research'}), timeout=60)
            d = r.read()
            if len(d) < 200 or d[:15].lower().startswith(b'<!doctype html'): raise Exception('html/short %d' % len(d))
            open(path, 'wb').write(d); return path, len(d)
        except Exception as e: err = e; time.sleep(4 * (i + 1))
    return path, 'ERR %s' % err
with cf.ThreadPoolExecutor(4) as ex:
    for p, r in ex.map(get, jobs): print(p, r, flush=True)
