# App icon and splash: the SDA logo

`xcodebuild -project AdventPraise.xcodeproj -scheme AdventPraise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds with no warnings. The splash was checked on an iPhone 17 Pro simulator (iOS 27.0) in light and dark.

This replaces the "AP" monogram from ICON_STATUS.md and SPLASH_STATUS.md with the Seventh-day Adventist church logo: three flame strokes, the open Bible and the cross.

## The vector

- **Source:** `Tools/source/sda-logo-6.3.png`, the live 6.3 App Store icon (512 px). It is committed because the trace is regenerated from it.
- **Trace:** `Tools/source/sda-logo.svg`, written by `xcrun swift Tools/trace_sda_logo.swift`. potrace isn't installed, so the script does the same job itself:
  1. It measures ink coverage from each pixel's brightest channel. White is ground, and the logo's gradient body is ink.
  2. It runs marching squares at 50 % coverage, so edges land on subpixel positions from the antialiasing.
  3. It keeps corners sharp: the flame tips, the page corners and the cross's right angles. The runs between corners are fitted with cubic Béziers (Schneider's algorithm) to within 0.45 px.
- **Result:** 9 closed loops and 144 cubics, filled even-odd, because the cross and the gaps between the flame strokes are holes. Nothing was added, removed or redrawn.
- **Fidelity:** rasterised back at 512 px, the outline differs from the source at the 50 % level on 547 edge pixels, 1.1 % of the 48,792 inked pixels. There is no shape-level difference. See `build/shots/icon2/trace-diff.png` (red = missed, blue = extra) and `trace-overlay.png` (the outline over the source at 2×).

## App icon (`Tools/make_app_icon.swift`)

The logo is 450 pt tall. Below it, "Advent Praise" is stacked in New York semibold (the app's `.serif`), with the wider word 540 pt across. The whole block is centred on the 1024 canvas.

The gradient runs the same way as the original's green-to-slate: green at the book's bottom-left corner, gold at the flame's top-right. It is pure green to 15 % of the diagonal and pure gold from 85 %, so the muddy middle mix never takes over.

| Appearance | Ground | Logo gradient | Wordmark |
|---|---|---|---|
| Light (`AppIcon.png`) | evergreen #1F7466 | evergreenOnDark #5FB8A6 → brassOnDark #D4A853 | paper #F7F4EE |
| Dark (`AppIcon-dark.png`) | stage #0E1110 | evergreenOnDark → brassOnDark | #E8E6E0 |
| Tinted (`AppIcon-tinted.png`) | black | 74 % → 100 % gray | white |

On the evergreen ground, the green end has to be `evergreenOnDark`; plain evergreen would vanish into the ground. All three PNGs are RGB with no alpha.

**Legibility** (`build/shots/icon2/sizes.png`, at true pixel size):

- **60 pt (180 and 120 px):** the flames, book and cross are all distinct, and "Advent Praise" reads easily.
- **29 pt @3x and @2x (87 and 58 px):** the logo is still clearly the SDA mark. The wordmark is readable at 87 px and just about readable at 58 px.
- **29 pt @1x (29 px):** the logo reads as a silhouette, and the words become texture. The previous icon behaved the same way at this size.

## Splash and launch screen (`Tools/make_splash_logo.swift`)

- `LaunchLogo.imageset/LaunchLogo.pdf` is the gradient logo, 160 × 147.3 pt, as a single vector PDF. The light and dark launch screens differ only in `LaunchBackground` (evergreen / Stage), so the separate dark PDF is gone.
- `AdventPraise/App/SDALogoShape.swift` is **generated** by the same script. It holds the outline as a SwiftUI `Shape` in unit coordinates, along with:
  - `revealAnchor` and `revealRadius`: the centre and radius of the largest disc inside the ink, found with a chamfer distance transform. It sits on the book's left page, at 11.3 pt radius.
- `SplashMonogram.imageset` and `SplashRing.imageset` are deleted.
- `SplashView`:
  - The first frame matches the launch frame: the same 160 pt logo, centred, with the same gradient stops.
  - The logo dips to 0.88. Its gradient then fades over 0.22 s, and the ground's logo-shaped hole (`RevealGround`, even-odd) grows about `revealAnchor` on the same critically damped 0.75 s spring.
  - The app shows through the logo and zooms into the left page, and the gaps between the flame strokes sweep off as ground-coloured bands.
  - The zoom stops once the page's disc clears the farthest screen corner.
  - The hole is a `Shape` rebuilt every frame, so its edge stays sharp at the roughly 45× final scale.
  - Reduce Motion, timing, What's New gating and the debug arguments are unchanged.
- **Previews:**
  - `build/shots/icon2/splash-light-sequence.png` and `splash-dark-sequence.png` are contact sheets of the reveal at `-uiDebugSplashSpeed 0.08`.
  - The first tile in the light sheet is the system launch screen, which is more saturated in screenshots. That is the capture artefact already noted in SPLASH_STATUS.md.

## Regenerate

```
xcrun swift Tools/trace_sda_logo.swift      # PNG → Tools/source/sda-logo.svg (+ trace previews)
xcrun swift Tools/make_app_icon.swift       # SVG → AppIcon.appiconset (+ build/shots/icon2 previews)
xcrun swift Tools/make_splash_logo.swift    # SVG → LaunchLogo, LaunchBackground, SDALogoShape.swift
```

Run them from the repo root. Both generators read the SVG, so a hand-cleaned or official SVG can replace the trace, as long as its path uses absolute M/L/C/Z.

## Previews (`build/shots/icon2/`, git-ignored)

- `AppIcon{,-dark,-tinted}-1024.png`, plus `-60pt@3x`, `-60pt@2x`, `-29pt@2x` and `-29pt@1x` for each
- `sizes.png`
- `trace-diff.png`, `trace-overlay.png`
- `splash-light-sequence.png`, `splash-dark-sequence.png`

## Open

- The SDA logo is a registered mark of the General Conference, and its identity guidelines set rules for how the logo may be coloured. The 6.3 icon already used a custom gradient. If the recolouring matters for the store listing, check those guidelines; changing the colours only means editing the palettes in the two generators.
- The splash wasn't checked on an iPad simulator. Its geometry comes from the window size, as before.
