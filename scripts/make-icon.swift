// Applies the macOS app icon template to square artwork and writes an .iconset.
// 1024 canvas, 824x824 body with continuous (superellipse) corners, 100 px margin, soft drop shadow.
// Usage: swift scripts/make-icon.swift <artwork.png> <out.iconset>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3, let artwork = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <artwork.png> <out.iconset>\n".utf8))
    exit(1)
}

func squirclePath(in rect: NSRect, exponent: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let steps = 720
    for step in 0...steps {
        let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let cosine = cos(angle), sine = sin(angle)
        let x = pow(abs(cosine), 2 / exponent) * (cosine < 0 ? -1 : 1)
        let y = pow(abs(sine), 2 / exponent) * (sine < 0 ? -1 : 1)
        let point = NSPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
        step == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    return path
}

func render(_ size: CGFloat) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let unit = size / 1024
    let body = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let path = squirclePath(in: body)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * unit)
    shadow.shadowBlurRadius = 20 * unit
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    artwork.draw(in: body, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let out = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(CGFloat(base * scale))?.write(to: out.appendingPathComponent(name))
    }
}
