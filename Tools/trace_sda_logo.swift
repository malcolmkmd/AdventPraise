// Traces the Seventh-day Adventist church logo (flame over an open Bible with
// a cross) from the 6.3 App Store icon into a vector outline. The symbol is
// not redrawn or altered: every curve comes from the pixels.
//
// Usage: xcrun swift Tools/trace_sda_logo.swift [source png] [svg out] [preview dir]
//   defaults: Tools/source/sda-logo-6.3.png  Tools/source/sda-logo.svg  build/shots/icon2
//
// potrace isn't installed, so this does the same job in three steps:
//   1. Ink coverage from the 512 px source (the logo is a green-to-slate
//      gradient on white; the darkest channel-max is ink, white is ground).
//   2. Marching squares at the 50 % coverage level, so edges land at subpixel
//      positions from the antialiasing.
//   3. Corners (flame tips, page corners, the cross's right angles) are kept
//      sharp; the runs between them are fitted with cubic Béziers (Schneider's
//      algorithm) to within `tolerance` px.
// The cross and the gaps between flame strokes are holes, so the SVG fills
// even-odd. The script also rasterises the result and reports how many pixels
// differ from the source, with a difference image in the preview dir.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let tolerance = 0.45          // max fit error, source px
let cornerSpan = 4            // samples either side when measuring the turn
let cornerAngle = 50.0        // degrees of turn over the span that make a corner
let minLoopArea = 6.0         // px²; drops antialiasing specks

// MARK: Source

let args = CommandLine.arguments.dropFirst()
let sourceURL = URL(fileURLWithPath: args.first ?? "Tools/source/sda-logo-6.3.png")
let svgURL = URL(fileURLWithPath: args.dropFirst().first ?? "Tools/source/sda-logo.svg")
let previews = URL(fileURLWithPath: args.dropFirst(2).first ?? "build/shots/icon2")
try! FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
guard let src = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("can't read \(sourceURL.path)") }
let W = image.width, H = image.height

func rgba(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let c = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

let pixels = rgba(image, width: W, height: H)
// Ink coverage 0…1: white ground is 0, the logo's body (channel max ≈ 0.5–0.6) is 1.
let inkLevel = 0.56
var coverage = [Double](repeating: 0, count: (W + 2) * (H + 2)) // one px of white padding
let GW = W + 2, GH = H + 2
for y in 0..<H {
    for x in 0..<W {
        let i = (y * W + x) * 4
        let v = Double(max(pixels[i], pixels[i + 1], pixels[i + 2])) / 255
        coverage[(y + 1) * GW + x + 1] = min(1, max(0, (1 - v) / (1 - inkLevel)))
    }
}

// MARK: Marching squares (image coords, y down; grid point (gx, gy) is pixel centre (gx - 0.5, gy - 0.5))

let level = 0.5
@inline(__always) func value(_ x: Int, _ y: Int) -> Double { coverage[y * GW + x] }

/// Edge ids: 2 * (y * GW + x) for the horizontal edge from (x, y), +1 for the vertical one.
func point(onEdge id: Int) -> SIMD2<Double> {
    let base = id / 2, x = base % GW, y = base / GW
    let a = value(x, y)
    if id % 2 == 0 {
        let b = value(x + 1, y), t = (level - a) / (b - a)
        return SIMD2(Double(x) + t - 0.5, Double(y) - 0.5)
    } else {
        let b = value(x, y + 1), t = (level - a) / (b - a)
        return SIMD2(Double(x) - 0.5, Double(y) + t - 0.5)
    }
}

var links: [Int: [Int]] = [:]
func link(_ a: Int, _ b: Int) { links[a, default: []].append(b); links[b, default: []].append(a) }

for y in 0..<(GH - 1) {
    for x in 0..<(GW - 1) {
        let tl = value(x, y) >= level, tr = value(x + 1, y) >= level
        let br = value(x + 1, y + 1) >= level, bl = value(x, y + 1) >= level
        let top = 2 * (y * GW + x), bottom = 2 * ((y + 1) * GW + x)
        let left = 2 * (y * GW + x) + 1, right = 2 * (y * GW + x + 1) + 1
        switch (tl, tr, br, bl) {
        case (false, false, false, false), (true, true, true, true): break
        case (true, false, false, false), (false, true, true, true): link(top, left)
        case (false, true, false, false), (true, false, true, true): link(top, right)
        case (false, false, true, false), (true, true, false, true): link(right, bottom)
        case (false, false, false, true), (true, true, true, false): link(left, bottom)
        case (true, true, false, false), (false, false, true, true): link(left, right)
        case (true, false, false, true), (false, true, true, false): link(top, bottom)
        case (true, false, true, false), (false, true, false, true):
            // Saddle: the centre decides whether the inked corners join.
            let centreInk = (value(x, y) + value(x + 1, y) + value(x + 1, y + 1) + value(x, y + 1)) / 4 >= level
            if tl == centreInk { link(top, right); link(left, bottom) } else { link(top, left); link(right, bottom) }
        }
    }
}

var loops: [[SIMD2<Double>]] = []
var visited = Set<Int>()
for start in links.keys.sorted() where !visited.contains(start) {
    var ids = [start]; visited.insert(start)
    var previous = start, current = links[start]![0]
    while current != start {
        ids.append(current); visited.insert(current)
        let next = links[current]!.first { $0 != previous } ?? links[current]![0]
        previous = current; current = next
    }
    var loop = ids.map(point(onEdge:))
    // Drop near-duplicates where the level passes through a grid point.
    loop = loop.enumerated().filter { i, p in distance(p, loop[(i + 1) % loop.count]) > 1e-3 }.map(\.element)
    loops.append(loop)
}

func area(_ loop: [SIMD2<Double>]) -> Double {
    var sum = 0.0
    for i in loop.indices { let a = loop[i], b = loop[(i + 1) % loop.count]; sum += a.x * b.y - b.x * a.y }
    return abs(sum) / 2
}
loops = loops.filter { area($0) >= minLoopArea }

// MARK: Bézier fitting

typealias P = SIMD2<Double>
struct Cubic { var p0, p1, p2, p3: P }

func distance(_ a: P, _ b: P) -> Double { ((a - b) * (a - b)).sum().squareRoot() }
func normalized(_ v: P) -> P { let l = (v * v).sum().squareRoot(); return l > 0 ? v / l : v }
func dot(_ a: P, _ b: P) -> Double { (a * b).sum() }

func bezier(_ c: Cubic, _ t: Double) -> P {
    let s = 1 - t
    return s * s * s * c.p0 + 3 * s * s * t * c.p1 + 3 * s * t * t * c.p2 + t * t * t * c.p3
}
func bezierD1(_ c: Cubic, _ t: Double) -> P {
    let s = 1 - t
    return 3 * s * s * (c.p1 - c.p0) + 6 * s * t * (c.p2 - c.p1) + 3 * t * t * (c.p3 - c.p2)
}
func bezierD2(_ c: Cubic, _ t: Double) -> P {
    6 * (1 - t) * (c.p2 - 2 * c.p1 + c.p0) + 6 * t * (c.p3 - 2 * c.p2 + c.p1)
}

func chordParameters(_ pts: ArraySlice<P>) -> [Double] {
    var u = [0.0]
    var previous = pts.first!
    for p in pts.dropFirst() { u.append(u.last! + distance(p, previous)); previous = p }
    let total = u.last!
    return u.map { total > 0 ? $0 / total : 0 }
}

func generate(_ pts: ArraySlice<P>, _ u: [Double], _ t1: P, _ t2: P) -> Cubic {
    let first = pts.first!, last = pts.last!
    var c00 = 0.0, c01 = 0.0, c11 = 0.0, x0 = 0.0, x1 = 0.0
    for (i, p) in pts.enumerated() {
        let t = u[i], s = 1 - t
        let a1 = t1 * (3 * s * s * t), a2 = t2 * (3 * s * t * t)
        c00 += dot(a1, a1); c01 += dot(a1, a2); c11 += dot(a2, a2)
        let tmp = p - (first * (s * s * s + 3 * s * s * t) + last * (3 * s * t * t + t * t * t))
        x0 += dot(a1, tmp); x1 += dot(a2, tmp)
    }
    let det = c00 * c11 - c01 * c01
    var alpha1 = det != 0 ? (x0 * c11 - x1 * c01) / det : 0
    var alpha2 = det != 0 ? (c00 * x1 - c01 * x0) / det : 0
    let segment = distance(first, last), epsilon = 1e-6 * segment
    if alpha1 < epsilon || alpha2 < epsilon { alpha1 = segment / 3; alpha2 = segment / 3 }
    return Cubic(p0: first, p1: first + t1 * alpha1, p2: last + t2 * alpha2, p3: last)
}

func maxError(_ pts: ArraySlice<P>, _ c: Cubic, _ u: [Double]) -> (Double, Int) {
    var worst = 0.0, at = pts.count / 2
    for (i, p) in pts.enumerated() {
        let d = distance(bezier(c, u[i]), p)
        if d > worst { worst = d; at = i }
    }
    return (worst, at)
}

func reparameterize(_ pts: ArraySlice<P>, _ u: [Double], _ c: Cubic) -> [Double] {
    zip(pts, u).map { p, t in
        let d = bezier(c, t) - p, d1 = bezierD1(c, t), d2 = bezierD2(c, t)
        let denominator = dot(d1, d1) + dot(d, d2)
        return denominator == 0 ? t : min(1, max(0, t - dot(d, d1) / denominator))
    }
}

func fit(_ pts: ArraySlice<P>, _ t1: P, _ t2: P) -> [Cubic] {
    if pts.count == 2 {
        let d = distance(pts.first!, pts.last!) / 3
        return [Cubic(p0: pts.first!, p1: pts.first! + t1 * d, p2: pts.last! + t2 * d, p3: pts.last!)]
    }
    var u = chordParameters(pts)
    var curve = generate(pts, u, t1, t2)
    var (error, split) = maxError(pts, curve, u)
    if error < tolerance { return [curve] }
    if error < tolerance * 4 {
        for _ in 0..<6 {
            u = reparameterize(pts, u, curve)
            curve = generate(pts, u, t1, t2)
            (error, split) = maxError(pts, curve, u)
            if error < tolerance { return [curve] }
        }
    }
    split = min(max(split, 1), pts.count - 2)
    let index = pts.startIndex + split
    let centre = normalized(pts[index - 1] - pts[index + 1])
    return fit(pts[pts.startIndex...index], t1, centre) + fit(pts[index...], -centre, t2)
}

/// Turn in degrees at sample i, measured over `cornerSpan` samples either side.
func turn(_ loop: [P], _ i: Int) -> Double {
    let n = loop.count
    let a = normalized(loop[i] - loop[(i - cornerSpan + n) % n])
    let b = normalized(loop[(i + cornerSpan) % n] - loop[i])
    return acos(min(1, max(-1, dot(a, b)))) * 180 / .pi
}

/// Estimated tangent leaving loop[i] towards higher indices, from a few samples.
func tangent(_ loop: [P], from i: Int, step: Int) -> P {
    let n = loop.count
    var sum = P(0, 0)
    for k in 1...3 { sum += normalized(loop[((i + step * k) % n + n) % n] - loop[i]) }
    return normalized(sum)
}

func fitLoop(_ loop: [P]) -> [Cubic] {
    let n = loop.count
    let turns = (0..<n).map { turn(loop, $0) }
    var corners: [Int] = []
    for i in 0..<n where turns[i] >= cornerAngle {
        let window = (-cornerSpan...cornerSpan).map { turns[((i + $0) % n + n) % n] }
        if turns[i] == window.max()!, corners.last.map({ i - $0 > cornerSpan }) ?? true { corners.append(i) }
    }
    if corners.count >= 2, n - corners.last! + corners.first! <= cornerSpan { corners.removeLast() }

    if corners.isEmpty {
        // A smooth loop: split it in two at opposite points, tangents continuous.
        let half = n / 2
        let rotated = loop + [loop[0]]
        let tA = normalized(loop[1] - loop[n - 1]), tB = normalized(loop[half + 1] - loop[half - 1])
        return fit(rotated[0...half], tA, -tB) + fit(rotated[half...n], tB, -tA)
    }
    var curves: [Cubic] = []
    for (k, start) in corners.enumerated() {
        let end = k + 1 < corners.count ? corners[k + 1] : corners[0] + n
        let run = (start...end).map { loop[$0 % n] }
        curves += fit(run[...], tangent(loop, from: start, step: 1), tangent(loop, from: end % n, step: -1))
    }
    return curves
}

let fitted = loops.map(fitLoop)

// MARK: Output

func f(_ v: Double) -> String { String(format: "%.2f", v) }
var d = ""
for curves in fitted {
    d += "M\(f(curves[0].p0.x)) \(f(curves[0].p0.y))"
    for c in curves { d += "C\(f(c.p1.x)) \(f(c.p1.y)) \(f(c.p2.x)) \(f(c.p2.y)) \(f(c.p3.x)) \(f(c.p3.y))" }
    d += "Z\n"
}
let svg = """
<?xml version="1.0" encoding="UTF-8"?>
<!-- Seventh-day Adventist church logo, traced from Tools/source/sda-logo-6.3.png
     by Tools/trace_sda_logo.swift. \(fitted.count) loops, \(fitted.map(\.count).reduce(0, +)) cubic segments. -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(W) \(H)" width="\(W)" height="\(H)">
<path fill="#000" fill-rule="evenodd" d="
\(d)"/>
</svg>

"""
try! svg.write(to: svgURL, atomically: true, encoding: .utf8)

// MARK: Check against the source

let path = CGMutablePath()
for curves in fitted {
    path.move(to: CGPoint(x: curves[0].p0.x, y: curves[0].p0.y))
    for c in curves {
        path.addCurve(to: CGPoint(x: c.p3.x, y: c.p3.y), control1: CGPoint(x: c.p1.x, y: c.p1.y),
                      control2: CGPoint(x: c.p2.x, y: c.p2.y))
    }
    path.closeSubpath()
}

func rasterise(scale: Int) -> CGContext {
    let s = W * scale
    let c = CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: s * 4, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: s, height: s))
    // Flip to image coordinates.
    c.translateBy(x: 0, y: CGFloat(s)); c.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    return c
}

let check = rasterise(scale: 1)
check.addPath(path); check.setFillColor(CGColor(gray: 0, alpha: 1)); check.fillPath(using: .evenOdd)
let traced = rgba(check.makeImage()!, width: W, height: H)
var differing = 0, inked = 0
var diff = [UInt8](repeating: 255, count: W * H * 4)
for y in 0..<H {
    for x in 0..<W {
        let source = coverage[(y + 1) * GW + x + 1] >= level
        let vector = traced[(y * W + x) * 4] < 128
        if source { inked += 1 }
        let i = (y * W + x) * 4
        switch (source, vector) {
        case (true, true): diff[i] = 200; diff[i + 1] = 200; diff[i + 2] = 200
        case (true, false): diff[i] = 220; diff[i + 1] = 0; diff[i + 2] = 0; differing += 1     // missed: red
        case (false, true): diff[i] = 0; diff[i + 1] = 90; diff[i + 2] = 220; differing += 1    // extra: blue
        default: break
        }
    }
}

func writePNG(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("can't write \(url.path)") }
}

let diffImage = CGContext(data: &diff, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
writePNG(diffImage, previews.appendingPathComponent("trace-diff.png"))

// Outline over the source at 2×, to eyeball the fit.
let overlay = rasterise(scale: 2)
overlay.saveGState(); overlay.scaleBy(x: 1, y: -1); overlay.translateBy(x: 0, y: -CGFloat(H))
overlay.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H)); overlay.restoreGState()
overlay.addPath(path); overlay.setStrokeColor(CGColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1))
overlay.setLineWidth(0.5); overlay.strokePath()
writePNG(overlay.makeImage()!, previews.appendingPathComponent("trace-overlay.png"))

print("\(fitted.count) loops, \(fitted.map(\.count).reduce(0, +)) cubics → \(svgURL.path)")
print(String(format: "pixels differing from source at the 50%% level: %d of %d inked (%.2f%%)",
             differing, inked, 100 * Double(differing) / Double(inked)))
