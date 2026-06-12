// Generates AppIcon PNGs for the asset catalog.
// Run: swift scripts/generate_icon.swift
import AppKit

let outputDir = "Assets.xcassets/AppIcon.appiconset"

func renderBase() -> NSImage {
    let canvas = 1024.0
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()

    // macOS icon grid: content squircle is ~824pt centered in the 1024 canvas.
    let inset = (canvas - 824) / 2
    let rect = NSRect(x: inset, y: inset, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.30, alpha: 1),  // warm coral
        NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.62, alpha: 1),  // magenta
        NSColor(calibratedRed: 0.42, green: 0.20, blue: 0.78, alpha: 1),  // violet
    ])!
    gradient.draw(in: path, angle: -60)

    // White wand.and.stars symbol, centered.
    let config = NSImage.SymbolConfiguration(pointSize: 380, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        let scale = 500.0 / max(tinted.size.width, tinted.size.height)
        let w = tinted.size.width * scale
        let h = tinted.size.height * scale
        tinted.draw(
            in: NSRect(x: (canvas - w) / 2, y: (canvas - h) / 2, width: w, height: h),
            from: .zero, operation: .sourceOver, fraction: 1
        )
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let base = renderBase()
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(base, pixels: pixels, to: "\(outputDir)/icon_\(pixels).png")
}
print("Icons written to \(outputDir)")
