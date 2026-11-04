import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216)
NSGradient(starting: NSColor(srgbRed: 0.03, green: 0.20, blue: 0.28, alpha: 1),
    ending: NSColor(srgbRed: 0.03, green: 0.65, blue: 0.68, alpha: 1))!.draw(in: background, angle: 50)
NSColor.white.withAlphaComponent(0.22).setFill()
NSBezierPath(roundedRect: NSRect(x: 185, y: 190, width: 630, height: 565), xRadius: 60, yRadius: 60).fill()
let page = NSBezierPath()
page.move(to: NSPoint(x: 245, y: 290))
page.line(to: NSPoint(x: 245, y: 800))
page.curve(to: NSPoint(x: 285, y: 840), controlPoint1: NSPoint(x: 245, y: 825), controlPoint2: NSPoint(x: 260, y: 840))
page.line(to: NSPoint(x: 810, y: 840))
page.line(to: NSPoint(x: 810, y: 540))
page.curve(to: NSPoint(x: 555, y: 290), controlPoint1: NSPoint(x: 720, y: 560), controlPoint2: NSPoint(x: 575, y: 480))
page.close()
NSColor(srgbRed: 0.95, green: 0.99, blue: 1, alpha: 1).setFill()
page.fill()
let fold = NSBezierPath()
fold.move(to: NSPoint(x: 555, y: 290))
fold.curve(to: NSPoint(x: 810, y: 540), controlPoint1: NSPoint(x: 690, y: 340), controlPoint2: NSPoint(x: 770, y: 440))
fold.curve(to: NSPoint(x: 555, y: 290), controlPoint1: NSPoint(x: 650, y: 615), controlPoint2: NSPoint(x: 520, y: 480))
NSColor(srgbRed: 0.56, green: 0.87, blue: 0.87, alpha: 1).setFill()
fold.fill()
NSColor(srgbRed: 0.14, green: 0.5, blue: 0.55, alpha: 0.55).setFill()
for x in [290, 326, 362] { NSBezierPath(ovalIn: NSRect(x: x, y: 775, width: 18, height: 18)).fill() }
image.unlockFocus()
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)@\(scale)x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let manifest: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: destination.appendingPathComponent("Contents.json"))
