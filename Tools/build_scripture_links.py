#!/usr/bin/env python3
"""Build AdventPraise/Resources/Extras/scripture_links.json.

Usage: build_scripture_links.py

Reads docs/scripture/<hymnal>.jsonl, one reviewed reference per line:

  {"n": 168, "ref": "Psalms 23:1", "source": "lyric", "confidence": "high",
   "line": "The Lord is my shepherd, no want Shall I know;", "why": "quotes KJV ..."}

and checks every row before writing anything:
  - `line` appears verbatim in that hymn in Resources/Hymnals/<hymnal>.json
    (for `lyric` rows: the evidence the reference rests on);
  - the book is a known name and the chapter exists (KJV chapter counts);
  - verses are positive and `from <= to`;
  - source and confidence are known values; at most one row per ref per hymn.

The app file is compact: per hymn, rows of [ref, source, confidence], hymns in
number order and passages in canonical order. Evidence lines stay in docs/.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HYMNALS = ["english"]
SOURCES = {
    "lyric": "The hymn's own words quote or closely paraphrase the passage (checked against the KJV).",
    "cis1908": "Scripture text printed with the hymn in Christ in Song (1908).",
    "hymnary": "Hymnary.org scripture index for the hymn.",
}
CONFIDENCE = {
    "high": "The hymn quotes or near-quotes the verse.",
    "medium": "The hymn clearly echoes this specific passage without quoting it.",
}
CHAPTERS = {  # KJV chapter counts, canonical order
    "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
    "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24, "1 Kings": 22,
    "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36, "Ezra": 10, "Nehemiah": 13,
    "Esther": 10, "Job": 42, "Psalms": 150, "Proverbs": 31, "Ecclesiastes": 12,
    "Song of Solomon": 8, "Isaiah": 66, "Jeremiah": 52, "Lamentations": 5, "Ezekiel": 48,
    "Daniel": 12, "Hosea": 14, "Joel": 3, "Amos": 9, "Obadiah": 1, "Jonah": 4, "Micah": 7,
    "Nahum": 3, "Habakkuk": 3, "Zephaniah": 3, "Haggai": 2, "Zechariah": 14, "Malachi": 4,
    "Matthew": 28, "Mark": 16, "Luke": 24, "John": 21, "Acts": 28, "Romans": 16,
    "1 Corinthians": 16, "2 Corinthians": 13, "Galatians": 6, "Ephesians": 6,
    "Philippians": 4, "Colossians": 4, "1 Thessalonians": 5, "2 Thessalonians": 3,
    "1 Timothy": 6, "2 Timothy": 4, "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5,
    "1 Peter": 5, "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1, "Jude": 1,
    "Revelation": 22,
}
ORDER = {b: i for i, b in enumerate(CHAPTERS)}
REF = re.compile(r"^(.+) (\d+)(?::(\d+)(?:-(\d+))?)?$")


def parse(ref):
    m = REF.match(ref)
    if not m:
        raise ValueError(f"bad ref format {ref!r}")
    book, ch, a, b = m.group(1), int(m.group(2)), m.group(3), m.group(4)
    if book not in CHAPTERS:
        raise ValueError(f"unknown book {book!r}")
    if not 1 <= ch <= CHAPTERS[book]:
        raise ValueError(f"{book} has {CHAPTERS[book]} chapters, not {ch}")
    a = int(a) if a else None
    b = int(b) if b else None
    if (a is not None and a < 1) or (b is not None and b <= a):
        raise ValueError(f"bad verse range in {ref!r}")
    return (ORDER[book], ch, a or 0, b or 0)


def main():
    out = {"version": 2, "columns": ["ref", "source", "confidence"],
           "sources": SOURCES, "confidence": CONFIDENCE, "hymnals": {}}
    errors = []
    for key in HYMNALS:
        hymnal = json.load(open(os.path.join(ROOT, "AdventPraise/Resources/Hymnals", f"{key}.json")))
        text = {h["number"]: [l for b in h["blocks"] for l in b["l"]] for h in hymnal["hymns"]}
        rows = {}
        path = os.path.join(ROOT, "docs/scripture", f"{key}.jsonl")
        for i, raw in enumerate(open(path, encoding="utf-8"), 1):
            if not raw.strip():
                continue
            e = json.loads(raw)
            where = f"{key}.jsonl:{i} (hymn {e.get('n')})"
            try:
                sort_key = parse(e["ref"])
                if e["n"] not in text:
                    raise ValueError("no such hymn")
                if e["source"] not in SOURCES or e["confidence"] not in CONFIDENCE:
                    raise ValueError("unknown source or confidence")
                if e["source"] == "lyric" and e["line"] not in text[e["n"]]:
                    raise ValueError(f"line not in hymn: {e['line']!r}")
                hymn = rows.setdefault(e["n"], {})
                if e["ref"] in hymn:
                    raise ValueError(f"duplicate {e['ref']}")
                hymn[e["ref"]] = (sort_key, [e["ref"], e["source"], e["confidence"]])
            except (KeyError, ValueError) as err:
                errors.append(f"{where}: {err}")
        out["hymnals"][key] = {
            str(n): [row for _, row in sorted(rows[n].values())] for n in sorted(rows)
        }
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    dest = os.path.join(ROOT, "AdventPraise/Resources/Extras/scripture_links.json")
    with open(dest, "w", encoding="utf-8") as f:
        # One hymn per line: compact, but diffs stay readable.
        f.write('{"version":2,"columns":["ref","source","confidence"],\n')
        f.write('"sources":' + json.dumps(SOURCES, ensure_ascii=False) + ",\n")
        f.write('"confidence":' + json.dumps(CONFIDENCE, ensure_ascii=False) + ",\n")
        f.write('"hymnals":{')
        for k, (key, hymns) in enumerate(out["hymnals"].items()):
            f.write(("," if k else "") + json.dumps(key) + ":{\n")
            f.write(",\n".join(json.dumps(n) + ":" + json.dumps(r, ensure_ascii=False, separators=(",", ":"))
                               for n, r in hymns.items()))
            f.write("\n}")
        f.write("}}\n")
    for key, hymns in out["hymnals"].items():
        count = sum(len(r) for r in hymns.values())
        print(f"{key}: {count} references across {len(hymns)} hymns -> {os.path.relpath(dest, ROOT)}")


if __name__ == "__main__":
    main()
