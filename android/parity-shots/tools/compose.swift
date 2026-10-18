// Side-by-side parity composites: iOS left, Android right, both scaled to the
// same height, each labelled, with a small caption. macOS only (AppKit), no packages.
//
//   swift compose.swift <ios.png> <android.png> <out.png> "<caption>"
//   swift compose.swift --all <ios dir> <android dir> <out dir>   every name found in both
import AppKit

let height: CGFloat = 1400
let gap: CGFloat = 40, margin: CGFloat = 40, labelBand: CGFloat = 70, captionBand: CGFloat = 60

func image(_ path: String) -> CGImage? {
    guard let ns = NSImage(contentsOfFile: path) else { return nil }
    var rect = CGRect(origin: .zero, size: ns.size)
    return ns.cgImage(forProposedRect: &rect, context: nil, hints: nil)
}

func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, in width: CGFloat) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ]
    NSAttributedString(string: text, attributes: attributes)
        .draw(in: CGRect(x: point.x, y: point.y, width: width, height: size * 1.4))
}

func compose(ios iosPath: String, android androidPath: String, out: String, caption: String) -> Bool {
    guard let left = image(iosPath), let right = image(androidPath) else {
        FileHandle.standardError.write("missing image for \(out)\n".data(using: .utf8)!); return false
    }
    let lw = height * CGFloat(left.width) / CGFloat(left.height)
    let rw = height * CGFloat(right.width) / CGFloat(right.height)
    let width = margin * 2 + lw + gap + rw
    let total = labelBand + height + captionBand + margin
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(total), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: total))
    ctx.interpolationQuality = .high
    // AppKit's origin is bottom-left: the caption band at the bottom, the labels at the top.
    let imageY = captionBand + margin / 2
    ctx.draw(left, in: CGRect(x: margin, y: imageY, width: lw, height: height))
    ctx.draw(right, in: CGRect(x: margin + lw + gap, y: imageY, width: rw, height: height))
    let labelY = imageY + height + 14
    draw("iOS", at: CGPoint(x: margin, y: labelY), size: 34, weight: .semibold, color: .black, in: lw)
    draw("Android", at: CGPoint(x: margin + lw + gap, y: labelY), size: 34, weight: .semibold, color: .black, in: rw)
    draw(caption, at: CGPoint(x: margin, y: 14), size: 24, weight: .regular, color: NSColor(white: 0.3, alpha: 1), in: width - margin * 2)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    return (try? data.write(to: URL(fileURLWithPath: out))) != nil
}

let args = CommandLine.arguments.dropFirst()
if args.first == "--all", args.count == 4 {
    let a = Array(args)
    let (iosDir, androidDir, outDir) = (a[1], a[2], a[3])
    let names = ((try? FileManager.default.contentsOfDirectory(atPath: androidDir)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
    for name in names where FileManager.default.fileExists(atPath: "\(iosDir)/\(name)") {
        let stem = String(name.dropLast(4))
        if compose(ios: "\(iosDir)/\(name)", android: "\(androidDir)/\(name)", out: "\(outDir)/\(name)",
                   caption: "\(stem) · iOS (iPhone 17 Pro sim) left, Android (Pixel 8 emulator) right") {
            print("\(name) ok")
        }
    }
} else if args.count == 4 {
    let a = Array(args)
    exit(compose(ios: a[0], android: a[1], out: a[2], caption: a[3]) ? 0 : 1)
} else {
    print("usage: swift compose.swift <ios.png> <android.png> <out.png> <caption> | --all <ios dir> <android dir> <out dir>")
    exit(2)
}
