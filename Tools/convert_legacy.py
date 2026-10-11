#!/usr/bin/env python3
"""Convert legacy AdventPraise english.json/zulu.json to the normalized hymnal schema.

Usage: convert_legacy.py <legacy Json dir> <out dir>
Outputs per language: <lang>.json (pretty), <lang>.min.json, <lang>.min.json.gz, <lang>.sqlite (FTS5), plus report.json
Schema (v1):
 {"schema":1,"language":"english","title":"Christ In Song","hymns":[
   {"n":1,"title":"...","refs":{"vern":1,"ah":350,"sdah":368},
    "blocks":[{"t":"v","n":1,"l":["line",...]},{"t":"c","l":[...]}]}]}
 t = "v" verse | "c" chorus (stored once, in source position; the UI decides whether to repeat it after each verse).
 No markup in text. Number = 1-based position in legacy file (legacy has no explicit number; Vern-N in subtitle is cross-checked).
"""
import json, re, sys, gzip, sqlite3, os, html
LANGS = {"english": "Christ In Song", "zulu": "UKrestu Esihlabelelweni"}
CHORUS_MD = re.compile(r"^\^\[CHORUS\]\(style:\s*'bold'\)\s*:?\s*$")
INLINE_MD = re.compile(r"\^\[CHORUS\]\(style:\s*'bold'\)")
CHORUS_HTML = re.compile(r"^<b>\s*CHORUS\s*</b>$", re.I)

def parse_refs(sub):
    refs = {}
    for k, v in re.findall(r"(Vern|AH|SDAH)-([^,)\s]+)", sub):
        if v.isdigit(): refs[k.lower()] = int(v)
    return refs

def parse_lyrics(s):
    # legacy bug: a find/replace turned the word "chorus" inside lyric lines into the marker; restore it
    s = "\n".join(l if CHORUS_MD.match(l.strip()) else INLINE_MD.sub("chorus", l) for l in s.split("\n"))
    s = s.replace("<br/>", "\n").replace("<br>", "\n")
    # put <b>CHORUS</b> on its own line
    s = re.sub(r"\s*(<b>\s*CHORUS\s*</b>)\s*", r"\n\1\n", s, flags=re.I)
    s = re.sub(r"</?b>", "", s) if False else s
    blocks, cur, kind = [], [], "v"
    def flush():
        nonlocal cur
        lines = [html.unescape(l.strip()) for l in cur if l.strip()]
        if lines: blocks.append({"t": kind, "l": lines})
        cur = []
    raw = [l.strip() for l in s.split("\n")]
    for l in raw:
        if CHORUS_MD.match(l) or CHORUS_HTML.match(l):
            flush(); kind = "c"; continue
        if l == "":
            if cur:
                flush(); kind = "v"   # blank line ends a block; next block is a verse unless marker follows
            continue
        cur.append(l)
    flush()
    n = 0
    for b in blocks:
        if b["t"] == "v": n += 1; b["n"] = n
    return blocks

def convert(lang, src):
    d = json.load(open(src, encoding="utf-8"))
    hymns = []
    for i, h in enumerate(d, 1):
        hymns.append({"n": i, "title": h["Title"].strip(), "refs": parse_refs(h["Subtitle"]),
                      "blocks": parse_lyrics(h["Lyrics"])})
    return {"schema": 1, "language": lang, "title": LANGS[lang], "hymns": hymns}

def render(h):  # canonical flattened text for round-trip check
    out = []
    for b in h["blocks"]:
        out.append(("C|" if b["t"] == "c" else "V|") + "\n".join(b["l"]))
    return "\n".join(out)

def legacy_canon(lyrics):  # independent normalisation of legacy text: strip markup tokens, collapse whitespace
    s = "\n".join(l if CHORUS_MD.match(l.strip()) else INLINE_MD.sub("chorus", l) for l in lyrics.replace("<br/>", "\n").split("\n"))
    s = re.sub(r"\^\[CHORUS\]\(style:\s*'bold'\):?|<b>\s*CHORUS\s*</b>", "\n@@C@@\n", s, flags=re.I)
    return re.sub(r"\s+", "", s.replace("@@C@@", ""))

def to_sqlite(doc, path):
    if os.path.exists(path): os.remove(path)
    c = sqlite3.connect(path)
    c.executescript("""CREATE TABLE hymn(n INTEGER PRIMARY KEY,title TEXT NOT NULL,vern INT,ah INT,sdah INT,body TEXT NOT NULL);
    CREATE VIRTUAL TABLE hymn_fts USING fts5(title,text,content='',tokenize='unicode61 remove_diacritics 2');""")
    for h in doc["hymns"]:
        r = h["refs"]
        c.execute("INSERT INTO hymn VALUES(?,?,?,?,?,?)", (h["n"], h["title"], r.get("vern"), r.get("ah"), r.get("sdah"),
                  json.dumps(h["blocks"], ensure_ascii=False, separators=(",", ":"))))
        text = " ".join(l for b in h["blocks"] for l in b["l"])
        c.execute("INSERT INTO hymn_fts(rowid,title,text) VALUES(?,?,?)", (h["n"], h["title"], text))
    c.commit(); c.execute("VACUUM"); c.close()

def main(src_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True); report = {}
    for lang in LANGS:
        src = os.path.join(src_dir, f"{lang}.json"); doc = convert(lang, src)
        pretty = json.dumps(doc, ensure_ascii=False, indent=1).encode()
        mini = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode()
        open(f"{out_dir}/{lang}.json", "wb").write(pretty)
        open(f"{out_dir}/{lang}.min.json", "wb").write(mini)
        open(f"{out_dir}/{lang}.min.json.gz", "wb").write(gzip.compress(mini, 9, mtime=0))
        to_sqlite(doc, f"{out_dir}/{lang}.sqlite")
        # validation
        legacy = json.load(open(src, encoding="utf-8")); errs = []
        if len(doc["hymns"]) != len(legacy): errs.append("count mismatch")
        for h, o in zip(doc["hymns"], legacy):
            flat = re.sub(r"\s+", "", "".join(l for b in h["blocks"] for l in b["l"]))
            if flat != legacy_canon(o["Lyrics"]): errs.append(f"roundtrip text {h['n']}")
            m = re.search(r"Vern-(\d+)", o["Subtitle"])
            if m and int(m.group(1)) != h["n"]: errs.append(f"vern!=n {h['n']} (Vern-{m.group(1)})")
            if not any(b["t"] == "v" for b in h["blocks"]): errs.append(f"no verse {h['n']}")
            if re.search(r"[<>]|\^\[|style:", render(h)): errs.append(f"markup left {h['n']}")
        # reload check
        again = json.loads(mini.decode()); assert again == doc
        con = sqlite3.connect(f"{out_dir}/{lang}.sqlite")
        assert con.execute("select count(*) from hymn").fetchone()[0] == len(legacy)
        hits = con.execute("select count(*) from hymn_fts where hymn_fts match 'love'").fetchone()[0]
        con.close()
        sz = lambda p: os.path.getsize(f"{out_dir}/{p}")
        report[lang] = {"hymns": len(doc["hymns"]), "choruses": sum(b["t"] == "c" for h in doc["hymns"] for b in h["blocks"]),
            "verses": sum(b["t"] == "v" for h in doc["hymns"] for b in h["blocks"]),
            "no_chorus_hymns": sum(all(b["t"] != "c" for b in h["blocks"]) for h in doc["hymns"]),
            "legacy_bytes": os.path.getsize(src), "pretty": sz(f"{lang}.json"), "min": sz(f"{lang}.min.json"),
            "min_gz": sz(f"{lang}.min.json.gz"), "sqlite": sz(f"{lang}.sqlite"), "fts_hits_love": hits, "errors": errs[:20], "error_count": len(errs)}
    json.dump(report, open(f"{out_dir}/report.json", "w"), indent=1); print(json.dumps(report, indent=1))

if __name__ == "__main__": main(sys.argv[1], sys.argv[2])
