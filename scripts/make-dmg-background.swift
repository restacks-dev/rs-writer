import AppKit
import Foundation

// Finder coordinates: app (180,230), Applications (540,230).
// Export 720x360 pixels / points for deterministic Finder background sizing.
let width = 720, height = 360, scale = 1
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale,
    pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext
ctx.translateBy(x: 0, y: CGFloat(height))
ctx.scaleBy(x: 1, y: -1)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
let ink = color(0.067, 0.067, 0.06), cream = color(1.0, 0.992, 0.95)
let accent = color(0.81, 0.41, 0.30), muted = color(0.40, 0.36, 0.33)
NSGradient(starting: cream, ending: color(0.97,0.93,0.86))!.draw(in: NSRect(x:0,y:0,width:width,height:height), angle:90)
// Fine stationery rules, with generous space for the real Finder items.
ctx.setStrokeColor(color(0.65,0.32,0.22,0.045).cgColor)
ctx.setLineWidth(0.5)
for y in stride(from: 15, through: height, by: 16) {
    ctx.move(to: CGPoint(x:0,y:y)); ctx.addLine(to: CGPoint(x:width,y:y)); ctx.strokePath()
}
func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ font: NSFont, _ tint: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font:font,.foregroundColor:tint]
    let str = NSAttributedString(string:value, attributes:attrs)
    ctx.saveGState()
    ctx.translateBy(x:x,y:y + str.size().height)
    ctx.scaleBy(x:1,y:-1)
    str.draw(at:.zero)
    ctx.restoreGState()
}
text("RS Writer",48,35,NSFont(name:"Georgia",size:43)!,ink)
for x in [94,454] {
    color(1,1,0.99,0.82).setFill()
    NSBezierPath(roundedRect:NSRect(x:x,y:158,width:172,height:156),xRadius:22,yRadius:22).fill()
}
ctx.setStrokeColor(accent.cgColor)
ctx.setLineWidth(2.5); ctx.setLineCap(.round);ctx.setLineJoin(.round)
ctx.move(to:CGPoint(x:315,y:230));ctx.addLine(to:CGPoint(x:405,y:230))
ctx.move(to:CGPoint(x:392,y:217));ctx.addLine(to:CGPoint(x:405,y:230));ctx.addLine(to:CGPoint(x:392,y:243));ctx.strokePath()
text("SLEEP",338,251,NSFont.monospacedSystemFont(ofSize:10,weight:.medium),accent)
NSGraphicsContext.restoreGraphicsState()
let output = CommandLine.arguments.dropFirst().first ?? "packaging/dmg-background.png"
try FileManager.default.createDirectory(atPath:(output as NSString).deletingLastPathComponent,withIntermediateDirectories:true)
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
