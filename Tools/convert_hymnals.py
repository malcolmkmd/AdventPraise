#!/usr/bin/env python3
"""Build the bundled hymnal files for AdventPraise 7.

Usage: convert_hymnals.py <handoff dir> <out dir> [--all]

<handoff dir> holds english.min.json / zulu.min.json (output of convert_legacy.py,
the legacy app's text) and cis-v2/<folder>/<key>.json + cis-v2/config.json.

Writes one minified JSON per language to <out dir>/<key>.json plus a catalogue
<out dir>/hymnals.json. Only the BUNDLED hymnals are written, in catalogue
order; --all also writes every other cis-v2 hymnal (sdah, swahili, twi, pt…)
so they can be brought back later, e.g. into a scratch dir for
build_collections.py. Per-language schema:

  {"key":"english","title":"Christ In Song","language":"English","refrain":"Chorus",
   "hymns":[{"number":1,"title":"...","refs":{"ah":350,"sdah":368},
             "blocks":[{"t":"v","n":1,"l":["line",...]},{"t":"c","l":[...]}]}]}

t = "v" verse | "c" chorus. A chorus is stored once (identical repeats are
dropped); the app decides whether to repeat it after every verse. No markup.

English, Zulu and Ndebele use the legacy text as the base (it is what buyers
have been reading) and take the cis-v2 line wherever the two are near-identical
but differ, which fixes the legacy typos ("Evry", dropped punctuation, the
"chorus" find/replace damage) without trusting cis where it diverges. Zulu and
Ndebele churches sing from the same book (UKrestu Esihlabelelweni); 6.x listed
it under both languages, so 7 does too.
"""
import difflib, glob, html, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sdah_ref_fixes  # noqa: E402

# What the app ships, in the order the 6.3 app listed them.
BUNDLED = ["english", "chichewa", "tswana", "xhosa", "sotho", "shona", "venda", "zulu", "ndebele", "sdah"]
LEGACY = {"english": "english.min.json", "zulu": "zulu.min.json", "ndebele": "zulu.min.json"}
# Hymnals not in cis-v2/config.json: key -> (config entry, cis-v2 file whose spelling fixes are borrowed).
EXTRA = {"zulu": ({"key": "zulu", "title": "UKrestu Esihlabelelweni", "language": "Zulu"}, "ndebele")}
LANGUAGE_NAMES = {  # display overrides for config.json "language" (the bundled ones as 6.3 named them)
    "ndebele": "Ndebele", "xhosa": "Xhosa", "pt": "Português",
    "ru": "Русский", "dg": "Français", "sdah": "English",
}
TITLE_NAMES = {  # display overrides for config.json "title" (source typos)
    "pt": "Hinário Adventista do Sétimo Dia",
    "sdah": "SDA Hymnal (1985)",
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


def main(handoff, out_dir, everything=False):
    os.makedirs(out_dir, exist_ok=True)
    config = json.load(open(os.path.join(handoff, "cis-v2", "config.json"), encoding="utf-8"))
    files = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(os.path.join(handoff, "cis-v2", "*", "*.json"))}
    entries = {e["key"]: (e, e["key"]) for e in config}
    entries.update(EXTRA)
    keys = BUNDLED + ([k for k in entries if k not in BUNDLED] if everything else [])
    catalogue, report = [], {}
    sdah_to_cis = {}
    for key in keys:
        entry, cis_key = entries[key]
        cis = json.load(open(files[cis_key], encoding="utf-8"))
        cis_by_n = {h["number"]: h for h in cis}
        stats = {"titles": 0, "lines_fixed": 0, "structure_mismatch": 0, "block_mismatch": 0, "empty": 0}
        hymns = []
        if key in LEGACY:
            legacy = json.load(open(os.path.join(handoff, LEGACY[key]), encoding="utf-8"))["hymns"]
            for h in legacy:
                title, blocks = merge_legacy(h, cis_by_n.get(h["n"]), stats)
                refs = h.get("refs", {})
                if key == "english":
                    refs = sdah_ref_fixes.apply(refs, h["n"])
                hymns.append({"number": h["n"], "title": title, "refs": refs, "blocks": blocks})
        else:
            for h in sorted(cis, key=lambda h: h["number"]):
                blocks = cis_blocks(h["lyrics"])
                if not blocks:
                    stats["empty"] += 1
                    continue
                hymns.append({"number": h["number"], "title": clean_title(h["title"]),
                              "refs": parse_refs(h.get("hymnal_references")), "blocks": blocks})
        if key == "english":
            sdah_to_cis = {}
            for h in hymns:
                if "sdah" in h["refs"]:
                    sdah_to_cis.setdefault(h["refs"]["sdah"], h["number"])
        elif key == "sdah":
            # Each SDA Hymnal hymn points back at its Christ In Song version (the
            # checked english refs.sdah), so the reader can go between the two.
            for h in hymns:
                if h["number"] in sdah_to_cis:
                    h["refs"] = {**h["refs"], "cis": sdah_to_cis[h["number"]]}
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
    args = [a for a in sys.argv[1:] if a != "--all"]
    main(args[0], args[1], everything="--all" in sys.argv)
