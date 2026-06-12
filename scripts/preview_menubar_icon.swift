// Renders the menu bar icons at 8x for design review.
// Run: swiftc Sources/MenuBarIcon.swift scripts/preview_menubar_icon.swift -o /tmp/iconpreview && /tmp/iconpreview
import AppKit

func writePreview(_ image: NSImage, to path: String) {
    let pixels = 144
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.white.set()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

writePreview(MenuBarIcon.normal, to: "/tmp/menubar_normal.png")
writePreview(MenuBarIcon.working, to: "/tmp/menubar_working.png")
print("written")
