// Draws the Advent Praise mark (gold ring around a Didone "AP", as on the app
// icon) as vector PDFs for the launch screen and the in-app splash.
//
// Usage: xcrun swift Tools/make_splash_logo.swift AdventPraise/Resources/Assets.xcassets
//
// Writes, all on the same 160 × 160 pt canvas so the layers line up exactly:
//   SplashRing.imageset/SplashRing.pdf          template: the ring
//   SplashMonogram.imageset/SplashMonogram.pdf  template: "AP" as glyph outlines
//   LaunchLogo.imageset/LaunchLogo{,-dark}.pdf  coloured, for UILaunchScreen
//   LaunchBackground.colorset                   the launch ground
//
// Colours are the DS tokens (DesignTokens.swift); keep them in step with
// SplashView.Palette and LaunchBackground.colorset.

import CoreGraphics
import CoreText
import Foundation

let canvas: CGFloat = 160
let ringWidth: CGFloat = 5
let capHeight: CGFloat = 46

struct RGB { let r, g, b: CGFloat; init(_ hex: UInt32) {
    r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255 }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    var components: String {
        String(format: "\"alpha\" : \"1.000\", \"blue\" : \"%.3f\", \"green\" : \"%.3f\", \"red\" : \"%.3f\"", b, g, r)
    }
}

let brassOnDark = RGB(0xD4A853)
let paper = RGB(0xF7F4EE)
let evergreenOnDark = RGB(0x5FB8A6)
let evergreen = RGB(0x1F7466)
let stage = RGB(0x0E1110)

func ringPath() -> CGPath {
    let inset = ringWidth / 2
    return CGPath(ellipseIn: CGRect(x: inset, y: inset, width: canvas - ringWidth, height: canvas - ringWidth),
                  transform: nil)
}

/// "AP" in Didot Bold, A and P overlapping a little at the stems like the icon.
func monogramPath() -> CGPath {
    let font = CTFontCreateWithName("Didot-Bold" as CFString, 100, nil)
    let scale = capHeight / CTFontGetCapHeight(font)
    var chars: [UniChar] = Array("AP".utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count) else { fatalError("Didot-Bold missing A/P") }
    var advances = [CGSize](repeating: .zero, count: glyphs.count)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)

    let path = CGMutablePath()
    var x: CGFloat = 0
    let kern: CGFloat = -9 // in 100-pt font units
    for (index, glyph) in glyphs.enumerated() {
        if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
            path.addPath(outline, transform: CGAffineTransform(translationX: x, y: 0))
        }
        x += advances[index].width + kern
    }
    // Centre the ink on the canvas.
    let box = path.boundingBoxOfPath
    var transform = CGAffineTransform(translationX: canvas / 2, y: canvas / 2)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -box.midX, y: -box.midY)
    return path.copy(using: &transform)!
}

func writePDF(_ url: URL, draw: (CGContext) -> Void) {
    var box = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { fatalError("can't write \(url.path)") }
    context.beginPDFPage(nil)
    draw(context)
    context.endPDFPage()
    context.closePDF()
}

func drawRing(_ c: CGContext, _ color: CGColor) {
    c.addPath(ringPath()); c.setStrokeColor(color); c.setLineWidth(ringWidth); c.strokePath()
}

func drawMonogram(_ c: CGContext, _ color: CGColor) {
    c.addPath(monogramPath()); c.setFillColor(color); c.fillPath()
}

func writeContents(_ dir: URL, _ json: String) {
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

let catalog = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AdventPraise/Resources/Assets.xcassets")
let black = CGColor(gray: 0, alpha: 1)

for (name, draw) in [("SplashRing", { drawRing($0, black) }), ("SplashMonogram", { drawMonogram($0, black) })]
    as [(String, (CGContext) -> Void)] {
    let dir = catalog.appendingPathComponent("\(name).imageset")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    writePDF(dir.appendingPathComponent("\(name).pdf"), draw: draw)
    writeContents(dir, """
    {
      "images" : [ { "filename" : "\(name).pdf", "idiom" : "universal" } ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "template" }
    }

    """)
}

let launch = catalog.appendingPathComponent("LaunchLogo.imageset")
try! FileManager.default.createDirectory(at: launch, withIntermediateDirectories: true)
// Light: gold ring, paper letters on evergreen (the app icon). Dark: gold ring,
// evergreen letters on the Stage.
writePDF(launch.appendingPathComponent("LaunchLogo.pdf")) { drawRing($0, brassOnDark.cg); drawMonogram($0, paper.cg) }
writePDF(launch.appendingPathComponent("LaunchLogo-dark.pdf")) { drawRing($0, brassOnDark.cg); drawMonogram($0, evergreenOnDark.cg) }
writeContents(launch, """
{
  "images" : [
    { "filename" : "LaunchLogo.pdf", "idiom" : "universal" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "LaunchLogo-dark.pdf", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "original" }
}

""")
let background = catalog.appendingPathComponent("LaunchBackground.colorset")
try! FileManager.default.createDirectory(at: background, withIntermediateDirectories: true)
writeContents(background, """
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" : { \(evergreen.components) } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { \(stage.components) } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""")
print("wrote SplashRing, SplashMonogram, LaunchLogo, LaunchBackground to \(catalog.path)")
