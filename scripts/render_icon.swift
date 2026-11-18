// Renders the Field Notes app icon (contour motif) in light, dark and tinted variants.
// Usage: swift scripts/render_icon.swift <output-dir>
import AppKit
import CoreGraphics
import Foundation

let size = 1024
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

struct Variant {
    let file: String
    let background: CGColor?
    let stroke: CGColor
    let dot: CGColor
}

func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let variants = [
    Variant(file: "AppIcon-light.png", background: rgb(0xF6F3EE), stroke: rgb(0xD24A2F), dot: rgb(0x1A1817)),
    Variant(file: "AppIcon-dark.png", background: rgb(0x121110), stroke: rgb(0xFF6B4E), dot: rgb(0xF3EFEA)),
    Variant(file: "AppIcon-tinted.png", background: nil, stroke: CGColor(gray: 1, alpha: 1), dot: CGColor(gray: 0.85, alpha: 1)),
]

/// Same formula as `ContourMotif` in SkinalyzeKit, so the icon matches the in-app motif.
func contour(in context: CGContext, center: CGPoint, maxRadius: CGFloat, rings: Int, phase: CGFloat) {
    for ring in 1...rings {
        let base = maxRadius * CGFloat(ring) / CGFloat(rings)
        let path = CGMutablePath()
        for step in 0...180 {
            let theta = CGFloat(step) / 180 * 2 * .pi
            let wobble = 1 + 0.06 * sin(3 * theta + phase + CGFloat(ring)) + 0.04 * sin(5 * theta - phase * 0.7 + CGFloat(ring) * 1.7)
            let point = CGPoint(x: center.x + cos(theta) * base * wobble, y: center.y + sin(theta) * base * wobble * 1.15)
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        context.addPath(path)
    }
    context.strokePath()
}

for variant in variants {
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("context") }
    if let background = variant.background {
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    context.setStrokeColor(variant.stroke)
    context.setLineWidth(14)
    context.setLineCap(.round)
    contour(in: context, center: CGPoint(x: 512, y: 500), maxRadius: 330, rings: 6, phase: 0.8)
    context.setFillColor(variant.dot)
    context.fillEllipse(in: CGRect(x: 512 - 34, y: 500 - 34, width: 68, height: 68))

    guard let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("png") }
    try data.write(to: outputDirectory.appendingPathComponent(variant.file))
    print("wrote \(variant.file)")
}
