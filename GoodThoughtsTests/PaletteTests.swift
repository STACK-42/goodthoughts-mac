import XCTest
@testable import GoodThoughts

final class PaletteTests: XCTestCase {
    func testParsesHexWithAndWithoutHash() {
        let ink = RGB(hex: "#2B2B2B")
        XCTAssertEqual(ink, RGB(hex: "2B2B2B"))
        XCTAssertEqual(ink?.red ?? 0, 0x2B / 255, accuracy: 1e-9)
    }

    func testReadsChannelsInOrder() throws {
        let highlighter = try XCTUnwrap(RGB(hex: "#F2D649"))
        XCTAssertEqual(highlighter.red, 0xF2 / 255, accuracy: 1e-9)
        XCTAssertEqual(highlighter.green, 0xD6 / 255, accuracy: 1e-9)
        XCTAssertEqual(highlighter.blue, 0x49 / 255, accuracy: 1e-9)
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(RGB(hex: "#FFF"))
        XCTAssertNil(RGB(hex: "#GGGGGG"))
        XCTAssertNil(RGB(hex: "#FAFAF7FF"))
        XCTAssertNil(RGB(hex: ""))
        XCTAssertNil(RGB(hex: "+FFFFF"))
    }

    func testEveryPaletteValueParses() {
        for hex in Palette.allHexes {
            XCTAssertNotNil(RGB(hex: hex), hex)
        }
    }
}
