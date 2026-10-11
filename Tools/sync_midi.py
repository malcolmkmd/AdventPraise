#!/usr/bin/env python3
"""Copy the Cyber Hymnal MIDI files into the app bundle and write the manifest.

    python3 Tools/sync_midi.py ../cyber AdventPraise/Resources/Midi

Reads <cyber>/ledger.csv and keeps only rows whose decision is 'downloaded'.
For each, copies <cyber>/midi-raw/hymn-NNN.mid (NNN = Christ In Song number,
English hymnal) into the destination, removes .mid files there that the ledger
no longer marks as downloaded, and writes midi-manifest.json:

    {"hymnals": {"english": {"file": "hymn-%03d", "hymns": [1, 2, 3, ...]}}}

The app reads only the manifest (Model/MIDICatalog.swift), so a second
download pass needs no code change: re-run this script and rebuild.
Provenance (page and .mid URL per hymn) goes to docs/midi-sources.csv, which
is not bundled.
"""

import csv
import json
import shutil
import sys
from pathlib import Path


def main() -> int:
    cyber = Path(sys.argv[1] if len(sys.argv) > 1 else "../cyber")
    dest = Path(sys.argv[2] if len(sys.argv) > 2 else "AdventPraise/Resources/Midi")
    sources_out = Path(sys.argv[3] if len(sys.argv) > 3 else "docs/midi-sources.csv")
    raw = cyber / "midi-raw"
    dest.mkdir(parents=True, exist_ok=True)

    with open(cyber / "ledger.csv", newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r["decision"].strip() == "downloaded"]

    kept, missing, sources = [], [], []
    for row in rows:
        number = int(row["hymn_no"])
        name = f"hymn-{number:03d}.mid"
        src = raw / name
        if not src.is_file():
            missing.append(name)
            continue
        target = dest / name
        if not target.exists() or target.read_bytes() != src.read_bytes():
            shutil.copyfile(src, target)
        kept.append(number)
        sources.append({"hymn_no": number, "title": row["title"],
                        "page_url": row["page_url"], "mid_url": row["mid_url"]})

    wanted = {f"hymn-{n:03d}.mid" for n in kept}
    removed = [p.name for p in dest.glob("*.mid") if p.name not in wanted]
    for name in removed:
        (dest / name).unlink()

    kept.sort()
    manifest = {"hymnals": {"english": {"file": "hymn-%03d", "hymns": kept}}}
    (dest / "midi-manifest.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")

    sources_out.parent.mkdir(parents=True, exist_ok=True)
    with open(sources_out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["hymn_no", "title", "page_url", "mid_url"])
        writer.writeheader()
        writer.writerows(sorted(sources, key=lambda s: s["hymn_no"]))

    print(f"{len(kept)} MIDI files in {dest}; removed {len(removed)}; "
          f"missing from midi-raw: {len(missing)} {missing[:10]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
