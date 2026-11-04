#!/usr/bin/env swift
// Draws placeholder wallpapers for the sample feed, so Apply can be tried before the
// site publishes real ones. They show only the catalogue number and aspect ratio:
// the real wallpapers, with the quote set in the brand fonts, come from the site.
//
//   swift scripts/make-sample-wallpapers.swift
//
// Writes GoodThoughts/Sample/sample-<number>-<ratio>.png.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("GoodThoughts/Sample")
let numbers = ["001", "004", "011", "013"]
let sizes: [(name: String, width: Int, height: Int)] = [("16x10", 2560, 1600), ("16x9", 2560, 1440)]

func gray(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let paper = gray(0xFAFAF7), ink = gray(0x2B2B2B), muted = gray(0x8A8A85), rule = gray(0xE2E2DC)
let highlighter = gray(0xF2D649)

func line(_ text: String, size: CGFloat, color: CGColor) -> CTLine {
    let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
}

func drawCentered(_ ctLine: CTLine, in context: CGContext, centerX: CGFloat, baseline: CGFloat) {
    let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
    context.textPosition = CGPoint(x: centerX - width / 2, y: baseline)
    CTLineDraw(ctLine, context)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
for number in numbers {
    for size in sizes {
        let w = CGFloat(size.width), h = CGFloat(size.height)
        guard let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
        context.setFillColor(paper)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // A frame inset like a card, and a slanted highlighter swipe.
        context.setStrokeColor(rule)
        context.setLineWidth(4)
        context.stroke(CGRect(x: 120, y: 120, width: w - 240, height: h - 240))
        context.saveGState()
        context.translateBy(x: w / 2, y: h / 2 - 40)
        context.rotate(by: 5 * .pi / 180)
        context.setFillColor(highlighter)
        context.fill(CGRect(x: -520, y: -60, width: 1040, height: 120))
        context.restoreGState()

        drawCentered(line("No. \(number)", size: 200, color: ink), in: context, centerX: w / 2, baseline: h / 2 - 20)
        drawCentered(line("PLACEHOLDER · \(size.name) · \(size.width)×\(size.height)", size: 44, color: muted),
                     in: context, centerX: w / 2, baseline: h / 2 - 220)
        drawCentered(line("The real wallpaper comes from goodthoughts.page", size: 36, color: muted),
                     in: context, centerX: w / 2, baseline: 200)

        let url = outDir.appendingPathComponent("sample-\(number)-\(size.name).png")
        guard let image = context.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { exit(1) }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("Wrote \(url.lastPathComponent)")
    }
}
