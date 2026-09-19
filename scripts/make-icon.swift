import AppKit
import Foundation

// Rebuild the asset catalog from the checked-in master; no network or AI call.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("packaging/icon-master.png")
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
guard let master = NSImage(contentsOf: source) else { fatalError("Missing icon master: \(source.path)") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                    from: .zero, operation: .copy, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
