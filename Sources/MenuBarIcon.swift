import AppKit

/// Code-drawn menu bar icon: two uniform "machine text" lines whose last line
/// breaks into a handwritten squiggle — text becoming human. Rendered as a
/// template image so it adapts to light/dark menu bars and tinting.
enum MenuBarIcon {
    /// Idle icon.
    static let normal = make(withSparkle: false)
    /// Shown while a rewrite is streaming.
    static let working = make(withSparkle: true)

    private static func make(withSparkle: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let stroke: CGFloat = 1.7

            // Two rigid, uniform lines of "AI text".
            // Top line is shortened when the sparkle needs the corner.
            let topLine = NSBezierPath()
            topLine.lineWidth = stroke
            topLine.lineCapStyle = .round
            topLine.move(to: NSPoint(x: 2.2, y: 14.2))
            topLine.line(to: NSPoint(x: withSparkle ? 10.8 : 15.8, y: 14.2))
            topLine.stroke()

            let midLine = NSBezierPath()
            midLine.lineWidth = stroke
            midLine.lineCapStyle = .round
            midLine.move(to: NSPoint(x: 2.2, y: 9.6))
            midLine.line(to: NSPoint(x: 12.4, y: 9.6))
            midLine.stroke()

            // The last line is a loose handwritten wave: the humanized text.
            let wave = NSBezierPath()
            wave.lineWidth = stroke
            wave.lineCapStyle = .round
            wave.move(to: NSPoint(x: 2.2, y: 4.4))
            wave.curve(
                to: NSPoint(x: 9.0, y: 4.4),
                controlPoint1: NSPoint(x: 4.4, y: 7.6),
                controlPoint2: NSPoint(x: 6.8, y: 1.2)
            )
            wave.curve(
                to: NSPoint(x: 15.8, y: 4.4),
                controlPoint1: NSPoint(x: 11.2, y: 7.6),
                controlPoint2: NSPoint(x: 13.6, y: 1.2)
            )
            wave.stroke()

            if withSparkle {
                // Four-point star in the freed top-right corner.
                drawSparkle(center: NSPoint(x: 14.6, y: 14.2), radius: 2.9)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawSparkle(center: NSPoint, radius: CGFloat) {
        let path = NSBezierPath()
        let waist = radius * 0.28
        path.move(to: NSPoint(x: center.x, y: center.y + radius))
        path.curve(to: NSPoint(x: center.x + radius, y: center.y),
                   controlPoint1: NSPoint(x: center.x + waist, y: center.y + waist),
                   controlPoint2: NSPoint(x: center.x + waist, y: center.y + waist))
        path.curve(to: NSPoint(x: center.x, y: center.y - radius),
                   controlPoint1: NSPoint(x: center.x + waist, y: center.y - waist),
                   controlPoint2: NSPoint(x: center.x + waist, y: center.y - waist))
        path.curve(to: NSPoint(x: center.x - radius, y: center.y),
                   controlPoint1: NSPoint(x: center.x - waist, y: center.y - waist),
                   controlPoint2: NSPoint(x: center.x - waist, y: center.y - waist))
        path.curve(to: NSPoint(x: center.x, y: center.y + radius),
                   controlPoint1: NSPoint(x: center.x - waist, y: center.y + waist),
                   controlPoint2: NSPoint(x: center.x - waist, y: center.y + waist))
        path.close()
        path.fill()
    }
}
