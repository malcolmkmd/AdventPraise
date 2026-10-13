// Draws the 1024 × 1024 app icon: the Advent Praise mark (gold ring around a
// Didone "AP", the same mark Tools/make_splash_logo.swift draws for the splash)
// above the wordmark "Advent Praise" in New York, the app's serif.
//
// Usage: xcrun swift Tools/make_app_icon.swift [Assets.xcassets] [preview dir]
//   defaults: AdventPraise/Resources/Assets.xcassets  build/shots/icon
//
// Writes AppIcon.appiconset with the iOS 18+ appearances:
//   AppIcon.png         light: evergreen ground, brass ring, paper letters (RGB, no alpha)
//   AppIcon-dark.png    dark: Stage ground, brass ring, evergreenOnDark letters
//   AppIcon-tinted.png  tinted: grayscale on black; the system tints by luminance
// and previews of each at 1024 and at the home screen / Settings sizes.
//
// Everything is drawn from vectors (glyph outlines and a stroked circle) at
// full size; nothing is upscaled. Colours are the DS tokens (DesignTokens.swift).

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024

// MARK: Layout (pt on the 1024 canvas, y down)

let ringDiameter: CGFloat = 352
let ringWidth: CGFloat = 22
let monogramCapHeight: CGFloat = 124
let wordmarkWidth: CGFloat = 700      // the wider of the two words
let ringToWordmark: CGFloat = 52
let lineGap: CGFloat = 30             // between the two words' ink
let opticalLift: CGFloat = 8          // sit the block a hair above centre

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

struct Palette { let ground, ring, monogram, wordmark: RGB }

let variants: [(file: String, palette: Palette)] = [
    ("AppIcon.png", Palette(ground: evergreen, ring: brassOnDark, monogram: paper, wordmark: paper)),
    ("AppIcon-dark.png", Palette(ground: stage, ring: brassOnDark, monogram: evergreenOnDark, wordmark: blackInk)),
    // Tinted: luminance becomes tint strength. Letters full, ring a step back.
    ("AppIcon-tinted.png", Palette(ground: RGB(gray: 0), ring: RGB(gray: 0.78), monogram: RGB(gray: 1), wordmark: RGB(gray: 1))),
]

// MARK: Shapes

/// Glyph outlines of `text` in `font`, with the font's own kerning, y up.
func outline(_ text: String, _ font: CTFont, tracking: CGFloat = 0) -> CGPath {
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
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

/// Moves and scales `path` so its ink box has `scale` and its centre lands on `center`.
func place(_ path: CGPath, scale: CGFloat, center: CGPoint) -> CGPath {
    let box = path.boundingBoxOfPath
    var transform = CGAffineTransform(translationX: center.x, y: center.y)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -box.midX, y: -box.midY)
    return path.copy(using: &transform)!
}

/// "AP" in Didot Bold, stems overlapping a little, exactly as on the splash.
func monogram() -> CGPath {
    let font = CTFontCreateWithName("Didot-Bold" as CFString, 100, nil)
    precondition(CTFontCopyPostScriptName(font) as String == "Didot-Bold", "Didot-Bold missing")
    let path = outline("AP", font, tracking: -9)
    return place(path, scale: monogramCapHeight / CTFontGetCapHeight(font), center: .zero)
}

/// New York (SwiftUI's `.serif` design), semibold, at a display size so the
/// optical-size axis picks the display cut.
func newYork() -> CTFont {
    let system = NSFont.systemFont(ofSize: 200, weight: .semibold)
    guard let descriptor = system.fontDescriptor.withDesign(.serif),
          let font = NSFont(descriptor: descriptor, size: 200) else { fatalError("New York unavailable") }
    return font as CTFont
}

struct Artwork { let ring: CGPath; let monogram: CGPath; let wordmark: CGPath }

/// Canvas in CG coordinates (y up). The block — ring, gap, two words — is
/// centred vertically.
func artwork() -> Artwork {
    let font = newYork()
    let advent = outline("Advent", font), praise = outline("Praise", font)
    let scale = wordmarkWidth / max(advent.boundingBoxOfPath.width, praise.boundingBoxOfPath.width)
    let adventHeight = advent.boundingBoxOfPath.height * scale
    let praiseHeight = praise.boundingBoxOfPath.height * scale

    let blockHeight = ringDiameter + ringToWordmark + adventHeight + lineGap + praiseHeight
    let top = size / 2 + blockHeight / 2 + opticalLift
    let ringCenter = CGPoint(x: size / 2, y: top - ringDiameter / 2)
    let adventCenterY = top - ringDiameter - ringToWordmark - adventHeight / 2
    let praiseCenterY = adventCenterY - adventHeight / 2 - lineGap - praiseHeight / 2

    let inner = ringDiameter - ringWidth
    let ring = CGPath(ellipseIn: CGRect(x: ringCenter.x - inner / 2, y: ringCenter.y - inner / 2,
                                        width: inner, height: inner), transform: nil)
    var shift = CGAffineTransform(translationX: ringCenter.x, y: ringCenter.y)
    let wordmark = CGMutablePath()
    wordmark.addPath(place(advent, scale: scale, center: CGPoint(x: size / 2, y: adventCenterY)))
    wordmark.addPath(place(praise, scale: scale, center: CGPoint(x: size / 2, y: praiseCenterY)))
    return Artwork(ring: ring, monogram: monogram().copy(using: &shift)!, wordmark: wordmark)
}

// MARK: Rendering

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func bitmap(_ pixels: Int, alpha: Bool) -> CGContext {
    CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
}

func render(_ art: Artwork, _ p: Palette) -> CGImage {
    let c = bitmap(Int(size), alpha: false)
    c.setFillColor(p.ground.cg); c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    c.addPath(art.ring); c.setStrokeColor(p.ring.cg); c.setLineWidth(ringWidth); c.strokePath()
    c.addPath(art.monogram); c.setFillColor(p.monogram.cg); c.fillPath()
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
let previews = URL(fileURLWithPath: args.dropFirst().first ?? "build/shots/icon")
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
