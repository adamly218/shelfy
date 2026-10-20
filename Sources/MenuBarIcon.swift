import AppKit

/// Shelfy's menu bar icon: two file cards fanned out over a rounded shelf.
/// Drawn as a template image so macOS tints it for light, dark and tinted menu bars.
enum MenuBarIcon {
    static func make(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width / 18 // drawn on an 18pt grid
            NSColor.black.set()

            // Back card, tilted left; drawn as an outline so it reads as "behind".
            card(center: NSPoint(x: 6.3 * s, y: 11.2 * s), size: NSSize(width: 6.6 * s, height: 8.6 * s),
                 angle: 16, scale: s).stroke()

            // Front card, tilted right, solid, with a folded corner cut out.
            let front = card(center: NSPoint(x: 11.4 * s, y: 10.6 * s), size: NSSize(width: 6.8 * s, height: 8.8 * s),
                             angle: -8, scale: s)
            NSGraphicsContext.current?.saveGraphicsState()
            // Clear the space around the front card so the outline behind it breaks cleanly.
            NSGraphicsContext.current?.compositingOperation = .clear
            let gap = front.copy() as! NSBezierPath
            gap.lineWidth = 2.4 * s
            gap.stroke()
            gap.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            front.fill()

            // The shelf: a rounded bar the cards rest on.
            let shelf = NSBezierPath(roundedRect: NSRect(x: 1.5 * s, y: 1.5 * s, width: 15 * s, height: 3 * s),
                                     xRadius: 1.5 * s, yRadius: 1.5 * s)
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            let shelfGap = NSBezierPath(roundedRect: NSRect(x: 0.5 * s, y: 0.5 * s, width: 17 * s, height: 5 * s),
                                        xRadius: 2.5 * s, yRadius: 2.5 * s)
            shelfGap.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            shelf.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Shelfy"
        return image
    }

    /// A rounded card rotated around its center.
    private static func card(center: NSPoint, size: NSSize, angle: CGFloat, scale s: CGFloat) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: NSRect(x: -size.width / 2, y: -size.height / 2,
                                                    width: size.width, height: size.height),
                                xRadius: 1.8 * s, yRadius: 1.8 * s)
        path.lineWidth = 1.4 * s
        var transform = AffineTransform(translationByX: center.x, byY: center.y)
        transform.rotate(byDegrees: angle)
        path.transform(using: transform)
        return path
    }
}
