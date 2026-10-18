"""Render build/xml/NNN.musicxml to one tall SVG per layout (phone, pad), coloured with currentColor.
Writes build/svg/{phone,pad}/NNN.svg and build/render.json. Usage: render.py [NNN ...]"""
import sys, os, re, glob, json
import verovio
ROOT = os.path.dirname(os.path.abspath(__file__))
LAYOUTS = {
    # pageWidth in verovio units (1/10 mm at scale 100); scale shrinks the music relative to the page.
    'phone': {'pageWidth': 1450, 'scale': 55},
    'pad': {'pageWidth': 2400, 'scale': 50},
}
def render(num, layout):
    tk = verovio.toolkit()
    o = LAYOUTS[layout]
    tk.setOptions({'pageWidth': o['pageWidth'], 'pageHeight': 60000, 'scale': o['scale'], 'adjustPageHeight': True,
                   'breaks': 'auto', 'pageMarginLeft': 20, 'pageMarginRight': 20, 'pageMarginTop': 20, 'pageMarginBottom': 20,
                   'header': 'none', 'footer': 'none', 'lyricSize': 4.8, 'lyricTopMinMargin': 2, 'spacingSystem': 10,
                   'svgViewBox': True, 'svgRemoveXlink': True, 'removeIds': True, 'svgFormatRaw': True,
                   'justifyVertically': False, 'mnumInterval': 0, 'barLineWidth': 0.4, 'staffLineWidth': 0.2})
    if not tk.loadFile(f'{ROOT}/build/xml/{num:03d}.musicxml'): raise RuntimeError('verovio could not load')
    if tk.getPageCount() != 1: raise RuntimeError('more than one page: %d' % tk.getPageCount())
    svg = tk.renderToSVG(1)
    # colours: everything follows CSS `color`, so the app picks ink for light/dark
    svg = svg.replace('fill="black"', 'fill="currentColor"').replace('stroke="black"', 'stroke="currentColor"')
    svg = svg.replace('#000000', 'currentColor').replace('#000', 'currentColor')
    svg = re.sub(r'<svg ([^>]*?)width="[^"]*" height="[^"]*"', r'<svg \1', svg, count=1)
    svg = svg.replace('color="black"', 'fill="currentColor"', 1)
    svg = re.sub(r'<title>.*?</title>|<desc>.*?</desc>', '', svg)
    m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg)
    w, h = (float(m.group(1)), float(m.group(2))) if m else (0, 0)
    os.makedirs(f'{ROOT}/build/svg/{layout}', exist_ok=True)
    open(f'{ROOT}/build/svg/{layout}/{num:03d}.svg', 'w').write(svg)
    return {'w': w, 'h': h, 'bytes': len(svg)}
if __name__ == '__main__':
    nums = [int(a) for a in sys.argv[1:]] or sorted(int(os.path.basename(p)[:3]) for p in glob.glob(f'{ROOT}/build/xml/*.musicxml'))
    out = json.load(open(f'{ROOT}/build/render.json')) if os.path.exists(f'{ROOT}/build/render.json') else {}
    for n in nums:
        try:
            out[str(n)] = {l: render(n, l) for l in LAYOUTS}
            print(n, out[str(n)], flush=True)
        except Exception as e:
            out[str(n)] = {'error': repr(e)}; print(n, 'FAIL', e, flush=True)
    json.dump(out, open(f'{ROOT}/build/render.json', 'w'), indent=1)
