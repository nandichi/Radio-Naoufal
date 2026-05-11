#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Genereert de Radio Naoufal app-icon (gestileerde mini-boombox) in alle vereiste resoluties.
// Output: RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset/*.png

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

let outputDirURL: URL = {
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    return scriptURL
        .deletingLastPathComponent()
        .appendingPathComponent("RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset")
}()

func drawBoomboxIcon(size: CGFloat, in ctx: CGContext) {
    let scale = size / 1024.0
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background gradient (rounded square)
    let cornerRadius = size * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        CGColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
        CGColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Subtle inner highlight
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.04))
    ctx.fill(CGRect(x: 0, y: size * 0.6, width: size, height: size * 0.4))

    // Boombox body (inner rounded rectangle)
    let boomboxRect = CGRect(
        x: size * 0.10,
        y: size * 0.22,
        width: size * 0.80,
        height: size * 0.55
    )
    let boomboxPath = CGPath(roundedRect: boomboxRect, cornerWidth: 18 * scale, cornerHeight: 18 * scale, transform: nil)
    ctx.saveGState()
    ctx.addPath(boomboxPath)
    ctx.clip()

    let bodyColors = [
        CGColor(srgbRed: 0.22, green: 0.23, blue: 0.26, alpha: 1),
        CGColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
    ] as CFArray
    let bodyGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bodyColors, locations: [0, 1])!
    ctx.drawLinearGradient(bodyGradient, start: CGPoint(x: 0, y: boomboxRect.maxY), end: CGPoint(x: 0, y: boomboxRect.minY), options: [])
    ctx.restoreGState()

    // Boombox border
    ctx.saveGState()
    ctx.addPath(boomboxPath)
    ctx.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.45, blue: 0.48, alpha: 1))
    ctx.setLineWidth(2 * scale)
    ctx.strokePath()
    ctx.restoreGState()

    // Two speakers
    let speakerSize = size * 0.30
    let leftSpeakerCenter = CGPoint(x: size * 0.27, y: size * 0.50)
    let rightSpeakerCenter = CGPoint(x: size * 0.73, y: size * 0.50)

    for center in [leftSpeakerCenter, rightSpeakerCenter] {
        // Outer ring
        let outerRect = CGRect(
            x: center.x - speakerSize / 2,
            y: center.y - speakerSize / 2,
            width: speakerSize,
            height: speakerSize
        )
        ctx.setFillColor(CGColor(srgbRed: 0.06, green: 0.06, blue: 0.08, alpha: 1))
        ctx.fillEllipse(in: outerRect)
        ctx.setStrokeColor(CGColor(srgbRed: 0.80, green: 0.81, blue: 0.84, alpha: 1))
        ctx.setLineWidth(2.5 * scale)
        ctx.strokeEllipse(in: outerRect)

        // Inner cone
        let innerRect = outerRect.insetBy(dx: speakerSize * 0.16, dy: speakerSize * 0.16)
        let coneColors = [
            CGColor(srgbRed: 1.0, green: 0.55, blue: 0.06, alpha: 1),
            CGColor(srgbRed: 0.55, green: 0.30, blue: 0.05, alpha: 1),
        ] as CFArray
        let coneGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: coneColors, locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: innerRect)
        ctx.clip()
        ctx.drawRadialGradient(
            coneGradient,
            startCenter: CGPoint(x: center.x - innerRect.width * 0.2, y: center.y + innerRect.height * 0.2),
            startRadius: 0,
            endCenter: center,
            endRadius: innerRect.width / 1.4,
            options: []
        )
        ctx.restoreGState()

        // Center dot
        let dotSize = speakerSize * 0.18
        let dotRect = CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize)
        ctx.setFillColor(CGColor(srgbRed: 0.05, green: 0.04, blue: 0.02, alpha: 1))
        ctx.fillEllipse(in: dotRect)
    }

    // Center cassette / LCD display
    let lcdRect = CGRect(
        x: size * 0.44,
        y: size * 0.43,
        width: size * 0.12,
        height: size * 0.16
    )
    ctx.setFillColor(CGColor(srgbRed: 0.04, green: 0.03, blue: 0.02, alpha: 1))
    ctx.fill(lcdRect)
    ctx.setStrokeColor(CGColor(srgbRed: 0.30, green: 0.30, blue: 0.32, alpha: 1))
    ctx.setLineWidth(1.5 * scale)
    ctx.stroke(lcdRect)

    // LCD glow
    let lcdGlowColors = [
        CGColor(srgbRed: 1.0, green: 0.70, blue: 0.12, alpha: 1),
        CGColor(srgbRed: 0.80, green: 0.40, blue: 0.05, alpha: 1),
    ] as CFArray
    let lcdGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: lcdGlowColors, locations: [0, 1])!
    ctx.saveGState()
    ctx.addRect(lcdRect.insetBy(dx: 4 * scale, dy: 4 * scale))
    ctx.clip()
    ctx.drawLinearGradient(lcdGradient, start: CGPoint(x: 0, y: lcdRect.maxY), end: CGPoint(x: 0, y: lcdRect.minY), options: [])
    ctx.restoreGState()

    // Handle on top
    let handleWidth = size * 0.32
    let handleHeight = size * 0.025
    let handleRect = CGRect(
        x: (size - handleWidth) / 2,
        y: size * 0.79,
        width: handleWidth,
        height: handleHeight
    )
    let handlePath = CGPath(
        roundedRect: handleRect,
        cornerWidth: handleHeight / 2,
        cornerHeight: handleHeight / 2,
        transform: nil
    )
    ctx.saveGState()
    ctx.addPath(handlePath)
    let handleColors = [
        CGColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1),
        CGColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 1),
    ] as CFArray
    let handleGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: handleColors, locations: [0, 1])!
    ctx.clip()
    ctx.drawLinearGradient(handleGradient, start: CGPoint(x: 0, y: handleRect.maxY), end: CGPoint(x: 0, y: handleRect.minY), options: [])
    ctx.restoreGState()

    // Antenna
    let antennaX = size * 0.82
    let antennaTopY = size * 0.85
    let antennaBaseY = size * 0.77
    ctx.setStrokeColor(CGColor(srgbRed: 0.80, green: 0.81, blue: 0.84, alpha: 1))
    ctx.setLineWidth(2 * scale)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: antennaX, y: antennaBaseY))
    ctx.addLine(to: CGPoint(x: antennaX + size * 0.05, y: antennaTopY))
    ctx.strokePath()

    // Bottom strip with preset buttons
    let stripY = size * 0.28
    let buttonSize = size * 0.025
    let buttonGap = size * 0.012
    let totalButtons = 5
    let totalWidth = CGFloat(totalButtons) * buttonSize + CGFloat(totalButtons - 1) * buttonGap
    var x = (size - totalWidth) / 2
    for i in 0..<totalButtons {
        let rect = CGRect(x: x, y: stripY, width: buttonSize, height: buttonSize)
        let alpha: CGFloat = i == 2 ? 1.0 : 0.5
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.71, blue: 0.12, alpha: alpha))
        ctx.fillEllipse(in: rect)
        x += buttonSize + buttonGap
    }

    ctx.restoreGState()

    // Outer rim highlight (very subtle)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08))
    ctx.setLineWidth(2 * scale)
    ctx.strokePath()
    ctx.restoreGState()
}

func renderIcon(size: Int) -> Data? {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )
    guard let bitmap else { return nil }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let nsContext = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current = nsContext
    guard let cgContext = nsContext?.cgContext else { return nil }
    cgContext.setShouldAntialias(true)
    cgContext.interpolationQuality = .high
    drawBoomboxIcon(size: CGFloat(size), in: cgContext)
    return bitmap.representation(using: .png, properties: [:])
}

let fm = FileManager.default
try? fm.createDirectory(at: outputDirURL, withIntermediateDirectories: true)

for entry in sizes {
    guard let data = renderIcon(size: entry.pixels) else {
        FileHandle.standardError.write(Data("Failed to render \(entry.name) (\(entry.pixels)px)\n".utf8))
        continue
    }
    let url = outputDirURL.appendingPathComponent("\(entry.name).png")
    do {
        try data.write(to: url)
        print("Generated \(url.path) (\(entry.pixels)x\(entry.pixels))")
    } catch {
        FileHandle.standardError.write(Data("Failed to write \(url.path): \(error)\n".utf8))
    }
}

print("Done. Re-run xcodegen generate after this.")
