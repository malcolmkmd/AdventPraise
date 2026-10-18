"""bundle.py -> build/bundle/SheetMusic/sheet-music-{phone,pad}.pack + sheet-music-manifest.json

Each pack is the slimmed SVGs (slim.py), each one raw DEFLATE (RFC 1951, which
NSData.decompressed(using: .zlib) reads), back to back. The manifest gives each
hymn's offset and length in each pack and its page size. Two packs rather than
430 files, because the app target's synced folders copy resources flat.
Aborts on a hymn check.py flagged for proofreading unless proofread_ok.json clears it."""
import json, os, zlib, shutil
from slim import slim
ROOT = os.path.dirname(os.path.abspath(__file__))
hold = json.load(open(f'{ROOT}/hold.json')); held = set(hold['rights_unclear']) | set(hold['proofreading']) | set(hold.get('no_words', {}))
render = json.load(open(f'{ROOT}/build/render.json'))
checks = json.load(open(f'{ROOT}/build/checks.json'))
if isinstance(checks, list): checks = {str(c['num']): c for c in checks}
proof_ok = set(json.load(open(f'{ROOT}/proofread_ok.json'))['items'])
out = f'{ROOT}/build/bundle/SheetMusic'
shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
LAYOUTS = ('phone', 'pad')
man = {'version': 1, 'hymnal': 'english', 'source': 'The Cyber Hymnal (hymntime.com/tch)', 'format': 'svg+deflate',
       'packs': {lay: f'sheet-music-{lay}' for lay in LAYOUTS}, 'hymns': {}}
packs = {lay: open(f'{out}/sheet-music-{lay}.pack', 'wb') for lay in LAYOUTS}
tot_raw = tot_z = 0
for k, v in sorted(render.items(), key=lambda a: int(a[0])):
    if k in held or 'error' in str(v): continue
    if checks.get(k, {}).get('status') == 'proofread' and k not in proof_ok: raise SystemExit('unresolved proofread item %s' % k)
    n = int(k); entry = {}
    for lay in LAYOUTS:
        svg = slim(open(f'{ROOT}/build/svg/{lay}/{n:03d}.svg').read()).encode()
        c = zlib.compressobj(9, zlib.DEFLATED, -15); z = c.compress(svg) + c.flush()
        f = packs[lay]; o = f.tell(); f.write(z)
        tot_raw += len(svg); tot_z += len(z)
        entry[lay] = {'w': v[lay]['w'], 'h': v[lay]['h'], 'o': o, 'n': len(z)}
    man['hymns'][k] = entry
for f in packs.values(): f.close()
json.dump(man, open(f'{out}/sheet-music-manifest.json', 'w'), separators=(',', ':'))
print('hymns', len(man['hymns']), 'raw MB %.1f' % (tot_raw / 1e6), 'deflated MB %.1f' % (tot_z / 1e6))
