"""Rasterise every shipped SVG before and after slim() and confirm the pixels are identical."""
import cairosvg, io, json, os, sys
from PIL import Image, ImageChops
from slim import slim
ROOT = os.path.dirname(os.path.abspath(__file__))
man = json.load(open(f'{ROOT}/build/bundle/SheetMusic/sheet-music-manifest.json'))
def r(s): return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.replace('currentColor', 'black').encode(), output_width=1100, background_color='white'))).convert('L')
bad = []
for k in man['hymns']:
    for lay in ('phone', 'pad'):
        s = open(f'{ROOT}/build/svg/{lay}/{int(k):03d}.svg').read()
        if ImageChops.difference(r(s), r(slim(s))).getbbox(): bad.append((k, lay))
print('checked', 2 * len(man['hymns']), 'different', bad)
