import AppKit
import CoreGraphics
import Foundation

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let s = CGFloat(size) / 1024.0
    cg.scaleBy(x: s, y: s)

    // Flip CG context so (0,0) is top-left, +Y is down (matching SVG & Icon Composer)
    cg.translateBy(x: 0, y: 1024)
    cg.scaleBy(x: 1, y: -1)

    // Standard macOS icon squircle geometry inside 1024x1024:
    // 824x824 centered at (512, 512), margin 100pt, cornerRadius 185.4pt
    let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)

    // Outer drop shadow for macOS squircle
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: 14),
        blur: 28,
        color: NSColor(calibratedWhite: 0, alpha: 0.30).cgColor
    )
    cg.addPath(squirclePath)
    cg.setFillColor(NSColor.black.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Clip to squircle in 1024x1024 space
    cg.saveGState()
    cg.addPath(squirclePath)
    cg.clip()

    // Transform from 1024x1024 Icon Composer space into 824x824 squircle space
    cg.saveGState()
    cg.translateBy(x: 512, y: 512)
    let innerScale: CGFloat = 824.0 / 1024.0
    cg.scaleBy(x: innerScale, y: innerScale)
    cg.translateBy(x: -512, y: -512)

    // 1. Background Linear Gradient from icon.json:
    // "display-p3:0.44314,0.13333,0.98039,1.00000" -> top
    // "srgb:0.96471,0.00392,0.61569,1.00000" -> bottom
    let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    let c1 = NSColor(displayP3Red: 0.44314, green: 0.13333, blue: 0.98039, alpha: 1.0).cgColor
    let c2 = NSColor(srgbRed: 0.96471, green: 0.00392, blue: 0.61569, alpha: 1.0).cgColor
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: [c1, c2] as CFArray, locations: [0.0, 1.0])!
    cg.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: 512, y: 0),
        end: CGPoint(x: 512, y: 1024),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Helper to place a layer given SVG viewBox size, scale, and translation-in-points
    func withLayerTransform(svgW: CGFloat, svgH: CGFloat, scale: CGFloat, tx: CGFloat, ty: CGFloat, draw: () -> Void) {
        cg.saveGState()
        let cx = 512.0 + tx
        let cy = 512.0 + ty
        let w = svgW * scale
        let h = svgH * scale
        cg.translateBy(x: cx - w / 2.0, y: cy - h / 2.0)
        cg.scaleBy(x: scale, y: scale)
        draw()
        cg.restoreGState()
    }

    // 2. Group 2: Ativo 5icon.svg (Outer rounded grid frame with 3 window cutouts)
    // viewBox: 208 x 208, scale: 3.18, translation: [0, 0]
    withLayerTransform(svgW: 208, svgH: 208, scale: 3.18, tx: 0, ty: 0) {
        let framePath = CGMutablePath()
        framePath.addRoundedRect(in: CGRect(x: 0, y: 0, width: 208, height: 208), cornerWidth: 48, cornerHeight: 48)
        framePath.addRoundedRect(in: CGRect(x: 22, y: 120, width: 74, height: 60), cornerWidth: 14, cornerHeight: 14)
        framePath.addRoundedRect(in: CGRect(x: 22, y: 28, width: 74, height: 60), cornerWidth: 14, cornerHeight: 14)
        framePath.addRoundedRect(in: CGRect(x: 112, y: 28, width: 74, height: 60), cornerWidth: 14, cornerHeight: 14)

        // Drop shadow from icon.json ("shadow": {"kind": "layer-color", "opacity": 0.8})
        cg.saveGState()
        cg.setShadow(
            offset: CGSize(width: 0, height: 14),
            blur: 32,
            color: NSColor(srgbRed: 0.22, green: 0.02, blue: 0.38, alpha: 0.45).cgColor
        )
        cg.addPath(framePath)
        cg.setFillColor(NSColor(srgbRed: 1.0, green: 0.96, blue: 0.996, alpha: 0.94).cgColor)
        cg.drawPath(using: .eoFill)
        cg.restoreGState()

        // Gradient fill on Ativo 5icon from icon.json
        cg.saveGState()
        cg.addPath(framePath)
        cg.clip(using: .evenOdd)
        let f1 = NSColor(srgbRed: 1.00000, green: 0.92657, blue: 0.99375, alpha: 0.95).cgColor
        let f2 = NSColor(srgbRed: 0.99788, green: 0.98635, blue: 1.00000, alpha: 0.98).cgColor
        let fGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [f1, f2] as CFArray, locations: [0.0, 1.0])!
        cg.drawLinearGradient(
            fGrad,
            start: CGPoint(x: 208 * 0.14, y: 208 * 0.39),
            end: CGPoint(x: 208 * 1.0, y: 208 * 1.0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        cg.restoreGState()
    }

    // 3. Group 1, Layer 2: Ativo 4icon.svg (Bottom-right pill / card behind play triangle)
    withLayerTransform(svgW: 74, svgH: 60, scale: 3.18, tx: 137, ty: 146) {
        let pillRect = CGRect(x: 0, y: 0, width: 74, height: 60)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        cg.saveGState()
        cg.setShadow(
            offset: CGSize(width: 0, height: 4),
            blur: 14,
            color: NSColor(srgbRed: 0.44, green: 0.13, blue: 0.98, alpha: 0.20).cgColor
        )
        cg.addPath(pillPath)
        cg.setFillColor(NSColor(srgbRed: 0.975, green: 0.94, blue: 1.0, alpha: 1.0).cgColor)
        cg.fillPath()
        cg.restoreGState()
    }

    // 4. Group 1, Layer 1: Ativo 3icon.svg (Play triangle inside bottom-right cell)
    withLayerTransform(svgW: 20, svgH: 23.1, scale: 4.42, tx: 148, ty: 146) {
        let playPath = CGMutablePath()
        playPath.move(to: CGPoint(x: 0, y: 0))
        playPath.addLine(to: CGPoint(x: 20, y: 11.55))
        playPath.addLine(to: CGPoint(x: 0, y: 23.1))
        playPath.closeSubpath()

        cg.saveGState()
        cg.setShadow(
            offset: CGSize(width: 0, height: 4),
            blur: 12,
            color: NSColor(srgbRed: 0.65, green: 0.10, blue: 0.85, alpha: 0.42).cgColor
        )
        cg.addPath(playPath)
        cg.clip()

        let p1 = NSColor(displayP3Red: 0.55, green: 0.18, blue: 0.98, alpha: 1.0).cgColor
        let p2 = NSColor(srgbRed: 0.91423, green: 0.25, blue: 0.88, alpha: 1.0).cgColor
        let pGrad = CGGradient(colorsSpace: colorSpace, colors: [p1, p2] as CFArray, locations: [0.0, 1.0])!
        cg.drawLinearGradient(
            pGrad,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 20, y: 23.1),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        cg.restoreGState()
    }

    cg.restoreGState() // restore innerScale

    // Outer squircle border highlight in 1024x1024 space (right on the edge of the 824x824 squircle)
    cg.saveGState()
    let rimPath = CGPath(roundedRect: iconRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil)
    cg.addPath(rimPath)
    cg.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.28).cgColor)
    cg.setLineWidth(3.0)
    cg.strokePath()
    cg.restoreGState()

    cg.restoreGState() // restore squircle clip
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconsetPath = "/Users/marcos/Downloads/GridApp/Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    let rep = renderIcon(size: px)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}
print("Generated clean AppIcon.iconset successfully")
