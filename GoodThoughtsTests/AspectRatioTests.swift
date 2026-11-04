import XCTest
@testable import GoodThoughts

final class AspectRatioTests: XCTestCase {
    private let both = ["16x10", "16x9"]

    private func pick(_ width: CGFloat, _ height: CGFloat, _ keys: [String]? = nil) -> String? {
        AspectRatio.closestKey(to: CGSize(width: width, height: height), among: keys ?? both)
    }

    func testParsesKeys() {
        XCTAssertEqual(AspectRatio("16x10")?.value, 1.6)
        XCTAssertEqual(AspectRatio("16X9")?.key, "16x9")
        XCTAssertNil(AspectRatio("square"))
        XCTAssertNil(AspectRatio("0x9"))
        XCTAssertNil(AspectRatio("16x"))
        XCTAssertNil(AspectRatio("16x9x2"))
        XCTAssertNil(AspectRatio("-16x9"))
    }

    func testSixteenByTenScreens() {
        XCTAssertEqual(pick(1440, 900), "16x10")    // MacBook Air 13" (older), points
        XCTAssertEqual(pick(2560, 1600), "16x10")   // 13" Retina, pixels
        XCTAssertEqual(pick(1512, 982), "16x10")    // MacBook Pro 14" (1.54)
        XCTAssertEqual(pick(1728, 1117), "16x10")   // MacBook Pro 16" (1.55)
        XCTAssertEqual(pick(1470, 956), "16x10")    // MacBook Air 13" M2 (1.54)
    }

    func testSixteenByNineScreens() {
        XCTAssertEqual(pick(1920, 1080), "16x9")
        XCTAssertEqual(pick(2560, 1440), "16x9")    // iMac, Studio Display (points)
        XCTAssertEqual(pick(5120, 2880), "16x9")
        XCTAssertEqual(pick(3840, 2160), "16x9")
    }

    func testOddShapesGetTheNearestAvailable() {
        XCTAssertEqual(pick(3440, 1440), "16x9")    // 21:9 ultrawide
        XCTAssertEqual(pick(1280, 1024), "16x10")   // 5:4
        XCTAssertEqual(pick(1080, 1920), "16x10")   // portrait
    }

    func testUsesNewRatiosWhenTheFeedAddsThem() {
        XCTAssertEqual(pick(3440, 1440, ["16x10", "16x9", "21x9"]), "21x9")
        XCTAssertEqual(pick(1920, 1080, ["16x10", "16x9", "21x9"]), "16x9")
    }

    func testIgnoresKeysThatArentRatios() {
        XCTAssertEqual(pick(1920, 1080, ["square", "16x10", "og"]), "16x10")
        XCTAssertNil(pick(1920, 1080, ["square", "og"]))
        XCTAssertNil(pick(1920, 1080, []))
    }

    func testDegenerateScreenSizeIsNil() {
        XCTAssertNil(pick(0, 1080))
        XCTAssertNil(pick(1920, 0))
    }

    func testTieGoesToTheWiderRatioWhateverTheOrder() {
        // 1.6 and 1.777… are equally far from their geometric mean on a log scale.
        let middle = (1.6 * (16.0 / 9.0)).squareRoot()
        XCTAssertEqual(pick(middle * 1000, 1000, ["16x10", "16x9"]), "16x9")
        XCTAssertEqual(pick(middle * 1000, 1000, ["16x9", "16x10"]), "16x9")
    }
}
