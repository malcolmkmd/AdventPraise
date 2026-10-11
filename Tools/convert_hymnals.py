#!/usr/bin/env python3
"""Build the bundled hymnal files for AdventPraise 7.

Usage: convert_hymnals.py <handoff dir> <out dir>

<handoff dir> holds english.min.json / zulu.min.json (output of convert_legacy.py,
the legacy app's text) and cis-v2/<folder>/<key>.json + cis-v2/config.json.

Writes one minified JSON per language to <out dir>/<key>.json plus a catalogue
<out dir>/hymnals.json. Per-language schema:

  {"key":"english","title":"Christ In Song","language":"English","refrain":"Chorus",
   "hymns":[{"number":1,"title":"...","refs":{"ah":350,"sdah":368},
             "blocks":[{"t":"v","n":1,"l":["line",...]},{"t":"c","l":[...]}]}]}

t = "v" verse | "c" chorus. A chorus is stored once (identical repeats are
dropped); the app decides whether to repeat it after every verse. No markup.

English and Ndebele/isiZulu use the legacy text as the base (it is what buyers
have been reading) and take the cis-v2 line wherever the two are near-identical
but differ, which fixes the legacy typos ("Evry", dropped punctuation, the
"chorus" find/replace damage) without trusting cis where it diverges.
"""
import difflib, glob, html, json, os, re, sys

LEGACY = {"english": "english.min.json", "ndebele": "zulu.min.json"}
LANGUAGE_NAMES = {  # display overrides for config.json "language"
    "ndebele": "Ndebele / isiZulu", "xhosa": "isiXhosa", "pt": "Português",
    "ru": "Русский", "dg": "Français", "sdah": "English",
}
TITLE_NAMES = {  # display overrides for config.json "title" (source typos)
    "pt": "Hinário Adventista do Sétimo Dia",
}
REFRAIN_DEFAULT = "Chorus"


def clean_line(s):
    s = html.unescape(html.unescape(s)).replace(" ", " ").replace("​", "")
    parts = re.split(r"<br\s*/?>?", s, flags=re.I)   # stray <br> means two lines were glued
    out = []
    for p in parts:
        p = re.sub(r"<[^>]*>", "", p)
        p = p.replace("<", "").replace(">", "")
        p = re.sub(r"\^\[[^\]]*\]\([^)]*\)", "", p)
        p = re.sub(r"\.{4,}|…\.+", "…", p)
        p = re.sub(r"\s+", " ", p).strip()
        if p:
            out.append(p)
    return out


def clean_lines(lines):
    return [c for l in lines for c in clean_line(l)]


def clean_title(t):
    t = " ".join(clean_line(t))
    return re.sub(r"\s*\.$", "", t).strip()


def norm(s):
    return re.sub(r"[^\w]", "", s.lower().replace("’", "'"))


def parse_refs(text):
    refs = {}
    for k, v in re.findall(r"\b([A-Za-z]+)[\s-]+(\d+)\b", text or ""):
        refs[k.lower()] = int(v)
    return refs


def cis_blocks(lyrics):
    blocks, seen, n = [], set(), 0
    for b in lyrics:
        lines = clean_lines(b.get("lines", []))
        if not lines:
            continue
        if b["type"] == "refrain":
            key = norm("".join(lines))
            if key in seen:
                continue
            seen.add(key)
            blocks.append({"t": "c", "l": lines})
        else:
            n += 1
            blocks.append({"t": "v", "n": n, "l": lines})
    return blocks


def similar(a, b):
    return difflib.SequenceMatcher(None, norm(a), norm(b)).ratio()


def merge_legacy(legacy, cis, stats):
    """Legacy structure, cis spelling where lines clearly correspond."""
    title = clean_title(legacy["title"])
    blocks = []
    for b in legacy["blocks"]:
        nb = {"t": b["t"], "l": clean_lines(b["l"])}
        if b["t"] == "v":
            nb["n"] = b["n"]
        if nb["l"]:
            blocks.append(nb)
    if cis is None:
        return title, blocks
    ct = clean_title(cis["title"])
    if ct != title and similar(ct, title) >= 0.8:
        title = ct; stats["titles"] += 1
    cb = cis_blocks(cis["lyrics"])
    if [b["t"] for b in cb] != [b["t"] for b in blocks]:
        stats["structure_mismatch"] += 1
        return title, blocks
    for lb, c in zip(blocks, cb):
        if len(lb["l"]) != len(c["l"]):
            stats["block_mismatch"] += 1
            continue
        for i, (a, b) in enumerate(zip(lb["l"], c["l"])):
            if a != b and similar(a, b) >= 0.75:
                if norm(a) != norm(b):
                    stats["lines_fixed"] += 1
                lb["l"][i] = b
    return title, blocks


def main(handoff, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    config = json.load(open(os.path.join(handoff, "cis-v2", "config.json"), encoding="utf-8"))
    files = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(os.path.join(handoff, "cis-v2", "*", "*.json"))}
    catalogue, report = [], {}
    for entry in config:
        key = entry["key"]
        cis = json.load(open(files[key], encoding="utf-8"))
        cis_by_n = {h["number"]: h for h in cis}
        stats = {"titles": 0, "lines_fixed": 0, "structure_mismatch": 0, "block_mismatch": 0, "empty": 0}
        hymns = []
        if key in LEGACY:
            legacy = json.load(open(os.path.join(handoff, LEGACY[key]), encoding="utf-8"))["hymns"]
            for h in legacy:
                title, blocks = merge_legacy(h, cis_by_n.get(h["n"]), stats)
                hymns.append({"number": h["n"], "title": title, "refs": h.get("refs", {}), "blocks": blocks})
        else:
            for h in sorted(cis, key=lambda h: h["number"]):
                blocks = cis_blocks(h["lyrics"])
                if not blocks:
                    stats["empty"] += 1
                    continue
                hymns.append({"number": h["number"], "title": clean_title(h["title"]),
                              "refs": parse_refs(h.get("hymnal_references")), "blocks": blocks})
        for h in hymns:
            text = json.dumps(h, ensure_ascii=False)
            assert not re.search(r"<|>|&[a-z]+;|\^\[", text), (key, h["number"])
        doc = {"key": key, "title": TITLE_NAMES.get(key, entry["title"]), "language": LANGUAGE_NAMES.get(key, entry["language"]),
               "refrain": entry.get("refrain_label", REFRAIN_DEFAULT), "hymns": hymns}
        mini = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))
        with open(os.path.join(out_dir, f"{key}.json"), "w", encoding="utf-8") as f:
            f.write(mini)
        catalogue.append({"key": key, "title": doc["title"], "language": doc["language"],
                          "count": len(hymns), "maxNumber": max(h["number"] for h in hymns)})
        report[key] = {"hymns": len(hymns), "bytes": len(mini.encode()), **stats}
    with open(os.path.join(out_dir, "hymnals.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(catalogue, ensure_ascii=False, separators=(",", ":")))
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
