#!/usr/bin/env swift
// Draws the app icon: mark No. 07 "Underlined" from the site repo's
// docs/brand/icon/IconsCropped.dc.html (the 96 px variant), full colour, on the
// macOS icon grid (an 824 pt rounded square inside 1024 with a soft shadow).
//
//   swift scripts/make-app-icon.swift
//
// Writes GoodThoughts/Resources/AppIcon.icns via iconutil. A plain .icns, not an
// asset catalog, so scripts/run.sh can bundle it without Xcode.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let fontURL = root.appendingPathComponent("GoodThoughts/Resources/Fonts/InstrumentSerif-Regular.ttf")
let outURL = root.appendingPathComponent("GoodThoughts/Resources/AppIcon.icns")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor])?.first
else { fail("Can't read \(fontURL.path)") }

/// Draws the mark into a 100-unit square (y-up), like the reference's viewBox.
func drawMark(in context: CGContext) {
    // Background tile: paper with a hairline, rx 22.
    let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 22, cornerHeight: 22, transform: nil)
    context.addPath(tile)
    context.setFillColor(color(0xFAFAF7))
    context.fillPath()

    // Highlighter: x 16, y 62, 68 x 14, rx 2, rotate(-5 50 69). SVG y-down -> y-up.
    let bar = CGRect(x: 16, y: 100 - 62 - 14, width: 68, height: 14)
    var spin = CGAffineTransform(translationX: 50, y: 31).rotated(by: 5 * .pi / 180).translatedBy(x: -50, y: -31)
    context.addPath(CGPath(roundedRect: bar, cornerWidth: 2, cornerHeight: 2, transform: &spin))
    context.setFillColor(color(0xF2D649))
    context.fillPath()

    // The g: Instrument Serif 84, centred on x 50, baseline y 62.
    let font = CTFontCreateWithFontDescriptor(descriptor, 84, nil)
    var chars: [UniChar] = Array("g".utf16)
    var glyph = CGGlyph()
    CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1)
    var advance = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
    var place = CGAffineTransform(translationX: 50 - advance.width / 2, y: 100 - 62)
    if let path = CTFontCreatePathForGlyph(font, glyph, &place) {
        context.addPath(path)
        context.setFillColor(color(0x2B2B2B))
        context.fillPath()
    }

    // Hairline edge, drawn last so it stays crisp over the fill.
    context.addPath(tile)
    context.setStrokeColor(color(0xE2E2DC))
    context.setLineWidth(1)
    context.strokePath()
}

func render(pixels: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("No context") }
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    // macOS grid: 824 x 824 body centred in 1024, shadow below.
    let inset: CGFloat = 100, body: CGFloat = 824
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.28))
    context.translateBy(x: inset, y: inset + 8)
    context.scaleBy(x: body / 100, y: body / 100)
    drawMark(in: context)
    context.restoreGState()
    guard let image = context.makeImage() else { fail("No image") }
    return image
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let url = iconset.appendingPathComponent(name)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { fail("Can't write \(name)") }
        CGImageDestinationAddImage(dest, render(pixels: points * scale), nil)
        CGImageDestinationFinalize(dest)
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fail("iconutil failed") }
try? FileManager.default.removeItem(at: iconset)
print("Wrote \(outURL.path)")
