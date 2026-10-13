#!/usr/bin/env python3
"""Build Resources/Extras/hymn_collections.json from the 1985 SDA Hymnal's sections.

Usage: build_collections.py [--check] [--sdah <dir>]

Collections are the topical sections of the Seventh-day Adventist Hymnal (1985),
as listed on hymnary.org (_src/sdah1985/hymnary_topics_SDAH1985.txt, fetched from
https://hymnary.org/browse/topics/SDAH1985). Each section is a contiguous range of
SDAH numbers; SECTIONS below is checked against the fetched index on every run.

  SDA Hymnal          its own numbers, straight into the section ranges. It is no
                      longer bundled, so it is read from <dir>/sdah.json (default
                      build/hymnals-all, written by `convert_hymnals.py <handoff>
                      build/hymnals-all --all`) and only used to check the CIS
                      cross-references; its own lists are left out of the output.
  Christ In Song      each hymn's SDAH cross-reference ("(Vern-1, AH-350, SDAH-368)",
                      kept as refs.sdah in english.json) picks its section. Where
                      the English edition has none, Tonga/Sepedi hymnal_references
                      (same CIS number) are used. No SDAH ref, no collection.
  CIS translations    hymnals that share CIS numbering get the CIS numbers as-is,
                      up to the last number that still lines up (CIS_NUMBERED).

--check prints the report without writing.
"""
import difflib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HYMNALS = os.path.join(ROOT, "AdventPraise", "Resources", "Hymnals")
OUT = os.path.join(ROOT, "AdventPraise", "Resources", "Extras", "hymn_collections.json")
SOURCE = os.path.join(ROOT, "_src", "sdah1985", "hymnary_topics_SDAH1985.txt")
CIS_SRC = os.path.join(ROOT, "_src", "cis-v2")

# (id, hymnary.org heading, SF Symbol, first, last) in hymnal order.
SECTIONS = [
    ("worship", "Worship", "hands.sparkles", 1, 69),
    ("trinity", "Trinity", "triangle", 70, 73),
    ("god-the-father", "God the Father", "sun.max", 74, 114),
    ("jesus-christ", "Jesus Christ", "crown", 115, 256),
    ("holy-spirit", "Holy Spirit", "flame", 257, 270),
    ("holy-scriptures", "Holy Scriptures", "book", 271, 278),
    ("gospel", "Gospel", "heart", 279, 343),
    ("christian-church", "Christian Church", "building.columns", 344, 379),
    ("doctrines", "Doctrines", "text.book.closed", 380, 437),
    ("early-advent", "Early Advent", "hourglass", 438, 454),
    ("christian-life", "Christian Life", "figure.walk", 455, 649),
    ("christian-home", "Christian Home", "house", 650, 659),
    ("sentences-and-responses", "Sentences and Responses", "text.bubble", 660, 695),
]

# Hymnals numbered like Christ In Song, and the last number that lines up with
# the English edition (checked by title_english, AH refs and verse/chorus shape;
# Kinyarwanda follows CIS to 200 and then goes its own way). Only bundled
# hymnals; unbundled ones (xitsonga, tonga, tumbuka, sepedi, icibemba: 300,
# kinyarwanda: 200) go back here if they return to the app.
CIS_NUMBERED = {
    "english": 300, "chichewa": 300, "tswana": 300, "xhosa": 300, "sotho": 300,
    "shona": 300, "venda": 300, "zulu": 300, "ndebele": 300,
}
# cis-v2 files whose hymnal_references carry SDAH numbers for CIS hymns (both
# number like CIS up to 300).
CIS_REF_SOURCES = {"tonga": "tonga/tonga.json", "sepedi": "sepedi/sepedi.json"}
CIS_REF_LAST = 300
SDAH_KEY = "sdah"
ALIASES = {"Christan Life": "Christian Life", "Doctrine": "Doctrines"}


def load(key, folder=HYMNALS):
    with open(os.path.join(folder, key + ".json"), encoding="utf-8") as f:
        return {h["number"]: h for h in json.load(f)["hymns"]}


def section_for(n):
    for s in SECTIONS:
        if s[3] <= n <= s[4]:
            return s
    return None


def check_source():
    """Every hymn number the hymnary.org index files under a section must fall in
    that section's range. Returns the cross-listed exceptions."""
    names = {s[1] for s in SECTIONS}
    exceptions, seen = [], set()
    for line in open(SOURCE, encoding="utf-8"):
        if line.startswith("#") or "|" not in line:
            continue
        heading, nums = line.split("|", 1)
        name = ALIASES.get(heading.split(" - ")[0].strip(), heading.split(" - ")[0].strip())
        if name not in names:
            continue  # readings, sentences beyond 695, benedictions…
        lo, hi = next((s[3], s[4]) for s in SECTIONS if s[1] == name)
        for n in (int(m) for m in re.findall(r"\b(\d+)[A-F]?\b", nums)):
            seen.add(n)
            if not lo <= n <= hi:
                exceptions.append((n, name))
    gaps = [s for s in SECTIONS if not any(s[3] <= n <= s[4] for n in seen)]
    if gaps:
        sys.exit(f"sections with no hymns in the source: {[s[1] for s in gaps]}")
    for a, b in zip(SECTIONS, SECTIONS[1:]):
        if a[4] + 1 != b[3]:
            sys.exit(f"sections not contiguous: {a[1]} / {b[1]}")
    return exceptions


def first_line(h):
    line = next((b["l"][0] for b in h["blocks"] if b["l"]), "")
    return re.sub(r"[^a-z ]", "", line.lower().replace("’", "'"))


def similar(a, b):
    return difflib.SequenceMatcher(None, a, b).ratio()


def cis_sdah_refs(english, sdah):
    """CIS number -> SDAH number, plus a log of where each came from.

    The cross-references have slips (English 119-121 are shifted by one, 173/174
    swapped), so a ref is only taken when the SDAH hymn it names has the same
    title or first line. The subtitle ref is tried first, then Tonga/Sepedi. If
    none agree but one SDAH hymn has the same first line, that one is used."""
    candidates = {n: [("subtitle", h["refs"]["sdah"])] for n, h in english.items() if h.get("refs", {}).get("sdah")}
    for key, path in CIS_REF_SOURCES.items():
        with open(os.path.join(CIS_SRC, path), encoding="utf-8") as f:
            for h in json.load(f):
                m = re.search(r"\bSDAH[\s-]+(\d+)", h.get("hymnal_references") or "", re.I)
                n = h["number"]
                if m and n <= CIS_REF_LAST and n in english:
                    candidates.setdefault(n, []).append(("hymnal_references", int(m.group(1))))
    firsts = {v: first_line(h) for v, h in sdah.items()}
    refs, log = {}, {"subtitle": 0, "hymnal_references": 0, "corrected": [], "rejected": []}
    for n, cands in sorted(candidates.items()):
        en_title, en_first = english[n]["title"].lower(), first_line(english[n])
        for src, v in cands:
            if v in sdah and (similar(en_title, sdah[v]["title"].lower()) >= 0.5 or similar(en_first, firsts[v]) >= 0.6):
                refs[n] = v
                log[src] += 1
                break
        else:
            best = max(firsts, key=lambda v: similar(en_first, firsts[v]))
            if similar(en_first, firsts[best]) >= 0.9:
                refs[n] = best
                log["corrected"].append((n, english[n]["title"], [v for _, v in cands], best))
            else:
                log["rejected"].append((n, english[n]["title"], [v for _, v in cands]))
    return refs, log


def main(check, sdah_dir):
    exceptions = check_source()
    english, sdah = load("english"), load(SDAH_KEY, sdah_dir)
    refs, log = cis_sdah_refs(english, sdah)

    hymns = {s[0]: {} for s in SECTIONS}
    unmapped = {}
    for key, last in CIS_NUMBERED.items():
        book = load(key)
        unmapped[key] = 0
        for n in sorted(book):
            s = section_for(refs[n]) if n <= last and n in refs else None
            if s:
                hymns[s[0]].setdefault(key, []).append(n)
            else:
                unmapped[key] += 1

    collections = []
    for order, (cid, title, symbol, lo, hi) in enumerate(SECTIONS, 1):
        h = hymns[cid]
        collections.append({
            "id": cid, "title": title, "symbol": symbol, "order": order,
            "sdah": [lo, hi],
            "counts": {k: len(v) for k, v in h.items()},
            "hymns": h,
        })
    data = {"version": 2,
            "source": "Seventh-day Adventist Hymnal (1985) sections, https://hymnary.org/browse/topics/SDAH1985",
            "collections": collections}

    print(f"cross-listed in the source outside their section: {exceptions}")
    print(f"CIS SDAH refs: {len(refs)} used ({log['subtitle']} subtitle, {log['hymnal_references']} hymnal_references, "
          f"{len(log['corrected'])} corrected by first line), {len(log['rejected'])} rejected")
    for m in log["corrected"]:
        print("  corrected (CIS, title, refs, used):", m)
    for m in log["rejected"]:
        print("  rejected  (CIS, title, refs):", m)
    print(f"{'section':26}" + "".join(f"{k[:7]:>8}" for k in CIS_NUMBERED))
    for c in collections:
        print(f"{c['title']:26}" + "".join(f"{c['counts'].get(k, 0):>8}" for k in CIS_NUMBERED))
    print(f"{'(no collection)':26}" + "".join(f"{unmapped[k]:>8}" for k in CIS_NUMBERED))
    if not check:
        with open(OUT, "w", encoding="utf-8") as f:
            f.write("{\n" + f'  "version": {data["version"]},\n  "source": {json.dumps(data["source"])},\n  "collections": [\n')
            f.write(",\n".join("    " + json.dumps(c, ensure_ascii=False, separators=(", ", ": ")) for c in collections))
            f.write("\n  ]\n}\n")
        print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    args = sys.argv[1:]
    sdah_dir = args[args.index("--sdah") + 1] if "--sdah" in args else os.path.join(ROOT, "build", "hymnals-all")
    main("--check" in args, sdah_dir)
