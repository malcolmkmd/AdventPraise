// Draws the 1024 × 1024 app icon: the Seventh-day Adventist church logo (flame
// over an open Bible with a cross, traced by Tools/trace_sda_logo.swift into
// Tools/source/sda-logo.svg) with a gold-to-green gradient, above the wordmark
// "Advent Praise" in New York, the app's serif.
//
// Usage: xcrun swift Tools/make_app_icon.swift [Assets.xcassets] [preview dir]
//   defaults: AdventPraise/Resources/Assets.xcassets  build/shots/icon2
//
// Writes AppIcon.appiconset with the iOS 18+ appearances:
//   AppIcon.png         light: evergreen ground, brass-to-mint logo, paper wordmark (RGB, no alpha)
//   AppIcon-dark.png    dark: Stage ground, brass-to-evergreen logo, light wordmark
//   AppIcon-tinted.png  tinted: grayscale on black; the system tints by luminance
// and previews of each at 1024 and at the home screen / Settings sizes.
//
// Everything is drawn from vectors (the traced logo and glyph outlines) at full
// size; nothing is upscaled. Colours are the DS tokens (DesignTokens.swift).
// The gradient runs like the original's green-to-slate: green at the book's
// bottom-left corner, gold at the flame's top-right.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024

// MARK: Layout (pt on the 1024 canvas)

let logoHeight: CGFloat = 450
let wordmarkWidth: CGFloat = 540      // the wider of the two words
let logoToWordmark: CGFloat = 50
let lineGap: CGFloat = 22             // between the two words' ink
let opticalLift: CGFloat = 6          // sit the block a hair above centre
/// Pure green up to 15 % of the diagonal and pure gold from 85 %, so neither end
/// is only ever the muddy mix.
let gradientStops: [CGFloat] = [0.15, 0.85]

// MARK: Colour

struct RGB { let r, g, b: CGFloat; init(_ hex: UInt32) {
    r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255 }
    init(gray: CGFloat) { r = gray; g = gray; b = gray }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

let evergreen = RGB(0x1F7466)
let evergreenOnDark = RGB(0x5FB8A6)
let brassOnDark = RGB(0xD4A853)
let paper = RGB(0xF7F4EE)
let stage = RGB(0x0E1110)
let blackInk = RGB(0xE8E6E0) // DSSurface.black foreground

/// `green` sits at the book's bottom-left, `gold` at the flame's top-right.
struct Palette { let ground, green, gold, wordmark: RGB }

let variants: [(file: String, palette: Palette)] = [
    // On evergreen the green end has to be the on-dark evergreen to read.
    ("AppIcon.png", Palette(ground: evergreen, green: evergreenOnDark, gold: brassOnDark, wordmark: paper)),
    ("AppIcon-dark.png", Palette(ground: stage, green: evergreenOnDark, gold: brassOnDark, wordmark: blackInk)),
    // Tinted: luminance becomes tint strength, so the gradient is a step of grey.
    ("AppIcon-tinted.png", Palette(ground: RGB(gray: 0), green: RGB(gray: 0.74), gold: RGB(gray: 1), wordmark: RGB(gray: 1))),
]

// MARK: Shapes

/// The `d` of the traced SVG (absolute M, L, C, Z only, as the tracer writes
/// it), in the SVG's y-down coordinates.
func logoPath() -> CGPath {
    let svg = try! String(contentsOf: URL(fileURLWithPath: "Tools/source/sda-logo.svg"), encoding: .utf8)
    guard let start = svg.range(of: " d=\"")?.upperBound,
          let end = svg[start...].firstIndex(of: "\"") else { fatalError("no path in sda-logo.svg") }
    let path = CGMutablePath()
    let scanner = Scanner(string: String(svg[start..<end]))
    func point() -> CGPoint { CGPoint(x: scanner.scanDouble()!, y: scanner.scanDouble()!) }
    while let command = scanner.scanCharacter() {
        switch command {
        case "M": path.move(to: point())
        case "L": path.addLine(to: point())
        case "C": let c1 = point(), c2 = point(); path.addCurve(to: point(), control1: c1, control2: c2)
        case "Z": path.closeSubpath()
        case _ where command.isWhitespace: continue
        default: fatalError("unexpected SVG command \(command)")
        }
    }
    return path
}

/// Glyph outlines of `text` in `font`, with the font's own kerning, y up.
func outline(_ text: String, _ font: CTFont) -> CGPath {
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        let runFont = (CTRunGetAttributes(run) as Dictionary)[kCTFontAttributeName] as! CTFont
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for (glyph, position) in zip(glyphs, positions) {
            if let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                path.addPath(glyphPath, transform: CGAffineTransform(translationX: position.x, y: position.y))
            }
        }
    }
    return path
}

/// Moves and scales `path` so its ink box has `scale` and its centre lands on
/// `center`. `flipY` turns a y-down path (the SVG) y-up.
func place(_ path: CGPath, scale: CGFloat, center: CGPoint, flipY: Bool = false) -> CGPath {
    let box = path.boundingBoxOfPath
    var transform = CGAffineTransform(translationX: center.x, y: center.y)
        .scaledBy(x: scale, y: flipY ? -scale : scale)
        .translatedBy(x: -box.midX, y: -box.midY)
    return path.copy(using: &transform)!
}

/// New York (SwiftUI's `.serif` design), semibold, at a display size so the
/// optical-size axis picks the display cut.
func newYork() -> CTFont {
    let system = NSFont.systemFont(ofSize: 200, weight: .semibold)
    guard let descriptor = system.fontDescriptor.withDesign(.serif),
          let font = NSFont(descriptor: descriptor, size: 200) else { fatalError("New York unavailable") }
    return font as CTFont
}

struct Artwork { let logo: CGPath; let wordmark: CGPath }

/// Canvas in CG coordinates (y up). The block — logo, gap, two words — is
/// centred vertically.
func artwork() -> Artwork {
    let font = newYork()
    let advent = outline("Advent", font), praise = outline("Praise", font)
    let scale = wordmarkWidth / max(advent.boundingBoxOfPath.width, praise.boundingBoxOfPath.width)
    let adventHeight = advent.boundingBoxOfPath.height * scale
    let praiseHeight = praise.boundingBoxOfPath.height * scale

    let blockHeight = logoHeight + logoToWordmark + adventHeight + lineGap + praiseHeight
    let top = size / 2 + blockHeight / 2 + opticalLift
    let adventCenterY = top - logoHeight - logoToWordmark - adventHeight / 2
    let praiseCenterY = adventCenterY - adventHeight / 2 - lineGap - praiseHeight / 2

    let traced = logoPath()
    let logo = place(traced, scale: logoHeight / traced.boundingBoxOfPath.height,
                     center: CGPoint(x: size / 2, y: top - logoHeight / 2), flipY: true)
    let wordmark = CGMutablePath()
    wordmark.addPath(place(advent, scale: scale, center: CGPoint(x: size / 2, y: adventCenterY)))
    wordmark.addPath(place(praise, scale: scale, center: CGPoint(x: size / 2, y: praiseCenterY)))
    return Artwork(logo: logo, wordmark: wordmark)
}

// MARK: Rendering

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func bitmap(_ pixels: Int, alpha: Bool) -> CGContext {
    CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
}

/// Fills the logo (even-odd: the cross and the gaps between flame strokes are
/// holes) with the gradient across its box, bottom-left to top-right.
func fillLogo(_ c: CGContext, _ logo: CGPath, _ p: Palette) {
    let box = logo.boundingBoxOfPath
    let gradient = CGGradient(colorsSpace: srgb, colors: [p.green.cg, p.gold.cg] as CFArray, locations: gradientStops)!
    c.saveGState()
    c.addPath(logo); c.clip(using: .evenOdd)
    c.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: box.minY), end: CGPoint(x: box.maxX, y: box.maxY),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    c.restoreGState()
}

func render(_ art: Artwork, _ p: Palette) -> CGImage {
    let c = bitmap(Int(size), alpha: false)
    c.setFillColor(p.ground.cg); c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    fillLogo(c, art.logo, p)
    c.addPath(art.wordmark); c.setFillColor(p.wordmark.cg); c.fillPath()
    return c.makeImage()!
}

func writePNG(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("can't write \(url.path)") }
}

/// The icon as the system shows it: downsampled, under the rounded-square mask
/// (continuous corners approximated by a 22.4 % radius).
func masked(_ icon: CGImage, pixels: Int) -> CGImage {
    let c = bitmap(pixels, alpha: true)
    let rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    let radius = CGFloat(pixels) * 0.224
    c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.clip()
    c.interpolationQuality = .high
    c.draw(icon, in: rect)
    return c.makeImage()!
}

/// One row per appearance: 60 pt @3x, 60 pt @2x, 29 pt @3x, 29 pt @2x, 29 pt @1x,
/// on a wallpaper-ish ground, at true pixel size.
func sheet(_ icons: [CGImage], grounds: [RGB]) -> CGImage {
    let sizes = [180, 120, 87, 58, 29], pad = 40
    let width = sizes.reduce(pad) { $0 + $1 + pad }, rowHeight = sizes[0] + pad
    let c = bitmap(max(width, rowHeight * icons.count + pad), alpha: false)
    let height = c.height
    c.setFillColor(RGB(0x8A8F8C).cg); c.fill(CGRect(x: 0, y: 0, width: c.width, height: height))
    for (row, icon) in icons.enumerated() {
        let y = height - pad - sizes[0] - row * rowHeight
        c.setFillColor(grounds[row].cg)
        c.fill(CGRect(x: 0, y: y - pad / 2, width: c.width, height: rowHeight))
        var x = pad
        for s in sizes {
            c.draw(masked(icon, pixels: s), in: CGRect(x: x, y: y + (sizes[0] - s) / 2, width: s, height: s))
            x += s + pad
        }
    }
    return c.makeImage()!
}

// MARK: Main

let args = CommandLine.arguments.dropFirst()
let catalog = URL(fileURLWithPath: args.first ?? "AdventPraise/Resources/Assets.xcassets")
let previews = URL(fileURLWithPath: args.dropFirst().first ?? "build/shots/icon2")
let iconset = catalog.appendingPathComponent("AppIcon.appiconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try! FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

let art = artwork()
var icons: [CGImage] = []
for (file, palette) in variants {
    let image = render(art, palette)
    icons.append(image)
    writePNG(image, iconset.appendingPathComponent(file))
    let name = (file as NSString).deletingPathExtension
    writePNG(masked(image, pixels: 1024), previews.appendingPathComponent("\(name)-1024.png"))
    for (label, pixels) in [("60pt@3x", 180), ("60pt@2x", 120), ("29pt@2x", 58), ("29pt@1x", 29)] {
        writePNG(masked(image, pixels: pixels), previews.appendingPathComponent("\(name)-\(label).png"))
    }
}
// Light on a light wallpaper, dark and tinted on dark ones.
writePNG(sheet(icons, grounds: [RGB(0xDCE3E0), RGB(0x202423), RGB(0x202423)]),
         previews.appendingPathComponent("sizes.png"))

try! """
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "AppIcon-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "AppIcon-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

""".write(to: iconset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote AppIcon{,-dark,-tinted}.png to \(iconset.path); previews in \(previews.path)")
