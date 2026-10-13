// Draws the Seventh-day Adventist church logo (Tools/source/sda-logo.svg, traced
// by Tools/trace_sda_logo.swift) for the launch screen and the in-app splash,
// with the app icon's gold-to-green gradient.
//
// Usage: xcrun swift Tools/make_splash_logo.swift [Assets.xcassets] [Swift out]
//   defaults: AdventPraise/Resources/Assets.xcassets  AdventPraise/App/SDALogoShape.swift
//
// The mark is `width` pt wide and as tall as the logo's ink needs; both outputs
// use that same box so the launch frame and the splash's first frame line up:
//   LaunchLogo.imageset/LaunchLogo.pdf   coloured vector, for UILaunchScreen
//   LaunchBackground.colorset            the launch ground
//   SDALogoShape.swift                   the outline as a SwiftUI Shape, plus the
//                                        point the splash zooms into
//
// Colours are the DS tokens (DesignTokens.swift); keep them in step with
// SplashView.Palette and Tools/make_app_icon.swift.

import CoreGraphics
import Foundation

let width: CGFloat = 160
/// As on the icon: pure green to 15 % of the diagonal, pure gold from 85 %.
let gradientStops: [CGFloat] = [0.15, 0.85]

struct RGB { let r, g, b: CGFloat; init(_ hex: UInt32) {
    r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255 }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    var components: String {
        String(format: "\"alpha\" : \"1.000\", \"blue\" : \"%.3f\", \"green\" : \"%.3f\", \"red\" : \"%.3f\"", b, g, r)
    }
}

let brassOnDark = RGB(0xD4A853)
let evergreenOnDark = RGB(0x5FB8A6)
let evergreen = RGB(0x1F7466)
let stage = RGB(0x0E1110)

// MARK: The traced outline

enum Segment { case move(CGPoint), line(CGPoint), curve(CGPoint, CGPoint, CGPoint), close }

/// The `d` of the traced SVG (absolute M, L, C, Z only, as the tracer writes it).
func svgSegments() -> [Segment] {
    let svg = try! String(contentsOf: URL(fileURLWithPath: "Tools/source/sda-logo.svg"), encoding: .utf8)
    guard let start = svg.range(of: " d=\"")?.upperBound,
          let end = svg[start...].firstIndex(of: "\"") else { fatalError("no path in sda-logo.svg") }
    var segments: [Segment] = []
    let scanner = Scanner(string: String(svg[start..<end]))
    func point() -> CGPoint { CGPoint(x: scanner.scanDouble()!, y: scanner.scanDouble()!) }
    while let command = scanner.scanCharacter() {
        switch command {
        case "M": segments.append(.move(point()))
        case "L": segments.append(.line(point()))
        case "C": segments.append(.curve(point(), point(), point()))
        case "Z": segments.append(.close)
        case _ where command.isWhitespace: continue
        default: fatalError("unexpected SVG command \(command)")
        }
    }
    return segments
}

func path(_ segments: [Segment]) -> CGPath {
    let path = CGMutablePath()
    for segment in segments {
        switch segment {
        case .move(let p): path.move(to: p)
        case .line(let p): path.addLine(to: p)
        case .curve(let c1, let c2, let p): path.addCurve(to: p, control1: c1, control2: c2)
        case .close: path.closeSubpath()
        }
    }
    return path
}

/// The outline in unit coordinates of its own ink box (0…1 both ways, y down).
let unitSegments: [Segment] = {
    let raw = svgSegments(), box = path(raw).boundingBoxOfPath
    func unit(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - box.minX) / box.width, y: (p.y - box.minY) / box.height) }
    return raw.map {
        switch $0 {
        case .move(let p): .move(unit(p))
        case .line(let p): .line(unit(p))
        case .curve(let c1, let c2, let p): .curve(unit(c1), unit(c2), unit(p))
        case .close: .close
        }
    }
}()
let aspect: CGFloat = { let box = path(svgSegments()).boundingBoxOfPath; return box.width / box.height }()
let height = width / aspect

/// The outline in a `size` box, y up (for drawing with CoreGraphics).
func logo(in size: CGSize) -> CGPath {
    var transform = CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: size.width, y: -size.height)
    return path(unitSegments).copy(using: &transform)!
}

// MARK: The point the splash zooms into

/// The centre and radius of the largest disc inside the ink (chamfer distance
/// transform at 4 px per pt), in unit coordinates and fractions of the width.
/// Zooming the mark about this point, the disc is the last thing to cover the
/// screen.
func largestDisc() -> (center: CGPoint, radius: CGFloat) {
    let w = Int(width * 4), h = Int(height * 4)
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    c.setFillColor(gray: 0, alpha: 1); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
    c.addPath(logo(in: CGSize(width: w, height: h))); c.setFillColor(gray: 1, alpha: 1); c.fillPath(using: .evenOdd)
    let ink = c.data!.bindMemory(to: UInt8.self, capacity: w * h) // row 0 is the top
    let far = Int.max / 4
    var d = (0..<(w * h)).map { ink[$0] >= 128 ? far : 0 }
    for y in 0..<h { for x in 0..<w where d[y * w + x] > 0 {
        var v = d[y * w + x]
        if x > 0 { v = min(v, d[y * w + x - 1] + 3) } else { v = 3 }
        if y > 0 { v = min(v, d[(y - 1) * w + x] + 3); if x > 0 { v = min(v, d[(y - 1) * w + x - 1] + 4) }
            if x < w - 1 { v = min(v, d[(y - 1) * w + x + 1] + 4) } } else { v = min(v, 3) }
        d[y * w + x] = v
    } }
    for y in stride(from: h - 1, through: 0, by: -1) { for x in stride(from: w - 1, through: 0, by: -1) where d[y * w + x] > 0 {
        var v = d[y * w + x]
        if x < w - 1 { v = min(v, d[y * w + x + 1] + 3) } else { v = min(v, 3) }
        if y < h - 1 { v = min(v, d[(y + 1) * w + x] + 3); if x < w - 1 { v = min(v, d[(y + 1) * w + x + 1] + 4) }
            if x > 0 { v = min(v, d[(y + 1) * w + x - 1] + 4) } } else { v = min(v, 3) }
        d[y * w + x] = v
    } }
    let best = d.indices.max { d[$0] < d[$1] }!
    // Chamfer 3-4 overestimates by up to ~8 %; keep the radius on the safe side.
    let radius = CGFloat(d[best]) / 3 / 1.08
    return (CGPoint(x: (CGFloat(best % w) + 0.5) / CGFloat(w), y: (CGFloat(best / w) + 0.5) / CGFloat(h)),
            radius / CGFloat(w))
}

// MARK: Writing

func writePDF(_ url: URL, draw: (CGContext) -> Void) {
    var box = CGRect(x: 0, y: 0, width: width, height: height)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { fatalError("can't write \(url.path)") }
    context.beginPDFPage(nil)
    draw(context)
    context.endPDFPage()
    context.closePDF()
}

/// The logo filled even-odd (the cross and the gaps between flame strokes are
/// holes) with the gradient from the box's bottom-left to its top-right.
func drawLogo(_ c: CGContext, green: RGB, gold: RGB) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: space, colors: [green.cg, gold.cg] as CFArray, locations: gradientStops)!
    c.addPath(logo(in: CGSize(width: width, height: height))); c.clip(using: .evenOdd)
    c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func writeContents(_ dir: URL, _ json: String) {
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func f(_ v: CGFloat) -> String { String(format: "%.4f", v) }

func swiftSource(disc: (center: CGPoint, radius: CGFloat)) -> String {
    func p(_ q: CGPoint) -> String { "p(\(f(q.x)), \(f(q.y)))" }
    var body = ""
    for segment in unitSegments {
        switch segment {
        case .move(let q): body += "        path.move(to: \(p(q)))\n"
        case .line(let q): body += "        path.addLine(to: \(p(q)))\n"
        case .curve(let c1, let c2, let q): body += "        path.addCurve(to: \(p(q)), control1: \(p(c1)), control2: \(p(c2)))\n"
        case .close: body += "        path.closeSubpath()\n"
        }
    }
    return """
    //
    //  SDALogoShape.swift
    //  Advent Praise
    //
    //  Generated by Tools/make_splash_logo.swift from Tools/source/sda-logo.svg
    //  (the Seventh-day Adventist church logo, traced from the 6.3 App Store
    //  icon). Don't edit by hand; run the script again.
    //

    import SwiftUI

    /// The church logo's outline, stretched to fill its rect. Fill it even-odd:
    /// the cross and the gaps between the flame strokes are holes.
    struct SDALogoShape: Shape {
        /// Width over height of the logo's ink.
        static let aspectRatio: CGFloat = \(f(aspect))
        /// Centre of the largest disc inside the ink, for zooming into the mark.
        static let revealAnchor = UnitPoint(x: \(f(disc.center.x)), y: \(f(disc.center.y)))
        /// That disc's radius, as a fraction of the logo's width.
        static let revealRadius: CGFloat = \(f(disc.radius))

        func path(in rect: CGRect) -> Path {
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            var path = Path()
    \(body.dropLast())
            return path
        }
    }

    """
}

let args = CommandLine.arguments.dropFirst()
let catalog = URL(fileURLWithPath: args.first ?? "AdventPraise/Resources/Assets.xcassets")
let swiftURL = URL(fileURLWithPath: args.dropFirst().first ?? "AdventPraise/App/SDALogoShape.swift")

// Light and dark grounds differ; on both the logo runs evergreenOnDark to brassOnDark.
let launch = catalog.appendingPathComponent("LaunchLogo.imageset")
try? FileManager.default.removeItem(at: launch)
try! FileManager.default.createDirectory(at: launch, withIntermediateDirectories: true)
writePDF(launch.appendingPathComponent("LaunchLogo.pdf")) { drawLogo($0, green: evergreenOnDark, gold: brassOnDark) }
writeContents(launch, """
{
  "images" : [ { "filename" : "LaunchLogo.pdf", "idiom" : "universal" } ],
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
let disc = largestDisc()
try! swiftSource(disc: disc).write(to: swiftURL, atomically: true, encoding: .utf8)
print("logo \(width) × \(height) pt; zoom disc at \(disc.center), r = \(f(disc.radius * width)) pt")
print("wrote LaunchLogo, LaunchBackground to \(catalog.path); \(swiftURL.path)")
