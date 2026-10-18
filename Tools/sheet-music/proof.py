"""proof.py NNN... -> build/proof/NNN.png : Cyber Hymnal PDF (top) above our iPad render (bottom)."""
import sys, os, subprocess, io, cairosvg
from PIL import Image
ROOT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(f'{ROOT}/build/proof', exist_ok=True)
for a in sys.argv[1:]:
    n = int(a)
    subprocess.run(['pdftoppm', '-r', '80', '-png', f'{ROOT}/src/pdf/{n:03d}.pdf', f'/tmp/pp{n}'], check=True)
    pages = sorted(p for p in os.listdir('/tmp') if p.startswith(f'pp{n}-') or p == f'pp{n}.png')
    pdfs = [Image.open('/tmp/' + p).convert('RGB') for p in pages]
    svg = open(f'{ROOT}/build/svg/pad/{n:03d}.svg').read().replace('fill="currentColor"', 'fill="black"').replace('currentColor', 'black')
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=1100, background_color='white')
    ours = Image.open(io.BytesIO(png)).convert('RGB')
    W = max([ours.width] + [p.width for p in pdfs]); H = sum(p.height for p in pdfs) + ours.height + 20
    out = Image.new('RGB', (W, H), 'white'); y = 0
    for p in pdfs: out.paste(p, (0, y)); y += p.height
    out.paste(Image.new('RGB', (W, 20), (255, 0, 0)), (0, y)); y += 20
    out.paste(ours, (0, y))
    out.save(f'{ROOT}/build/proof/{n:03d}.png')
    for p in pages: os.remove('/tmp/' + p)
    print(n, out.size)
