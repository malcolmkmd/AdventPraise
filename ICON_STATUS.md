# App icon status

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds with no warnings. `assetutil` on the built `Assets.car` lists AppIcon at 1024 px in three appearances: any, `UIAppearanceDark` and `ISAppearanceTintable`.

## Logo: not the SDA logo

**This repo has no SDA church logo, and neither did the legacy app.** The splash job didn't restore one either: see SPLASH_STATUS.md, "Logo: which file was used". The legacy `AdventPraises/…/AppIcon.appiconset` only ever held a `Contents.json` with no image. The only image ever committed is the placeholder icon from 45795f7: a gold ring around a Didone "AP" on evergreen.

So the icon uses **the same mark as the splash**: the ring and the Didot Bold "AP", drawn from vectors. To use the real SDA logo, add it as a vector file (PDF or SVG). Then replace `monogram()` (and the ring, if needed) in `Tools/make_app_icon.swift` and run the script again.

## Design

- 1024 × 1024, single size. At the top is the ring (352 pt across, 22 pt stroke) with "AP" inside (124 pt cap height). Below it, "Advent Praise" in New York semibold, the app's `.serif` design. The two words are stacked, each up to 700 pt wide, so the wordmark stays large enough to read at small sizes. The whole block is centred, with about 120 pt clear at the top and 135 pt at the bottom, so it stays inside the rounded mask.
- Colours are DS tokens:

| Appearance | Ground | Ring | "AP" | Wordmark |
|---|---|---|---|---|
| Light (`AppIcon.png`) | evergreen #1F7466 | brassOnDark #D4A853 | paper #F7F4EE | paper #F7F4EE |
| Dark (`AppIcon-dark.png`) | stage #0E1110 | brassOnDark #D4A853 | evergreenOnDark #5FB8A6 | #E8E6E0 (Black surface ink) |
| Tinted (`AppIcon-tinted.png`) | black | 78 % gray | white | white |

- All three PNGs are 8-bit RGB with **no alpha channel** (`sips -g hasAlpha` reports `no`).
- Small sizes: at 60 pt (180 px and 120 px), "Advent Praise" reads clearly. At 29 pt @2x (58 px) it is still legible. At 29 pt @1x (29 px) only the ring reads, and the words become texture. The thin hairlines of the Didot "AP" fade below about 87 px, but its heavy stems still show.

## Regenerate

```
xcrun swift Tools/make_app_icon.swift [Assets.xcassets] [preview dir]
```

The defaults are `AdventPraise/Resources/Assets.xcassets` and `build/shots/icon`. The script draws every shape from vectors at 1024 px (glyph outlines plus a stroked circle) with CoreGraphics. It uses CoreGraphics rather than Pillow because neither Pillow nor ImageMagick is installed. It writes the three PNGs and `AppIcon.appiconset/Contents.json`, with the dark and tinted entries under `luminosity` appearances.

## Previews (`build/shots/icon/`, git-ignored)

The previews are masked with a rounded square.

- `build/shots/icon/sizes.png`: all three appearances side by side at true pixel size (180, 120, 87, 58 and 29 px).
- `build/shots/icon/AppIcon-1024.png`, `AppIcon-dark-1024.png`, `AppIcon-tinted-1024.png`
- `build/shots/icon/AppIcon{,-dark,-tinted}-60pt@3x.png`, `-60pt@2x.png`, `-29pt@2x.png`, `-29pt@1x.png`

## Files touched

`AdventPraise/Resources/Assets.xcassets/AppIcon.appiconset/` (the 3 PNGs and Contents.json), the new `Tools/make_app_icon.swift`, and this file.
