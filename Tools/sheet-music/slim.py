"""slim(svg): strip verovio's semantic wrappers (class/id on groups) and shorten glyph ids; drawing is unchanged."""
import re
def slim(svg):
    refs = set(re.findall(r'href="#([^"]+)"', svg))
    short = {r: 'g%d' % i for i, r in enumerate(sorted(refs))}
    svg = re.sub(r' id="([^"]+)"', lambda m: ' id="%s"' % short[m.group(1)] if m.group(1) in short else '', svg)
    svg = re.sub(r'href="#([^"]+)"', lambda m: 'href="#%s"' % short[m.group(1)], svg)
    def cls(m):
        c = m.group(1).split()
        if c and c[0] in ('ending', 'fing', 'reh', 'tempo'): return ' font-weight="bold"'
        if c and c[0] in ('dir', 'dynam', 'mNum'): return ' font-style="italic"'
        return ''
    svg = re.sub(r' class="([^"]*)"', cls, svg)
    svg = re.sub(r'<style[^>]*>.*?</style>', '<style type="text/css">ellipse,path,polygon,polyline,rect{stroke:currentColor}</style>', svg, flags=re.S)
    svg = re.sub(r' data-[a-z-]+="[^"]*"', '', svg)
    # unwrap attribute-less groups
    prev = None
    while prev != svg:
        prev = svg
        svg = re.sub(r'<g>((?:(?!<g[ >]|</g>).)*)</g>', r'\1', svg, flags=re.S)
    svg = re.sub(r'<g></g>|<g/>', '', svg)
    svg = re.sub(r'>\s+<', '><', svg)
    return svg
