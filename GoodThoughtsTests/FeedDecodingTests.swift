import XCTest
@testable import GoodThoughts

final class FeedDecodingTests: XCTestCase {
    private let base = URL(string: "https://goodthoughts.page/wallpapers.json")!

    private func decode(_ json: String) throws -> Feed {
        try Feed.decode(Data(json.utf8), baseURL: base)
    }

    private func feedJSON(version: String = "1.0", quotes: String) -> String {
        #"{"version": "\#(version)", "generated": "2026-11-04T00:00:00Z", "quotes": [\#(quotes)]}"#
    }

    private let allen = #"""
    {
      "id": "allen-calmness", "number": "No. 001",
      "text": "Calmness of mind is one of the beautiful jewels of wisdom.",
      "author": "James Allen", "source": "As a Man Thinketh", "lang": "en",
      "url": "https://goodthoughts.page/q/allen-calmness/",
      "wallpapers": {
        "16x10": "https://goodthoughts.page/wallpaper/q/allen-calmness/16x10.png",
        "16x9": "https://goodthoughts.page/wallpaper/q/allen-calmness/16x9.png"
      }
    }
    """#

    func testDecodesTheContractExample() throws {
        let feed = try decode(feedJSON(quotes: allen))
        XCTAssertEqual(feed.version.major, 1)
        XCTAssertEqual(feed.version.minor, 0)
        XCTAssertEqual(feed.generated, ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z"))
        let quote = try XCTUnwrap(feed.quotes.first)
        XCTAssertEqual(quote.id, "allen-calmness")
        XCTAssertEqual(quote.number, "No. 001")
        XCTAssertEqual(quote.author, "James Allen")
        XCTAssertEqual(quote.source, "As a Man Thinketh")
        XCTAssertEqual(quote.language, .english)
        XCTAssertFalse(quote.language.isRightToLeft)
        XCTAssertEqual(quote.url?.absoluteString, "https://goodthoughts.page/q/allen-calmness/")
        XCTAssertEqual(quote.wallpapers["16x9"]?.absoluteString,
                       "https://goodthoughts.page/wallpaper/q/allen-calmness/16x9.png")
    }

    func testIgnoresUnknownFieldsAtEveryLevel() throws {
        let json = #"""
        {
          "version": "1.3", "generated": "2026-11-04T00:00:00Z", "license": "CC BY",
          "quotes": [{
            "id": "x", "number": "No. 002", "text": "Hi", "author": "A", "source": "S", "lang": "en",
            "url": "https://goodthoughts.page/q/x/", "category": "calm", "highlight": [3, 9],
            "wallpapers": {"16x10": "https://a/x.png", "16x9": "https://a/y.png", "21x9": "https://a/z.png"}
          }]
        }
        """#
        let feed = try decode(json)
        XCTAssertEqual(feed.version.minor, 3)
        XCTAssertEqual(feed.quotes.count, 1)
        XCTAssertEqual(feed.quotes[0].wallpapers.count, 3, "Unknown ratios are kept for the picker to ignore")
    }

    func testEmptyAuthorAndSourceStayEmpty() throws {
        let json = feedJSON(quotes: #"""
        {"id": "anon", "number": "No. 013", "text": "Text", "author": "", "source": "", "lang": "en",
         "url": "https://goodthoughts.page/q/anon/", "wallpapers": {}}
        """#)
        let quote = try XCTUnwrap(decode(json).quotes.first)
        XCTAssertEqual(quote.author, "")
        XCTAssertEqual(quote.source, "")
    }

    func testMissingOptionalFieldsDefault() throws {
        let json = feedJSON(quotes: #"{"id": "bare", "text": "Text"}"#)
        let quote = try XCTUnwrap(decode(json).quotes.first)
        XCTAssertEqual(quote.author, "")
        XCTAssertEqual(quote.number, "")
        XCTAssertEqual(quote.language, .english)
        XCTAssertNil(quote.url)
        XCTAssertTrue(quote.wallpapers.isEmpty)
    }

    func testArabicQuoteKeepsItsTextAndReadsRightToLeft() throws {
        let text = "الغزلان تحب أن تموت عند أهلها، الصقور لا يهمها أين تموت."
        let json = feedJSON(quotes: #"""
        {"id": "kanafani-gazelles", "number": "No. 011", "text": "\#(text)", "author": "غسان كنفاني",
         "source": "", "lang": "ar", "url": "https://goodthoughts.page/q/kanafani-gazelles/", "wallpapers": {}}
        """#)
        let quote = try XCTUnwrap(decode(json).quotes.first)
        XCTAssertEqual(quote.text, text)
        XCTAssertEqual(quote.author, "غسان كنفاني")
        XCTAssertEqual(quote.language, .arabic)
        XCTAssertTrue(quote.language.isRightToLeft)
    }

    func testUnknownLanguageStillDecodes() throws {
        let json = feedJSON(quotes: #"{"id": "fa", "text": "x", "lang": "fa-IR"}"#)
        let quote = try XCTUnwrap(decode(json).quotes.first)
        XCTAssertEqual(quote.language.rawValue, "fa-ir")
        XCTAssertTrue(quote.language.isRightToLeft)
    }

    func testNewerMajorVersionAsksForAnUpdate() {
        // A v2 feed may have changed shape completely; the version alone decides.
        let json = #"{"version": "2.0", "entries": {"whatever": true}}"#
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? FeedError, .unsupportedVersion("2.0"))
            XCTAssertEqual((error as? FeedError)?.errorDescription, "Update the app to read the new quote feed.")
        }
    }

    func testNewerMinorVersionIsFine() throws {
        XCTAssertNoThrow(try decode(feedJSON(version: "1.9", quotes: allen)))
    }

    func testGarbageIsInvalidNotACrash() {
        for json in ["", "[]", "{}", #"{"version": "one"}"#, #"{"version": "1.0"}"#] {
            XCTAssertThrowsError(try decode(json), json) { error in
                guard case .invalid = error as? FeedError else {
                    return XCTFail("Expected .invalid for \(json), got \(error)")
                }
            }
        }
    }

    func testRelativeWallpaperURLsResolveAgainstTheFeed() throws {
        let json = feedJSON(quotes: #"{"id": "r", "text": "x", "wallpapers": {"16x9": "wallpaper/q/r/16x9.png"}}"#)
        let quote = try XCTUnwrap(decode(json).quotes.first)
        XCTAssertEqual(quote.wallpapers["16x9"]?.absoluteString,
                       "https://goodthoughts.page/wallpaper/q/r/16x9.png")
    }

    func testFractionalSecondsAndBadDatesInGenerated() throws {
        let fractional = #"{"version": "1.0", "generated": "2026-11-04T00:00:00.250Z", "quotes": []}"#
        XCTAssertNotNil(try decode(fractional).generated)
        let bad = #"{"version": "1.0", "generated": "yesterday", "quotes": []}"#
        XCTAssertNil(try decode(bad).generated)
    }

    func testSampleFeedDecodesWithBundledWallpapers() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "sample-wallpapers", withExtension: "json"))
        let feed = try Feed.decode(Data(contentsOf: url), baseURL: url.deletingLastPathComponent())
        XCTAssertEqual(feed.quotes.count, 4)
        XCTAssertTrue(feed.quotes.contains { $0.language.isRightToLeft })
        XCTAssertTrue(feed.quotes.contains { $0.author.isEmpty && $0.source.isEmpty })
        for quote in feed.quotes {
            for ratio in ["16x10", "16x9"] {
                let file = try XCTUnwrap(quote.wallpapers[ratio], "\(quote.id) has no \(ratio)")
                XCTAssertTrue(file.isFileURL)
                XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), file.path)
            }
        }
    }
}
