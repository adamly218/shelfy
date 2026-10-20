// Draws Shelfy's app icon at 1024×1024 and writes it as a PNG.
// Usage: make-icon <output.png>   (see scripts/make-icon.sh for the .icns)
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func withShadow(blur: CGFloat, y: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// A rounded rectangle rotated around its center.
func card(center: NSPoint, size: NSSize, radius: CGFloat, angle: CGFloat) -> NSBezierPath {
    let path = NSBezierPath(roundedRect: NSRect(x: -size.width / 2, y: -size.height / 2,
                                                width: size.width, height: size.height),
                            xRadius: radius, yRadius: radius)
    var transform = AffineTransform(translationByX: center.x, byY: center.y)
    transform.rotate(byDegrees: angle)
    path.transform(using: transform)
    return path
}

// Background: Apple's icon grid puts the rounded square at 824pt with a 100pt margin.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
withShadow(blur: 28, y: -12, alpha: 0.3) {
    color(0x5B6BF2).setFill()
    tilePath.fill()
}
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(colors: [color(0x5468F5), color(0x8E5BE8), color(0xE0609E)])!.draw(in: tile, angle: -55)
// Soft light from the top.
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// The shelf the cards rest on.
let shelf = NSBezierPath(roundedRect: NSRect(x: 250, y: 262, width: 524, height: 70), xRadius: 35, yRadius: 35)
withShadow(blur: 24, y: -10, alpha: 0.25) {
    NSColor.white.setFill()
    shelf.fill()
}

// Back card: translucent, tilted left.
let back = card(center: NSPoint(x: 432, y: 506), size: NSSize(width: 250, height: 316), radius: 40, angle: 13)
withShadow(blur: 30, y: -12, alpha: 0.18) {
    NSColor.white.withAlphaComponent(0.55).setFill()
    back.fill()
}

// Front card: solid white, tilted right, with a little picture on it.
let frontCenter = NSPoint(x: 586, y: 496)
let front = card(center: frontCenter, size: NSSize(width: 262, height: 330), radius: 42, angle: -8)
withShadow(blur: 36, y: -16, alpha: 0.28) {
    NSColor.white.setFill()
    front.fill()
}
NSGraphicsContext.saveGraphicsState()
var transform = AffineTransform(translationByX: frontCenter.x, byY: frontCenter.y)
transform.rotate(byDegrees: -8)
(transform as NSAffineTransform).concat()
// Picture: sunset over a hill, then two text lines below it.
let photo = NSRect(x: -100, y: -10, width: 200, height: 134)
let photoPath = NSBezierPath(roundedRect: photo, xRadius: 22, yRadius: 22)
NSGraphicsContext.saveGraphicsState()
photoPath.addClip()
NSGradient(colors: [color(0xF79A5B), color(0x9A5BD6)])!.draw(in: photo, angle: 90)
color(0xFFE08A).setFill()
NSBezierPath(ovalIn: NSRect(x: -30, y: 30, width: 60, height: 60)).fill()
color(0x3B2A6B).setFill()
let hill = NSBezierPath()
hill.move(to: NSPoint(x: photo.minX, y: photo.minY))
hill.line(to: NSPoint(x: photo.minX, y: 30))
hill.curve(to: NSPoint(x: photo.maxX, y: 22), controlPoint1: NSPoint(x: -30, y: 70), controlPoint2: NSPoint(x: 40, y: 0))
hill.line(to: NSPoint(x: photo.maxX, y: photo.minY))
hill.fill()
NSGraphicsContext.restoreGraphicsState()
color(0xD9DCE6).setFill()
NSBezierPath(roundedRect: NSRect(x: -100, y: -62, width: 200, height: 22), xRadius: 11, yRadius: 11).fill()
NSBezierPath(roundedRect: NSRect(x: -100, y: -104, width: 130, height: 22), xRadius: 11, yRadius: 11).fill()
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
