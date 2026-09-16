import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels), flipped: false) { rect in
            let factor = CGFloat(pixels) / 1024
            let context = NSGraphicsContext.current!.cgContext
            context.scaleBy(x: factor, y: factor)
            NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.17, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196).fill()
            NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.89, alpha: 1).setFill()
            for (y, width) in [(660.0, 520.0), (500.0, 520.0), (340.0, 340.0)] {
                NSBezierPath(roundedRect: NSRect(x: 222, y: y, width: width, height: 50), xRadius: 25, yRadius: 25).fill()
            }
            NSColor(calibratedRed: 0.32, green: 0.77, blue: 0.73, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 620, y: 291, width: 45, height: 150), xRadius: 10, yRadius: 10).fill()
            return true
        }
        let data = image.tiffRepresentation!
        let png = NSBitmapImageRep(data: data)!.representation(using: .png, properties: [:])!
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try png.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
