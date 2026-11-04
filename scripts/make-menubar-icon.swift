#!/usr/bin/env swift
// Draws the menu bar icon: mark No. 07 "Underlined" from the site repo's
// docs/brand/icon/IconsCropped.dc.html, as a monochrome template image.
//
//   swift scripts/make-menubar-icon.swift [preview.png]
//
// Writes GoodThoughts/Resources/MenuBarIcon.pdf (18 x 18 pt, vector). A template
// image only uses alpha, so the highlighter bar is drawn translucent and the g
// opaque. That keeps them apart once macOS tints both the same colour.
// With a path argument it also writes an enlarged preview on light and dark bars.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let fontURL = root.appendingPathComponent("GoodThoughts/Resources/Fonts/InstrumentSerif-Regular.ttf")
let outURL = root.appendingPathComponent("GoodThoughts/Resources/MenuBarIcon.pdf")

let canvas: CGFloat = 18   // points; the menu bar is 22 pt tall
let padding: CGFloat = 1
let barAlpha: CGFloat = 0.45

// Geometry of the 16 px variant in the reference, in its 100-unit viewBox.
// SVG is y-down; everything below is converted to y-up.
let fontSize: CGFloat = 92
let baselineY: CGFloat = 62
let bar = CGRect(x: 12, y: 58, width: 76, height: 22)
let barRadius: CGFloat = 2
let barRotation: CGFloat = -5          // degrees, SVG sense
let barPivot = CGPoint(x: 50, y: 69)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// The g, centred on x = 50 (text-anchor: middle), sitting on the baseline.
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first else { fail("Can't read \(fontURL.path)") }
let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
var chars: [UniChar] = Array("g".utf16)
var glyph = CGGlyph()
guard CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1) else { fail("No g in the font") }
var advance = CGSize.zero
CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
var glyphPlacement = CGAffineTransform(translationX: 50 - advance.width / 2, y: 100 - baselineY)
guard let glyphPath = CTFontCreatePathForGlyph(font, glyph, &glyphPlacement) else { fail("No outline for g") }

// The bar, flipped to y-up. A negative SVG rotation is counter-clockwise on
// screen, which is a positive angle once y points up.
let barUp = CGRect(x: bar.minX, y: 100 - bar.maxY, width: bar.width, height: bar.height)
let pivotUp = CGPoint(x: barPivot.x, y: 100 - barPivot.y)
var barTransform = CGAffineTransform(translationX: pivotUp.x, y: pivotUp.y)
    .rotated(by: -barRotation * .pi / 180)
    .translatedBy(x: -pivotUp.x, y: -pivotUp.y)
let barPath = CGPath(roundedRect: barUp, cornerWidth: barRadius, cornerHeight: barRadius, transform: &barTransform)

// Fit the mark into the canvas.
let bounds = glyphPath.boundingBoxOfPath.union(barPath.boundingBoxOfPath)
let scale = (canvas - 2 * padding) / max(bounds.width, bounds.height)
let fit = CGAffineTransform(translationX: canvas / 2, y: canvas / 2)
    .scaledBy(x: scale, y: scale)
    .translatedBy(x: -bounds.midX, y: -bounds.midY)

func draw(in context: CGContext, color: CGColor) {
    context.saveGState()
    context.concatenate(fit)
    context.setFillColor(color.copy(alpha: barAlpha) ?? color)
    context.addPath(barPath)
    context.fillPath()
    context.setFillColor(color)
    context.addPath(glyphPath)
    context.fillPath()
    context.restoreGState()
}

var mediaBox = CGRect(x: 0, y: 0, width: canvas, height: canvas)
guard let pdf = CGContext(outURL as CFURL, mediaBox: &mediaBox, nil) else { fail("Can't write \(outURL.path)") }
pdf.beginPDFPage(nil)
draw(in: pdf, color: CGColor(gray: 0, alpha: 1))
pdf.endPDFPage()
pdf.closePDF()
print("Wrote \(outURL.path)")

// Optional preview: the icon at 8x on a light and a dark menu bar.
if CommandLine.arguments.count > 1 {
    let zoom: CGFloat = 8
    let side = Int(canvas * zoom)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let png = CGContext(data: nil, width: side * 2, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("Can't make preview") }
    let looks: [(bar: CGFloat, ink: CGFloat)] = [(0.93, 0), (0.17, 1)]
    for (index, look) in looks.enumerated() {
        png.saveGState()
        png.translateBy(x: CGFloat(index * side), y: 0)
        png.setFillColor(CGColor(gray: look.bar, alpha: 1))
        png.fill(CGRect(x: 0, y: 0, width: side, height: side))
        png.scaleBy(x: zoom, y: zoom)
        draw(in: png, color: CGColor(gray: look.ink, alpha: 1))
        png.restoreGState()
    }
    let previewURL = URL(fileURLWithPath: CommandLine.arguments[1])
    guard let image = png.makeImage(),
          let dest = CGImageDestinationCreateWithURL(previewURL as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("Can't write preview") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(previewURL.path)")
}
