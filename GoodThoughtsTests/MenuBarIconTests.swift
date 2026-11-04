import XCTest
@testable import GoodThoughts

@MainActor
final class MenuBarIconTests: XCTestCase {
    func testIconShipsInTheAppBundleAsATemplate() throws {
        let image = try XCTUnwrap(MenuBarIcon.load(from: .main), "MenuBarIcon.pdf is missing from the app bundle")
        XCTAssertTrue(image.isTemplate, "A non-template icon won't follow the menu bar's appearance")
        XCTAssertEqual(image.size, MenuBarIcon.size)
    }

    func testAppHasNoDockIcon() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
    }
}
