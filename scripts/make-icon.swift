#!/usr/bin/env swift
// Renders every raster the app and the site show an icon in, from the SVG sources in
// Design/Icon/ (the design handoff of 3 Sep 2026). Nothing here is drawn by hand; edit the
// SVGs and run `make icon`.
//
//   swift scripts/make-icon.swift            # from the repository root
//
// Outputs: AppIcon.appiconset (10 PNGs; 16 and 32 px from the small master, the rest from
// the 1024 master), docs/icon.png (256), site/app/apple-icon.png (180), site/public/og.png
// (1200×630, the icon and the wordmark on the dark card).
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let sources = root.appendingPathComponent("Design/Icon")
let appIconSet = root.appendingPathComponent("AgentBar/Resources/Assets.xcassets/AppIcon.appiconset")
let site = root.appendingPathComponent("site")

func load(_ name: String) -> NSImage {
    guard let image = NSImage(contentsOf: sources.appendingPathComponent(name)) else {
        fputs("cannot load \(name)\n", stderr); exit(1)
    }
    return image
}

/// Rasterizes `image` into a square PNG of exactly `pixels`, alpha kept (the shadow lives in it).
func png(from image: NSImage, width: Int, height: Int, draw: ((CGContext) -> Void)? = nil) -> Data {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    if let draw {
        draw(context.cgContext)
    } else {
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height), from: .zero, operation: .copy, fraction: 1)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(url.path.replacingOccurrences(of: root.path + "/", with: ""))")
}

let master = load("appicon-1024.svg")
let small = load("appicon-small.svg")
let favicon = load("favicon.svg")

// MARK: App icon set

let slots: [(String, Int, Int)] = [
    ("16x16", 1, 16), ("16x16", 2, 32), ("32x32", 1, 32), ("32x32", 2, 64), ("128x128", 1, 128),
    ("128x128", 2, 256), ("256x256", 1, 256), ("256x256", 2, 512), ("512x512", 1, 512), ("512x512", 2, 1024),
]
var images: [[String: String]] = []
for (size, scale, pixels) in slots {
    let name = "icon_\(size)@\(scale)x.png"
    // The small master has no shadow or sheen and thicker strokes: it stays crisp at 16 and 32.
    let source = pixels <= 32 ? small : master
    write(png(from: source, width: pixels, height: pixels), to: appIconSet.appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": size])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
write(try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]),
      to: appIconSet.appendingPathComponent("Contents.json"))

// MARK: README and site

write(png(from: master, width: 256, height: 256), to: root.appendingPathComponent("docs/icon.png"))

if FileManager.default.fileExists(atPath: site.path) {
    write(png(from: favicon, width: 180, height: 180), to: site.appendingPathComponent("app/apple-icon.png"))

    // The OG card: the icon on the left, the wordmark and tagline on the right.
    let tagline: String = {
        guard let text = try? String(contentsOf: site.appendingPathComponent("app/site.ts"), encoding: .utf8),
              let range = text.range(of: "tagline:\\s*\"([^\"]*)\"", options: .regularExpression) else {
            return "What the coding agents on this Mac are doing, and how much of their quota is left."
        }
        let match = String(text[range])
        return String(match[match.index(after: match.firstIndex(of: "\"")!)..<match.index(before: match.endIndex)])
    }()
    let card = png(from: master, width: 1200, height: 630) { context in
        NSColor(srgbRed: 0x15 / 255, green: 0x16 / 255, blue: 0x1A / 255, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1200, height: 630).fill()
        master.draw(in: NSRect(x: 96, y: (630 - 400) / 2, width: 400, height: 400), from: .zero, operation: .sourceOver, fraction: 1)

        let ink = NSColor(srgbRed: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF4 / 255, alpha: 1)
        let green = NSColor(srgbRed: 0x3B / 255, green: 0xC2 / 255, blue: 0x8A / 255, alpha: 1)
        let column = NSRect(x: 560, y: 0, width: 560, height: 630)
        let name = NSAttributedString(string: "AgentBar", attributes: [
            .font: NSFont.systemFont(ofSize: 88, weight: .semibold), .foregroundColor: ink, .kern: -1.76,
        ])
        let paragraph = NSMutableParagraphStyle(); paragraph.lineHeightMultiple = 1.15
        let line = NSAttributedString(string: tagline, attributes: [
            .font: NSFont.systemFont(ofSize: 34), .foregroundColor: ink.withAlphaComponent(0.62), .paragraphStyle: paragraph,
        ])
        let host = NSAttributedString(string: "agentbar.greatpixels.com", attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .medium), .foregroundColor: green,
        ])
        let taglineHeight = line.boundingRect(with: NSSize(width: column.width, height: 400), options: [.usesLineFragmentOrigin]).height
        let total = 100 + 18 + taglineHeight + 28 + 32
        var y = (630 + total) / 2
        y -= 100; name.draw(at: NSPoint(x: column.minX, y: y))
        y -= 18 + taglineHeight; line.draw(with: NSRect(x: column.minX, y: y, width: column.width, height: taglineHeight), options: [.usesLineFragmentOrigin])
        y -= 28 + 32; host.draw(at: NSPoint(x: column.minX, y: y))
    }
    write(card, to: site.appendingPathComponent("public/og.png"))
}
