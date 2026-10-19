import collections
"""Production pipeline step: Cyber Hymnal NWC (2.75 text) -> MusicXML with app lyrics where they align.
Writes build/xml/NNN.musicxml and build/report/NNN.json. Usage: convert.py [NNN ...] (default: all in src/nwc)
"""
import sys, re, zlib, os, json, math, glob, difflib, unicodedata
from music21 import chord, stream, note, meter, key, clef, metadata, pitch as m21pitch, tie, spanner, bar as m21bar, expressions
import pyphen

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(ROOT, '../../AdventPraise/Resources'))
os.makedirs(f'{ROOT}/build/xml', exist_ok=True); os.makedirs(f'{ROOT}/build/report', exist_ok=True)
APP = {h['number']: h for h in json.load(open(f'{REPO}/Hymnals/english.json'))['hymns']}
OVERRIDES = json.load(open(f'{ROOT}/overrides.json')) if os.path.exists(f'{ROOT}/overrides.json') else {}
DIC = pyphen.Pyphen(lang='en_US')
DUR = {'Whole': 4, 'Half': 2, '4th': 1, '8th': .5, '16th': .25, '32nd': .125, '64th': .0625}
STEPS = 'CDEFGAB'
EPS = 1e-6

# ---------------- NWC parsing ----------------
def load(path, patches=None):
    d = open(path, 'rb').read()
    if d[:5] == b'[NWZ]': d = zlib.decompress(d[6:])
    i = d.find(b'!NoteWorthyComposer')
    if i < 0: raise ValueError('binary NWC (not 2.x text)')
    lines = d[i:].decode('utf-8', 'replace').splitlines()
    # proofreading fixes from overrides.json: [exact source line, replacement, which occurrence (1-based)]
    for old, new, occ in (patches or []):
        hits = [k for k, l in enumerate(lines) if l == old]
        if len(hits) < occ: raise ValueError('override patch not found: %s' % old)
        lines[hits[occ - 1]] = new
    return [x for l in lines for x in l.split('\n')]

def fields(line):
    parts = line.split('|')[1:]
    f = {}
    for p in parts[1:]:
        if ':' in p: k, v = p.split(':', 1); f[k] = v
        else: f[p] = True
    return parts[0], f

def parse(path, patches=None):
    info, staves, cur = {}, [], None
    for ln in load(path, patches):
        if not ln.startswith('|'): continue
        typ, f = fields(ln)
        if typ == 'SongInfo': info = f
        elif typ == 'AddStaff': cur = {'name': f.get('Name', '').strip('"'), 'items': [], 'lyrics': []}; staves.append(cur)
        elif cur is not None:
            if re.fullmatch(r'Lyric\d+', typ): cur['lyrics'].append(f.get('Text', '').strip('"'))
            else: cur['items'].append((typ, f))
    return info, staves

def dur2_of(f):
    # the triplet bracket of a split chord covers both of its voices
    q2, sl2 = dur_of(f.get('Dur2', f['Dur']))
    if 'Triplet' in f['Dur'] and 'Triplet' not in f.get('Dur2', ''): q2 *= 2 / 3
    return q2, sl2

def dur_of(s):
    toks = s.split(',')
    q = DUR[toks[0]]
    if 'Dotted' in toks: q *= 1.5
    if 'DblDotted' in toks: q *= 1.75
    if any(t.startswith('Triplet') for t in toks): q *= 2 / 3
    return (0 if 'Grace' in toks else q), ('Slur' in toks)

def parse_pos(tok):
    m = re.match(r'([#bnxv]?)(-?\d+)([oxXz]?)(\^?)', tok)
    acc, p, _, t = m.groups()
    return acc, int(p), bool(t)

def staff_pitch(acc, pos, clefbase, keyalt, baralt):
    di = clefbase + pos
    step = STEPS[di % 7]; octv = di // 7
    if acc:
        alt = {'#': 1, 'b': -1, 'n': 0, 'x': 2, 'v': -2}[acc]; baralt[di] = alt
    else:
        alt = baralt.get(di, keyalt.get(step, 0))
    p = m21pitch.Pitch(step + str(octv)); p.accidental = m21pitch.Accidental(alt) if alt else None
    return p

CLEFBASE = {'Treble': 34, 'Bass': 22, 'Alto': 28, 'Tenor': 26}

def staff_events(st, seglens=None, other_bars=None):
    """Timeline of one NWC staff -> 2 voices of [start,end,pitch,lyric_ok,tie_open,slur_to_next]."""
    clefbase = 34; keyalt = {}; ks = 0; ts = '4/4'; cl = 'Treble'
    clock = [0.0, 0.0]; v = [[], []]; bars = []; barstyles = []; baralt = {}; slur_prev = [False, False]
    mstart = 0.0; barlen = 4.0; ts_events = []; key_events = []; texts = []; endings = []; warnings = set()
    fermatas = set(); pend_ferm = False; items_ev = []; prev_item_hold = False
    for typ, f in st['items']:
        if typ == 'TempoVariance' and f.get('Style') == 'Fermata': pend_ferm = True; continue
        if pend_ferm and typ in ('Chord', 'Note', 'Rest', 'RestChord'):
            fermatas.add(round(min(clock), 3)); pend_ferm = False
        if typ == 'Clef':
            cl = f.get('Type', 'Treble'); clefbase = CLEFBASE.get(cl, 34)
            if 'OctaveShift' in f: warnings.add('octave-shift clef')
        elif typ == 'Key':
            keyalt = {}
            for s in f.get('Signature', 'C').split(','):
                if len(s) == 2: keyalt[s[0]] = 1 if s[1] == '#' else -1
            ks = sum(keyalt.values()); key_events.append((max(clock), ks))
        elif typ == 'TimeSig':
            ts = {'Common': '4/4', 'AllaBreve': '2/2'}.get(f['Signature'], f['Signature'])
            a_, b_ = map(int, ts.split('/')); barlen = a_ * 4 / b_; ts_events.append((max(clock), ts))
        elif typ == 'Text':
            texts.append((max(clock), f.get('Text', '').strip('"')))
        elif typ == 'Ending':
            endings.append((max(clock), f.get('Endings', '1')))
        elif typ == 'Bar':
            style = f.get('Style', 'Single')
            end = max(clock)
            if end - mstart < EPS:
                if barstyles and style != 'Single': barstyles[-1] = style
                elif not barstyles and style == 'MasterRepeatOpen': barstyles_open_at_start = True
                continue
            L = end - mstart; bi = len(bars)
            if seglens is not None and bars and L < barlen - EPS:
                nxt = seglens[bi + 1] if bi + 1 < len(seglens) else None
                ob = other_bars or []
                def has(x): return any(abs(x - b) < 1e-3 for b in ob)
                if other_bars is None:
                    if nxt is not None and abs(L + nxt - barlen) < EPS:
                        seglens[bi + 1] = barlen; continue
                    end = mstart + barlen
                elif nxt is not None and not has(end) and has(end + nxt) and L + nxt <= barlen + EPS:
                    seglens[bi + 1] = L + nxt; continue      # source split one bar in two (the other staff didn't)
                elif not has(end) and has(mstart + barlen):
                    end = mstart + barlen                    # source left out a rest (the other staff has the full bar)
            for i in (0, 1):
                if clock[i] < end - EPS:
                    v[i].append([clock[i], end, None, False, False, False]); clock[i] = end
            bars.append(end); barstyles.append(style); baralt = {}; mstart = end
        elif typ in ('Chord', 'Note', 'Rest', 'RestChord'):
            opts = f.get('Opts', '')
            q1, sl1 = dur_of(f['Dur'])
            if q1 == 0: warnings.add('grace notes dropped'); continue
            cursor = min(clock)
            lyr = False if 'Lyric=Never' in opts else (True if 'Lyric=Always' in opts else None)
            if typ != 'Rest':
                # NoteWorthy places one lyric syllable per note/chord item, skipping items inside a slur or tie
                items_ev.append((round(cursor, 3), (not prev_item_hold) if lyr is None else lyr))
                prev_item_hold = sl1 or '^' in f.get('Pos', '') or 'Slur' in f.get('Dur2', '') or '^' in f.get('Pos2', '')
            else: prev_item_hold = False
            free = [clock[0] <= cursor + EPS, clock[1] <= cursor + EPS]
            def put(i, start, q, p, tied, slur):
                if p is None:
                    v[i].append([start, start + q, None, False, False, False])
                    slur_prev[i] = False
                else:
                    prev = v[i][-1] if v[i] else None
                    if prev and prev[4] and prev[2] is not None and prev[2].ps == p.ps and abs(prev[1] - start) < EPS:
                        prev[1] = start + q; prev[4] = tied; prev[5] = slur
                    else:
                        v[i].append([start, start + q, p, (not slur_prev[i]) if lyr is None else lyr, tied, slur])
                    slur_prev[i] = slur
                clock[i] = start + q
            if typ == 'Rest':
                for i in (0, 1):
                    if free[i]: put(i, cursor, q1, None, False, False)
                continue
            if typ == 'RestChord':
                q2, sl2 = dur2_of(f)
                toks2 = f.get('Pos2', '').split(',')
                ps2 = sorted([(staff_pitch(a, p, clefbase, keyalt, baralt), t) for a, p, t in map(parse_pos, toks2)], key=lambda x: -x[0].ps)
                notes_low = 'Stem=Down' in opts or 'Stem=Up' not in opts
                rv, nv = (0, 1) if notes_low else (1, 0)
                if free[rv]: put(rv, cursor, q1, None, False, False)
                if free[nv]: put(nv, cursor, q2, ps2[-1 if nv else 0][0], ps2[-1 if nv else 0][1], sl2)
                continue
            toks = f.get('Pos', '').split(',')
            ps = sorted([(staff_pitch(a, p, clefbase, keyalt, baralt), t) for a, p, t in map(parse_pos, toks)], key=lambda x: -x[0].ps)
            if 'Dur2' in f:
                q2, sl2 = dur2_of(f)
                ps2 = sorted([(staff_pitch(a, p, clefbase, keyalt, baralt), t) for a, p, t in map(parse_pos, f.get('Pos2', '').split(','))], key=lambda x: -x[0].ps)
                up_first = 'Stem=Down' not in opts
                A, B = (ps, ps2) if up_first else (ps2, ps)
                qa, qb = (q1, q2) if up_first else (q2, q1)
                sa, sb = (sl1, sl2) if up_first else (sl2, sl1)
                if free[0]: put(0, cursor, qa, A[0][0], A[0][1], sa)
                if free[1]: put(1, cursor, qb, B[-1][0], B[-1][1], sb)
                continue
            if free[0] and free[1]:
                put(0, cursor, q1, ps[0][0], ps[0][1], sl1); put(1, cursor, q1, ps[-1][0], ps[-1][1], sl1)
                if len(ps) > 2:
                    warnings.add('3+ note chord'); v[1][-1].append([x[0] for x in ps[1:-1]])
            elif free[0]: put(0, cursor, q1, ps[0][0], ps[0][1], sl1)
            elif free[1]: put(1, cursor, q1, ps[-1][0], ps[-1][1], sl1)
    return dict(clef=cl, ks0=key_events[0][1] if key_events else 0, ts0=ts_events[0][1] if ts_events else '4/4',
                voices=v, bars=bars, barstyles=barstyles, ts_events=ts_events, key_events=key_events,
                texts=texts, endings=endings, total=max(clock), warnings=warnings, fermatas=fermatas, items_ev=items_ev)

def staff_timeline(st, other=None):
    b = staff_events(st)['bars']
    seg = [b[0]] + [b[i] - b[i - 1] for i in range(1, len(b))] if b else []
    ob = staff_events(other)['bars'] if other is not None else None
    return staff_events(st, seg, ob)

# ---------------- lyrics ----------------
def norm(w): return unicodedata.normalize('NFKD', w).encode('ascii', 'ignore').decode().lower().replace("'", '').strip(".,;:!?\"()")

def nwc_syllables(text):
    text = text.replace('\\n', '\n')
    text = re.sub(r'^\s*\d+\._?', '', text)
    out = []
    for word in re.split(r'[ \n\t]+', text):
        if not word: continue
        if word == '_': out.append(None); continue
        word = word.replace('_', ' ')
        parts = word.split('-')
        # "-" at a word start/end (e.g. trailing hyphen) would make empty parts
        parts = [p for p in parts if p != ''] or [word]
        for i, p in enumerate(parts):
            st = 'single' if len(parts) == 1 else ('begin' if i == 0 else ('end' if i == len(parts) - 1 else 'middle'))
            out.append((p, st))
    return out

def words_of(syls):
    """Group syllables (skipping None placeholders) into words: [(index_list, [texts])]."""
    words, curw = [], None
    for i, s in enumerate(syls):
        if s is None: continue
        t, st = s
        if st in ('single', 'begin'): curw = ([i], [t]); words.append(curw)
        elif curw is not None: curw[0].append(i); curw[1].append(t)
        else: curw = ([i], [t]); words.append(curw)
    return words

VOWELS = 'aeiouyAEIOUY'
def vowel_split(word, n):
    """Split into n pieces at consonant boundaries after vowel groups (fallback when spelling differs)."""
    groups = [m.end() for m in re.finditer(r'[aeiouyAEIOUY]+[^aeiouyAEIOUY]?', word)]
    cuts = [g for g in groups[:-1] if 0 < g < len(word)]
    if len(cuts) < n - 1: return None
    # choose n-1 cuts spread evenly
    step = len(cuts) / (n - 1) if n > 1 else 1
    chosen = sorted(set(cuts[min(len(cuts) - 1, int(round(k * step)))] for k in range(n - 1)))
    if len(chosen) != n - 1: chosen = cuts[:n - 1]
    out, i = [], 0
    for c in chosen: out.append(word[i:c]); i = c
    out.append(word[i:])
    return out if all(out) else None

def split_like(word, n, template):
    if n == 1: return [word]
    if norm(word) == norm(''.join(template)):
        out, i = [], 0
        for k, tpl in enumerate(template):
            if k == n - 1: out.append(word[i:]); break
            L = sum(ch.isalpha() for ch in tpl); j = i; cnt = 0
            while j < len(word) and cnt < L:
                if word[j].isalpha(): cnt += 1
                j += 1
            out.append(word[i:j]); i = j
        if all(out): return out
    # spelling differs (Ev'rything / ev-ery-thing, Saviour / Sav-ior): map the template's cuts by letter alignment
    tl = ''.join(template).lower(); wl = word.lower()
    cuts_t, acc = [], 0
    for tpl in template[:-1]: acc += len(tpl); cuts_t.append(acc)
    sm = difflib.SequenceMatcher(None, tl, wl, autojunk=False)
    def mapc(c):
        for a, b, size in sm.get_matching_blocks():
            if a <= c <= a + size: return b + (c - a)
        return None
    cw = [mapc(c) for c in cuts_t]
    if all(x is not None for x in cw) and all(0 < cw[i] < len(word) for i in range(len(cw))) and cw == sorted(set(cw)) and len(cw) == n - 1:
        out, i = [], 0
        for c in cw: out.append(word[i:c]); i = c
        out.append(word[i:])
        if all(re.search(r'[A-Za-z]', x) for x in out): return out
    parts = DIC.inserted(word).split('-')
    if len(parts) == n: return parts
    return vowel_split(word, n)

def app_words(lines):
    toks = []
    for ln in lines:
        if ln.strip().startswith('('): continue  # echo lines like "(loud o'er land and sea)"
        for w in re.findall(r"\S+", ln.replace('—', ' ').replace('–', ' ').replace(' - ', ' ').replace('…', ' ')):
            if not re.search(r'[A-Za-z]', w): continue
            toks.extend(p for p in re.split(r'(?<=[A-Za-z])-(?=[A-Za-z])', w) if p)
    return toks

def swap_in_app_text(syls, app_lines):
    """Put the app's words on a Cyber Hymnal lyric line's notes. None if they don't align well enough."""
    words = words_of(syls)
    toks = app_words(app_lines)
    a = [norm(''.join(t)) for _, t in words]; b = [norm(re.sub(r"[^A-Za-z’'\u00C0-\u024F]", '', t)) for t in toks]
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    out = list(syls); changed = 0; kept = []
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == 'equal' or (op == 'replace' and i2 - i1 == j2 - j1):
            for (idxs, texts), tok in zip(words[i1:i2], toks[j1:j2]):
                lead, body, trail = re.match(r"^([^A-Za-z\u00C0-\u024F]*)(.*?)([^A-Za-z\u00C0-\u024F’']*)$", tok).groups()
                if op == 'replace': changed += 1
                pieces = split_like(body, len(idxs), texts)
                if pieces is None: return None, 'cannot split "%s" into %d' % (tok, len(idxs))
                pieces[0] = lead + pieces[0]; pieces[-1] = pieces[-1] + trail
                for i, p in zip(idxs, pieces): out[i] = (p, syls[i][1])
        elif op == 'replace' and max(i2 - i1, j2 - j1) <= 3:
            # different word counts: fine if the app words can be sung to exactly these notes
            idxs = [i for ws, _ in words[i1:i2] for i in ws]
            fit, _ch = fit_syllables([' '.join(toks[j1:j2])], len(idxs))
            if fit is None: return None, '%s %s -> %s' % (op, ' '.join(a[i1:i2]), ' '.join(b[j1:j2]))
            for i, (p, st) in zip(idxs, fit): out[i] = (p, st)
            changed += max(i2 - i1, j2 - j1)
        elif op == 'delete' and i2 - i1 <= 2:
            kept.append(' '.join(a[i1:i2]))     # word the app text lacks: the score keeps Cyber Hymnal's
        else:
            return None, '%s %s -> %s' % (op, ' '.join(a[i1:i2]), ' '.join(b[j1:j2]))
    if changed > max(3, len(words) * 0.35): return None, 'too different (%d of %d words)' % (changed, len(words))
    if len(kept) > 1: return None, 'app lacks %s' % kept
    return out, 'ok (%d words differ%s)' % (changed, ', kept CH word: ' + kept[0] if kept else '')

import pronouncing as _pr
def word_counts(body):
    """(default syllable count, set of plausible alternatives) for one word."""
    key = norm(body)
    lw = body.lower().replace('’', "'")
    m = re.match(r"^(th)['’](\w{3,})$", body, re.I)   # th’Almighty, th’eternal: elided article joins the next word
    if m: return word_counts(m.group(2))[0], set()
    alts = set()
    if key in SYL: d = len(SYL[key])
    else:
        ph = [_pr.syllable_count(p) for p in _pr.phones_for_word(re.sub(r"[^a-z']", '', lw))]
        if not ph and lw.endswith('our'): ph = [_pr.syllable_count(p) for p in _pr.phones_for_word(lw[:-3] + 'or')]
        if not ph and re.search(r"(eth|est)$", lw):
            ph = [c + 1 for c in (_pr.syllable_count(p) for p in _pr.phones_for_word(lw[:-3] + 'e') or _pr.phones_for_word(lw[:-3]))]
        if ph: d = min(ph); alts.update(ph)
        else: d = len(DIC.inserted(body).split('-')) if len(body) > 3 else 1
        if "'" in lw: alts = set()   # written elisions are sung as written
    # common hymn elisions / expansions
    if re.search(r"(ow|ow)ers?$|ower(ed|ing)?$", lw): alts.update({d - 1, d, d + 1})
    if re.search(r"(eaven|ven)s?$", lw) and d >= 2: alts.add(d - 1)
    if re.search(r"^every|^ev'ry", lw): alts.update({2, 3} if lw.startswith('every') else set())
    if re.search(r"(iour|ior|ious|ian|ial|ient|iant)s?$", lw): alts.update({d, d + 1, max(d - 1, 1)})
    if re.search(r"[^aeiou]ering$|[^aeiou]ering|[^aeiou]erous", lw) and d >= 3: alts.add(d - 1)
    if re.search(r"ire[sd]?$|our[s]?$", lw) and len(lw) <= 6: alts.update({1, 2})
    alts.update(ALT.get(key, []))
    alts.discard(d); alts = {a for a in alts if a >= 1}
    return d, alts

def split_word(body, n):
    if n <= 1: return [body]
    m = re.match(r"^(th['’])(\w{3,})$", body, re.I)
    if m:
        rest = split_word(m.group(2), n)
        return [m.group(1) + rest[0]] + rest[1:] if rest else None
    key = norm(body)
    if key in SYL and len(SYL[key]) == n: return split_like(body, n, SYL[key]) or vowel_split(body, n)
    hy = DIC.inserted(body).split('-')
    if len(hy) == n: return hy
    v = vowel_split(body, n)
    return v if v and len(v) == n else None

def _emit(tok, pieces):
    lead, _, trail = re.match(r"^([^A-Za-z\u00C0-\u024F]*)(.*?)([^A-Za-z\u00C0-\u024F’']*)$", tok).groups()
    pieces = list(pieces); pieces[0] = lead + pieces[0]; pieces[-1] = pieces[-1] + trail
    return [(p, 'single' if len(pieces) == 1 else ('begin' if k == 0 else ('end' if k == len(pieces) - 1 else 'middle'))) for k, p in enumerate(pieces)]

def app_syllables(lines, counts=None):
    """Syllables for app text (Cyber Hymnal sung-syllable dictionary, then CMU dictionary, then hyphenation)."""
    out = []
    for i, tok in enumerate(app_words(lines)):
        body = re.sub(r"[^A-Za-z’'\u00C0-\u024F]", '', tok)
        if not body: continue
        n = counts[i] if counts else word_counts(body)[0]
        pieces = split_word(body, n) or [body]
        out.extend(_emit(tok, pieces))
    return out

def fit_syllables(lines, want):
    """Underlay app words to exactly `want` notes. If the default count misses by up to 2, use the
    plausible alternative count (e.g. pow-er/pow'r, heav-en/heav'n, ev-ery/ev-er-y) on at most 2 words.
    Returns (syllables, changed_words) or (None, None)."""
    toks = app_words(lines)
    info = []
    for t in toks:
        body = re.sub(r"[^A-Za-z’'\u00C0-\u024F]", '', t)
        info.append(word_counts(body) if body else (0, set()))
    counts = [d for d, _ in info]
    if want is None: return app_syllables(lines, counts), []
    diff = want - sum(counts)
    if diff == 0: return app_syllables(lines, counts), []
    if abs(diff) > 2: return None, None
    cands = [(i, a) for i, (d, al) in enumerate(info) for a in al if (a - d) * diff > 0 and abs(a - d) <= abs(diff)]
    chosen = next(([c] for c in cands if c[1] - counts[c[0]] == diff), None)
    if chosen is None:
        for x in range(len(cands)):
            for y in range(x + 1, len(cands)):
                if cands[x][0] != cands[y][0] and cands[x][1] - counts[cands[x][0]] + cands[y][1] - counts[cands[y][0]] == diff:
                    chosen = [cands[x], cands[y]]; break
            if chosen: break
    if not chosen: return None, None
    c2 = list(counts); changed = []
    for i, a in chosen:
        changed.append('%s:%d->%d' % (re.sub(r"[^A-Za-z’'\u00C0-\u024F]", '', toks[i]), c2[i], a)); c2[i] = a
    out = app_syllables(lines, c2)
    return (out, changed) if len(out) == want else (None, None)

SYL = {}
_SYLC = collections.defaultdict(collections.Counter)
for _p in glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src/nwc/*.nwc')):
    try:
        for _ln in load(_p):
            if _ln.startswith('|Lyric') and 'Text:' in _ln:
                for _w in re.split(r'[ \n_]+|\\n', _ln.split('Text:', 1)[1].strip('"')):
                    _w = _w.strip('-')
                    if not _w: continue
                    _parts = tuple(x for x in _w.split('-') if x)
                    # every syllable must carry a vowel, otherwise it is a typo or an elision artefact
                    if all(re.search(r'[aeiouyAEIOUY\u00C0-\u024F]', x) for x in _parts):
                        _SYLC[norm(_w.replace('-', ''))][_parts] += 1
    except Exception: pass
for _k, _c in _SYLC.items(): SYL[_k] = list(_c.most_common(1)[0][0])
SYL.update({'rugged': ['rug', 'ged'], 'wandrings': ['wand', 'rings'], 'whosoeer': ['who', 'so', 'eer'], 'fiery': ['fier', 'y'], 'seest': ['se', 'est'], 'aright': ['a', 'right'], 'wondring': ['wond', 'ring']})   # corpus has an unhyphenated typo

# ---------------- build ----------------
ALT = {}   # per-hymn extra plausible counts, e.g. {"blessed": [1]} when one verse sings it as one syllable and another as two
def build(num):
    _syl = dict(SYL); SYL.update(OVERRIDES.get(str(num), {}).get('syl', {}))   # per-hymn syllable splits (book spellings)
    ALT.clear(); ALT.update(OVERRIDES.get(str(num), {}).get('alt', {}))
    try: return _build(num)
    finally: SYL.clear(); SYL.update(_syl); ALT.clear()
def _build(num):
    path = f'{ROOT}/src/nwc/{num:03d}.nwc'
    info, staves = parse(path, OVERRIDES.get(str(num), {}).get('patch'))
    if len(staves) != 2: raise ValueError('expected 2 staves, got %d' % len(staves))
    tl = [staff_timeline(staves[0], staves[1]), staff_timeline(staves[1], staves[0])]
    ov = OVERRIDES.get(str(num), {})
    for tt, sig in ov.get('ts_insert', []):   # proofreading: time signature missing in the source
        for t_ in tl: t_['ts_events'] = sorted(t_['ts_events'] + [(float(tt), sig)])
    b0 = tl[0]['bars']
    total = max(t['total'] for t in tl)
    rep_notes = []
    lens = [t['total'] for t in tl]
    extra = []
    if abs(lens[0] - lens[1]) > EPS:
        longer = tl[0] if lens[0] > lens[1] else tl[1]
        extra = [b for b in longer['bars'] if b > (b0[-1] if b0 else 0) + EPS]
    bounds = sorted(set([0.0] + [b for b in b0 + extra if b < total - EPS] + [total]))
    def ts_at(t):
        cur = tl[0]['ts0']
        for tt, s in tl[0]['ts_events']:
            if tt <= t + EPS: cur = s
        return cur
    def barlen_of(ts): a, b = map(int, ts.split('/')); return a * 4 / b
    # a barline missing on staff 1 but present on staff 2 (measure would be too long): take staff 2's
    other = tl[1]['bars']
    for k in range(len(bounds) - 1):
        s_, e_ = bounds[k], bounds[k + 1]
        if e_ - s_ > barlen_of(ts_at(s_)) + EPS:
            bounds += [b for b in other if s_ + EPS < b < e_ - EPS]
    bounds = sorted(set(bounds))
    # refrain pickup engraved inside the first refrain bar (after a double bar): give it its own short measure
    style0 = {round(b, 3): st_ for b, st_ in zip(tl[0]['bars'], tl[0]['barstyles'])}
    def onsets(tl_):
        return {round(n[0], 3) for n in tl_['voices'][0]}
    on0, on1 = onsets(tl[0]), onsets(tl[1])
    for k in range(1, len(bounds) - 1):
        s_, e_ = bounds[k], bounds[k + 1]; L = barlen_of(ts_at(s_)); x = (e_ - s_) - L
        if x > EPS and style0.get(round(s_, 3)) in ('Double', 'SectionClose', 'SectionOpen') and round(s_ + x, 3) in on0 and round(s_ + x, 3) in on1:
            bounds.append(s_ + x); rep_notes.append('refrain pickup at %.2f given its own measure' % s_)
    bounds = sorted(set(bounds))
    # a barline missing on both staves: a measure exactly 2x/3x the bar length is split evenly
    for k in range(len(bounds) - 1):
        s_, e_ = bounds[k], bounds[k + 1]; L = barlen_of(ts_at(s_)); q = (e_ - s_) / L
        if q > 1.5 and abs(q - round(q)) < EPS:
            bounds += [s_ + L * i for i in range(1, int(round(q)))]
            rep_notes.append('split %.1f-beat measure at %.1f' % (e_ - s_, s_))
    bounds = sorted(set(bounds))
    nmeas = len(bounds) - 1
    pick = bounds[1] if bounds[1] < barlen_of(ts_at(0)) - EPS else 0.0
    rep = {'num': num, 'title': APP[num]['title'], 'measures': nmeas, 'pickup': pick, 'time': tl[0]['ts0'], 'key': tl[0]['ks0'],
           'notes': rep_notes, 'warnings': sorted(set().union(*[t['warnings'] for t in tl])) + (['staves differ in length (%.1f vs %.1f beats)' % tuple(lens)] if abs(lens[0] - lens[1]) > EPS else []), 'lyrics': []}
    sc = stream.Score(); sc.metadata = metadata.Metadata(); sc.metadata.title = ''
    app = APP[num]
    app_verses = [b for b in app['blocks'] if b['t'] == 'v']
    app_refrain = next((b for b in app['blocks'] if b['t'] == 'c'), None)
    for si, t in enumerate(tl):
        part = stream.Part(); part.partName = ''
        ms = []; ts_for = {}
        lastts, lastks = None, None
        for mi in range(nmeas):
            s, e = bounds[mi], bounds[mi + 1]
            m = stream.Measure(number=mi if pick else mi + 1)
            tsn = ts_at(s)
            # a time signature that the source places inside this measure (e.g. after a pickup) governs it
            for tt, ts_ in tl[0]['ts_events']:
                if s + EPS < tt < e - EPS and abs((e - s) - barlen_of(ts_)) < EPS and abs((e - s) - barlen_of(tsn)) > EPS: tsn = ts_
            ts_for[mi] = tsn
            ksn = t['ks0']
            for tt, k in t['key_events']:
                if tt <= s + EPS: ksn = k
            if mi == 0:
                m.insert(0, clef.TrebleClef() if t['clef'] == 'Treble' else clef.BassClef())
            if ksn != lastks: m.insert(0, key.KeySignature(ksn)); lastks = ksn
            if tsn != lastts: m.insert(0, meter.TimeSignature(tsn)); lastts = tsn
            ms.append(m)
        noteobjs = {}; onset_obj = {}
        for vi, vn in enumerate(t['voices']):
            seq = []; cur = 0.0
            for n in vn:
                if n[0] < cur - EPS:
                    rep['warnings'].append('overlapping notes trimmed (staff %d voice %d at %.2f)' % (si + 1, vi + 1, n[0]))
                    if n[1] <= cur + EPS: continue
                    n = [cur] + n[1:]
                if n[0] > cur + EPS: seq.append([cur, n[0], None, False, False, False])
                seq.append(n); cur = max(cur, n[1])
            if cur < total - EPS: seq.append([cur, total, None, False, False, False])
            for mi, m in enumerate(ms):
                s, e = bounds[mi], bounds[mi + 1]
                vv = stream.Voice(id=str(vi + 1))
                for n in seq:
                    a, b, p = n[0], n[1], n[2]
                    lo, hi = max(a, s), min(b, e)
                    if hi - lo < EPS: continue
                    if p is None: o = note.Rest()
                    elif len(n) > 6 and n[6]: o = chord.Chord([p] + n[6])
                    else: o = note.Note(p)
                    o.quarterLength = hi - lo
                    if p is not None:
                        o.stemDirection = 'up' if vi == 0 else 'down'
                        if a < s - EPS and b > e + EPS: o.tie = tie.Tie('continue')
                        elif a < s - EPS: o.tie = tie.Tie('stop')
                        elif b > e + EPS: o.tie = tie.Tie('start')
                        if lo == a: noteobjs[(vi, id(n))] = o; onset_obj[(vi, round(a, 3))] = o
                    if lo == a and round(a, 3) in t['fermatas'] and vi == si:
                        fm = expressions.Fermata()
                        if si == 1: fm.type = 'inverted'; fm.placement = 'below'
                        else: fm.placement = 'above'
                        o.expressions.append(fm)
                    vv.insert(lo - s, o)
                m.insert(0, vv)
        # slurs (a note marked Slur slurs into the next note of its voice)
        for vi, vn in enumerate(t['voices']):
            notes_only = [n for n in vn if n[2] is not None]
            k = 0
            while k < len(notes_only):
                if notes_only[k][5] and k + 1 < len(notes_only):
                    j = k
                    while j + 1 < len(notes_only) and notes_only[j][5]: j += 1
                    a, b = noteobjs.get((vi, id(notes_only[k]))), noteobjs.get((vi, id(notes_only[j])))
                    if a is not None and b is not None and a is not b: part.insert(0, spanner.Slur(a, b))
                    k = j + 1
                else: k += 1
        # lyrics on voice 1 notes that start a syllable
        targets = [n for n in t['voices'][0] if n[2] is not None and n[3]]
        lines = [nwc_syllables(x) for x in staves[si]['lyrics']] if not ov.get('ignore_nwc_lyrics') else []
        lines = [l for l in lines if any(s for s in l)]
        ref_k = None
        if si == 0 and not lines and not ov.get('no_underlay'):
            # tune-only score: underlay the app's words where the syllable count fits the melody exactly
            T = len(targets)
            R = app_syllables(app_refrain['l']) if app_refrain else []
            rep['underlay'] = []; fits = []; adj = []
            Rf = fit_syllables(app_refrain['l'], None) if app_refrain else ([], [])
            # with a refrain: either the score holds verse + refrain, or only one strophe that both are sung to
            mode = None
            if R and app_verses and fit_syllables(app_verses[0]['l'], T - len(R))[0] is not None: mode = 'verse+refrain'
            elif app_verses and fit_syllables(app_verses[0]['l'], T)[0] is not None: mode = 'verse'; R = [] if not (app_refrain and fit_syllables(app_refrain['l'], T)[0]) else R
            for j, vb in enumerate(app_verses):
                sy, ch = fit_syllables(vb['l'], T - len(R) if mode == 'verse+refrain' else T)
                fits.append(sy); adj.append(ch)
            if mode == 'verse' and R:
                # refrain sung to the same strophe: add it as its own line after the verses
                rf, rch = fit_syllables(app_refrain['l'], T); fits.append(rf); adj.append(rch)
                rep['underlay_refrain_line'] = True
            if mode == 'verse': R = []
            rep['underlay_fit'] = {'notes': T, 'verse_syllables': [len(app_syllables(vb['l'])) for vb in app_verses], 'refrain_syllables': len(R)}
            if app_verses and fits and fits[0] is not None:
                for j, sy in enumerate(fits):
                    if sy is None: continue
                    if rep.get('underlay_refrain_line') and j == len(fits) - 1: ref_k = len(lines); lines.append(sy); continue
                    lines.append(sy + (R if R and j == 0 else [])); rep['underlay'].append(j + 1)
                rep['underlay_adjusted'] = [a for a in adj if a]
        if si == 0:
            verse_lines = []; used = set(); keep = []
            def sim(l, vb):
                x = [norm(''.join(t)) for _, t in words_of(l)]
                y = [norm(re.sub(r"[^A-Za-z’'\u00C0-\u024F]", '', t)) for t in app_words(vb['l'])]
                return difflib.SequenceMatcher(None, x[:len(y)], y, autojunk=False).ratio()
            matched = {}
            for k, l in enumerate(lines):
                lead_blank = next((i for i, x in enumerate(l) if x is not None), len(l))
                if lead_blank == 0 and k != ref_k:
                    scores = [(sim(l, vb), j) for j, vb in enumerate(app_verses) if j not in used]
                    best = max(scores, default=(0, None))
                    if best[0] >= 0.45: matched[k] = best[1]; used.add(best[1])
            new_lines = []; order = []; nlines0 = len(lines)
            for k, l in enumerate(lines):
                lead_blank = next((i for i, x in enumerate(l) if x is not None), len(l))
                tag, why = 'cyber', ''
                if lead_blank == 0 and k != ref_k:
                    if k not in matched:
                        rep['lyrics'].append({'line': k + 1, 'source': 'dropped', 'why': 'Cyber Hymnal verse not in the app'})
                        # keep a refrain that only this line carries (notes no other line has words for)
                        if len(lines) > 1 and k < nlines0:
                            uniq = [i for i, x in enumerate(l) if x is not None and all(i >= len(o) or o[i] is None for kk, o in enumerate(lines[:nlines0]) if kk != k)]
                            if uniq and len(uniq) >= 4 and uniq == list(range(uniq[0], len(l))) and l[uniq[0]][1] in ('single', 'begin'):
                                lines.append([None] * uniq[0] + l[uniq[0]:])
                        continue
                    j = matched[k]
                    sw, why = swap_in_app_text(l, app_verses[j]['l'])
                    if sw is None and app_refrain is not None:
                        sw2, why2 = swap_in_app_text(l, app_verses[j]['l'] + app_refrain['l'])
                        if sw2 is not None: sw, why = sw2, why2
                    if sw is not None: l = sw; tag = 'app'
                    order.append((j, len(new_lines)))
                elif app_refrain is not None:
                    sw, why = swap_in_app_text(l, app_refrain['l']); why = 'refrain: ' + why
                    if sw is not None: l = sw; tag = 'app'
                else: why = 'refrain (app has none)'
                rep['lyrics'].append({'line': k + 1, 'source': tag, 'why': why, 'app_verse': matched.get(k, -1) + 1})
                new_lines.append(l)
            lines = new_lines
            verse_lines = [k for _, k in sorted(order)]
            vnums = [j + 1 for j, _ in sorted(order)]
            vi_app_missing = [j for j in range(len(app_verses)) if j not in used]
            # app verses the Cyber Hymnal score doesn't have: add them when their syllables fit the verse exactly
            vlen = min((sum(1 for x in lines[k] if x is not None) for k in verse_lines), default=0)
            rep['extra_verses'] = []
            for j in vi_app_missing:
                extra = app_verses[j]
                sy, _ch = fit_syllables(extra['l'], vlen) if vlen else (None, None)
                if sy is not None:
                    lines.append(sy); verse_lines.append(len(lines) - 1); vnums.append(j + 1); rep['extra_verses'].append(extra.get('n') or j + 1)
                else:
                    rep['lyrics'].append({'line': None, 'source': 'missing', 'why': 'app verse %s: %d syllables vs %d notes' % (extra.get('n') or j + 1, len(app_syllables(extra['l'])), vlen)})
            # put verse lines in app verse order, refrain-only lines after line 1
            others = [k for k in range(len(lines)) if k not in verse_lines]
            srt = sorted(zip(vnums, verse_lines))
            vnums = [v for v, _ in srt]
            lines = [lines[k] for _, k in srt] + [lines[k] for k in others]
            verse_lines = list(range(len(verse_lines)))
            rep['verse_numbers_in_score'] = vnums
            # verse numbers
            for vn_, k in zip(vnums, verse_lines):
                i0 = next((i for i, x in enumerate(lines[k]) if x is not None), None)
                if i0 is not None: lines[k][i0] = ('%d. %s' % (vn_, lines[k][i0][0]), lines[k][i0][1])
            rep['lyric_targets'] = len(targets)
            rep['syllables'] = [len(l) for l in lines]
            rep['app_verses'] = len(app_verses)
        # display clean-up of app text quirks: backtick apostrophes, punctuation stuck to the next word, lone "i"
        for l in lines:
            prev = None
            for i, x in enumerate(l):
                if x is None: continue
                txt, st = x
                txt = txt.replace('`', '\u2019')
                m_ = re.match(r'^([!?,;:]+)(\S.*)$', txt)
                if m_ and prev is not None and st in ('single', 'begin'):
                    pt, ps_ = l[prev]; l[prev] = (pt + m_.group(1), ps_); txt = m_.group(2)
                if txt == 'i' and st == 'single': txt = 'I'
                txt = re.sub(r',-$', ',', txt)
                l[i] = (txt, st); prev = i
        # place: move lone lines (refrain on line 2+) up to line 1 where line 1 is empty
        grid = {}
        for k, l in enumerate(lines):
            for i, s in enumerate(l):
                if s is not None and s[0] and i < len(targets): grid.setdefault(i, {})[k] = s
        for i, d in grid.items():
            if 0 not in d and len(d) == 1:
                (k, s), = d.items(); grid[i] = {0: s}
        tobj = [noteobjs.get((0, id(x))) for x in targets]
        longest = max([len(l) for l in lines] or [0])
        if longest > len(targets):
            # more syllables than melody notes: the source puts some syllables on inner-voice notes
            alt = [tt for tt, ok in t['items_ev'] if ok]
            if len(alt) == longest:
                tobj = [onset_obj.get((0, tt)) or onset_obj.get((1, tt)) for tt in alt]
                if si == 0: rep['notes'].append('lyrics follow NoteWorthy item order (%d syllable notes)' % len(alt))
                grid = {}
                for k, l in enumerate(lines):
                    for i, s_ in enumerate(l):
                        if s_ is not None and s_[0] and i < len(tobj): grid.setdefault(i, {})[k] = s_
                for i, d in grid.items():
                    if 0 not in d and len(d) == 1:
                        (k, s_), = d.items(); grid[i] = {0: s_}
        if si == 0: rep['overflow'] = max([len(l) - len(tobj) for l in lines] or [0])
        for i, d in grid.items():
            o = tobj[i] if i < len(tobj) else None
            if o is None: continue
            for k, (txt, st) in sorted(d.items()):
                o.lyrics.append(note.Lyric(text=txt, number=k + 1, syllabic=st))
        # barlines: repeats / double / final
        style_at = {round(b, 3): st_ for b, st_ in zip(t['bars'], t['barstyles'])}
        for mi, m in enumerate(ms):
            style = style_at.get(round(bounds[mi + 1], 3))
            if style == 'MasterRepeatClose': m.rightBarline = m21bar.Repeat(direction='end')
            elif style == 'MasterRepeatOpen' and mi + 1 < len(ms): ms[mi + 1].leftBarline = m21bar.Repeat(direction='start')
            elif style in ('Double',) and mi < nmeas - 1: m.rightBarline = m21bar.Barline('double')
        ms[-1].rightBarline = m21bar.Barline('final')
        if si == 0:
            for tt, txt in t['texts']:
                if txt.lower() == 'refrain' or txt.lower() == 'chorus':
                    mi = max(i for i in range(nmeas) if bounds[i] <= tt + EPS)
                    te = expressions.TextExpression('Refrain'); te.style.fontStyle = 'italic'; te.placement = 'above'
                    ms[mi].insert(tt - bounds[mi], te)
            for tt, num_e in t['endings']:
                mi = max(i for i in range(nmeas) if bounds[i] <= tt + EPS)
                rb = spanner.RepeatBracket(ms[mi], number=num_e.split(',')[0]); part.insert(0, rb)
        if pick: ms[0].paddingLeft = barlen_of(ts_at(0)) - pick
        for mi in range(1, nmeas):
            ln = bounds[mi + 1] - bounds[mi]; L = barlen_of(ts_for[mi])
            if ln < L - EPS: ms[mi].paddingRight = L - ln
        for m in ms:
            for vv in m.voices:
                vv.makeAccidentals(useKeySignature=m.keySignature or key.KeySignature(t['ks0']), inPlace=True, cautionaryNotImmediateRepeat=False)
            part.append(m)
        sc.insert(0, part)
    # MIDI-comparable data
    rep['soprano'] = [[n[0], n[1], int(n[2].ps)] for n in tl[0]['voices'][0] if n[2] is not None]
    rep['bass'] = [[n[0], n[1], int(n[2].ps)] for n in tl[1]['voices'][1] if n[2] is not None]
    rep['total'] = total
    rep['info'] = {k: str(v).strip('"') for k, v in info.items() if k in ('Title', 'Author', 'Lyricist', 'Copyright1', 'Copyright2')}
    xml = f'{ROOT}/build/xml/{num:03d}.musicxml'
    sc.write('musicxml', fp=xml)
    json.dump(rep, open(f'{ROOT}/build/report/{num:03d}.json', 'w'), indent=1)
    return rep

if __name__ == '__main__':
    nums = [int(a) for a in sys.argv[1:]] or sorted(int(os.path.basename(p)[:3]) for p in glob.glob(f'{ROOT}/src/nwc/*.nwc'))
    HOLD = {5, 11, 87, 101, 125, 161, 170, 173, 182, 216, 260, 281}
    for n in nums:
        if n in HOLD: continue
        try:
            r = build(n)
            print(n, 'ok', r['measures'], 'meas', 'targets', r.get('lyric_targets'), 'syl', r.get('syllables'), [l['source'] for l in r['lyrics']], r['warnings'], flush=True)
        except Exception as e:
            import traceback; print(n, 'FAIL', repr(e), traceback.format_exc().splitlines()[-3:], flush=True)
