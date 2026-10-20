// Places a shelf snapshot on a colorful backdrop with a soft shadow, for the README.
// Usage: frame <input.png> <output.png>
//        frame --sample-image <output.png>   (draws a sample "photo" for the demo files)
import AppKit

func gradient(_ rect: NSRect, _ colors: [NSColor], angle: CGFloat) {
    NSGradient(colors: colors)!.draw(in: rect, angle: angle)
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func canvas(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let args = CommandLine.arguments
if args[1] == "--sample-image" {
    // A simple sunset landscape.
    let rep = canvas(width: 1200, height: 800) {
        let rect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        gradient(rect, [NSColor(red: 0.98, green: 0.55, blue: 0.3, alpha: 1),
                        NSColor(red: 0.55, green: 0.3, blue: 0.75, alpha: 1)], angle: 90)
        NSColor(red: 1, green: 0.85, blue: 0.5, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 480, y: 260, width: 240, height: 240)).fill()
        NSColor(red: 0.2, green: 0.15, blue: 0.35, alpha: 1).setFill()
        let hills = NSBezierPath()
        hills.move(to: .zero)
        hills.line(to: NSPoint(x: 0, y: 300))
        hills.curve(to: NSPoint(x: 1200, y: 260), controlPoint1: NSPoint(x: 400, y: 420), controlPoint2: NSPoint(x: 800, y: 120))
        hills.line(to: NSPoint(x: 1200, y: 0))
        hills.fill()
    }
    writePNG(rep, to: args[2])
    exit(0)
}

let shot = NSImage(contentsOfFile: args[1])!
let shotRep = shot.representations[0]
let w = CGFloat(shotRep.pixelsWide), h = CGFloat(shotRep.pixelsHigh)
let pad: CGFloat = 120
let rep = canvas(width: Int(w + pad * 2), height: Int(h + pad * 2)) {
    let rect = NSRect(x: 0, y: 0, width: w + pad * 2, height: h + pad * 2)
    gradient(rect, [NSColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1),
                    NSColor(red: 0.85, green: 0.38, blue: 0.75, alpha: 1)], angle: -35)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 50
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    let card = NSRect(x: pad, y: pad, width: w, height: h)
    NSBezierPath(roundedRect: card.insetBy(dx: 2, dy: 2), xRadius: 46, yRadius: 46).fill()
    NSGraphicsContext.restoreGraphicsState()
    shot.draw(in: card)
}
writePNG(rep, to: args[2])
