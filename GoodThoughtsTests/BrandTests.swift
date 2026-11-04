import AppKit
import SwiftUI
import XCTest
@testable import GoodThoughts

@MainActor
final class BrandTests: XCTestCase {
    func testEveryBrandFontRegistersAndResolves() {
        XCTAssertEqual(BrandFont.registerAll(), [], "Font files missing from the app bundle")
        for font in BrandFont.allCases {
            XCTAssertNotNil(NSFont(name: font.rawValue, size: 12), "\(font.rawValue) didn't resolve")
        }
    }

    func testRegisteringTwiceIsHarmless() {
        BrandFont.registerAll()
        XCTAssertEqual(BrandFont.registerAll(), [])
    }

    func testFontLicencesShipWithTheFonts() {
        for name in ["InstrumentSerif-OFL", "EBGaramond-OFL", "JetBrainsMono-OFL", "Amiri-OFL"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "txt"), name)
        }
    }

    func testArabicDetection() {
        XCTAssertTrue("غسان كنفاني".containsArabic)
        XCTAssertTrue("Kanafani (غسان)".containsArabic)
        XCTAssertFalse("Seneca".containsArabic)
        XCTAssertFalse("".containsArabic)
    }

    func testArabicGetsMoreLeadingThanLatin() {
        XCTAssertGreaterThan(Typography.quoteLineSpacing(rightToLeft: true),
                             Typography.quoteLineSpacing(rightToLeft: false))
    }

    func testThemeFollowsTheAppearance() {
        func resolved(_ color: Color, _ name: NSAppearance.Name) -> String {
            var hex = ""
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                let ns = NSColor(color).usingColorSpace(.sRGB)!
                hex = String(format: "#%02X%02X%02X", Int(round(ns.redComponent * 255)),
                             Int(round(ns.greenComponent * 255)), Int(round(ns.blueComponent * 255)))
            }
            return hex
        }
        XCTAssertEqual(resolved(Theme.paper, .aqua), "#FAFAF7")
        XCTAssertEqual(resolved(Theme.ink, .aqua), "#2B2B2B")
        XCTAssertEqual(resolved(Theme.paper, .darkAqua), "#1E1E1C")
        XCTAssertEqual(resolved(Theme.ink, .darkAqua), "#FAFAF7")
        XCTAssertEqual(resolved(Theme.highlighter, .darkAqua), "#F2D649")
    }
}
