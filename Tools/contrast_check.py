#!/usr/bin/env python3
"""WCAG 2.x contrast of the Tools sheets' colour pairs on every reading surface.

Values mirror AdventPraise/Design/DesignTokens.swift (DSSurface, DS.Palette).
Translucent colours are composited over what they sit on before measuring.
Run: python3 Tools/contrast_check.py   (exits 1 if any pair fails)
"""
import sys

def hexrgb(h): return [((h >> s) & 0xFF) / 255 for s in (16, 8, 0)]
def over(fg, a, bg): return [f * a + b * (1 - a) for f, b in zip(fg, bg)]
def lum(c):
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

WHITE, BLACK = hexrgb(0xFFFFFF), hexrgb(0x000000)
EVERGREEN, EVERGREEN_DEEP, EVERGREEN_DARK = hexrgb(0x1F7466), hexrgb(0x19604F), hexrgb(0x5FB8A6)
BRASS, BRASS_DEEP, BRASS_DARK = hexrgb(0x7F5B1C), hexrgb(0x6B4C14), hexrgb(0xD4A853)

SURFACES = {
    #          background  foreground  elevated   tint            brass       dark
    "paper":     (0xF7F4EE, 0x1C1F1E, 0xFCFBF8, EVERGREEN,      BRASS,      False),
    "parchment": (0xF3E9D4, 0x3B2F1E, 0xF9F2E3, EVERGREEN,      BRASS,      False),
    "sepia":     (0xE6D6B9, 0x3E2F1D, 0xEFE3CC, EVERGREEN_DEEP, BRASS_DEEP, False),
    "muted":     (0x262A29, 0xD9DBD8, 0x323736, EVERGREEN_DARK, BRASS_DARK, True),
    "black":     (0x000000, 0xE8E6E0, 0x1B1C1B, EVERGREEN_DARK, BRASS_DARK, True),
}

# DS.Language: hymnal tile fills (light grounds, dark grounds), text in DSSurface.languageInk.
LANGUAGES = {
    "indigo": (0x3F3D8F, 0x5250A6), "terracotta": (0xA3452A, 0xA54B30), "sapphire": (0x1D5A94, 0x2866A2),
    "teal": (0x0F6878, 0x13707F), "ochre": (0x8A5908, 0x8F5E0C), "olive": (0x5C6B1A, 0x5F6F1D),
    "plum": (0x74305E, 0x8A3B70), "forest": (0x2D6639, 0x34723F), "clay": (0x8F4F55, 0x95545A),
    "midnight": (0x23415F, 0x2E5276),
    "slate": (0x4C5857, 0x5A6766),
}
LANGUAGE_INK_DARK = hexrgb(0xF7F1E6)

TEXT, UI = 4.5, 3.0   # WCAG AA: normal text; non-text UI and large text
failures = 0

def check(surface, name, a, b, need):
    global failures
    r = ratio(a, b)
    ok = r >= need
    failures += not ok
    print(f"  {'ok  ' if ok else 'FAIL'} {r:5.2f}:1  (need {need})  {name}")

for name, (bg, fg, el, tint, brass, dark) in SURFACES.items():
    bg, fg, el = hexrgb(bg), hexrgb(fg), hexrgb(el)
    secondary = over(fg, 0.78 if name == "sepia" else 0.72, bg)
    secondary_el = over(fg, 0.78 if name == "sepia" else 0.72, el)
    on_tint = BLACK if dark else WHITE
    border = over(fg, 0.62, el)           # DSSurface.controlBorder (0.62) around an elevated control
    wash = over(tint, 0.14, el)           # DS.Fill.tintOn wash on an elevated chip
    print(name)
    check(name, "text on sheet ground", fg, bg, TEXT)
    check(name, "text on elevated control", fg, el, TEXT)
    check(name, "secondary text on ground", secondary, bg, TEXT)
    check(name, "secondary text on elevated bar", secondary_el, el, TEXT)
    check(name, "tint text (Done, links) on ground", tint, bg, TEXT)
    check(name, "tint text on elevated control", tint, el, TEXT)
    check(name, "onTint text on solid tint (selected chip, sound button)", on_tint, tint, TEXT)
    check(name, "brass text on ground", brass, bg, TEXT)
    check(name, "text in a tint wash (hidden word, chip)", fg, wash, TEXT)
    check(name, "tint border of a wash vs ground", tint, bg, UI)
    check(name, "word chip outline vs elevated choice panel", over(fg, 0.62, bg), el, UI)
    check(name, "text in the brass glow of a just-filled word", fg, over(brass, 0.18, bg), TEXT)
    check(name, "secondary text on elevated completion card", secondary_el, el, TEXT)
    check(name, "control border vs ground", border, bg, UI)
    check(name, "solid tint control vs ground", tint, bg, UI)
    ink = LANGUAGE_INK_DARK if dark else WHITE
    for lang, (light, dark_fill) in LANGUAGES.items():
        fill = hexrgb(dark_fill if dark else light)
        check(name, f"hymnal tile text and check on {lang}", ink, fill, TEXT)
    # The ring sits 3 pt outside the tile, so the ground is the colour it meets.
    check(name, "current-hymnal ring vs ground", fg, bg, UI)

print("\nall pass" if not failures else f"\n{failures} failing pair(s)")
sys.exit(1 if failures else 0)
