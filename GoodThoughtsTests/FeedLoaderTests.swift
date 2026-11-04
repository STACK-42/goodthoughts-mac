import XCTest
@testable import GoodThoughts

final class FeedLoaderTests: XCTestCase {
    private var cacheDirectory: URL!
    private var host: String!

    override func setUpWithError() throws {
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FeedLoaderTests-\(UUID().uuidString)", isDirectory: true)
        host = "feed-\(UUID().uuidString.lowercased()).test"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private func loader(sample: URL? = nil) -> FeedLoader {
        FeedLoader(feedURL: URL(string: "https://\(host!)/wallpapers.json")!,
                   session: StubURLProtocol.session(),
                   cacheDirectory: cacheDirectory,
                   sampleFeedURL: sample)
    }

    private func feed(version: String = "1.0", ids: [String]) -> Data {
        let quotes = ids.map { #"{"id": "\#($0)", "text": "t", "wallpapers": {"16x9": "wallpaper/\#($0).png"}}"# }
        return Data(#"{"version": "\#(version)", "quotes": [\#(quotes.joined(separator: ","))]}"#.utf8)
    }

    func testLoadsFromTheNetworkAndCachesIt() async throws {
        StubURLProtocol.stub(host: host, .data(feed(ids: ["a", "b"])))
        let loaded = try await loader().load()
        XCTAssertEqual(loaded.source, .network)
        XCTAssertNil(loaded.networkError)
        XCTAssertEqual(loaded.feed.quotes.map(\.id), ["a", "b"])
        XCTAssertEqual(loaded.feed.quotes[0].wallpapers["16x9"]?.absoluteString, "https://\(host!)/wallpaper/a.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: loader().cacheFile.path))
    }

    func testFallsBackToTheCacheWhenOffline() async throws {
        StubURLProtocol.stub(host: host, .data(feed(ids: ["a", "b", "c"])))
        _ = try await loader().load()

        StubURLProtocol.stub(host: host, .failure(.notConnectedToInternet))
        let loaded = try await loader().load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(loaded.feed.quotes.map(\.id), ["a", "b", "c"])
        guard case .unavailable = loaded.networkError else {
            return XCTFail("Expected .unavailable, got \(String(describing: loaded.networkError))")
        }
        // Relative URLs in the cached copy still point at the feed's host.
        XCTAssertEqual(loaded.feed.quotes[0].wallpapers["16x9"]?.host, host)
    }

    func testFallsBackToTheCacheOnServerErrors() async throws {
        StubURLProtocol.stub(host: host, .data(feed(ids: ["a"])))
        _ = try await loader().load()
        StubURLProtocol.stub(host: host, .data(Data("<h1>Bad gateway</h1>".utf8), status: 502))
        let loaded = try await loader().load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(loaded.networkError, .httpStatus(502))
    }

    func testABrokenDownloadDoesNotReplaceTheCache() async throws {
        StubURLProtocol.stub(host: host, .data(feed(ids: ["good"])))
        _ = try await loader().load()
        StubURLProtocol.stub(host: host, .data(Data("{\"version\": \"1.0\", \"quot".utf8)))
        let loaded = try await loader().load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(loaded.feed.quotes.map(\.id), ["good"])
    }

    func testNewerMajorVersionKeepsTheCacheAndFlagsAnUpdate() async throws {
        StubURLProtocol.stub(host: host, .data(feed(ids: ["old"])))
        _ = try await loader().load()
        StubURLProtocol.stub(host: host, .data(feed(version: "2.0", ids: ["new"])))
        let loaded = try await loader().load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertTrue(loaded.updateRequired)
        XCTAssertEqual(loaded.feed.quotes.map(\.id), ["old"])
    }

    func testNewerMajorVersionWithNothingCachedThrows() async {
        StubURLProtocol.stub(host: host, .data(feed(version: "2.0", ids: ["new"])))
        do {
            _ = try await loader().load()
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? FeedError, .unsupportedVersion("2.0"))
        }
    }

    func testOfflineWithNoCacheUsesTheSampleWhenGiven() async throws {
        StubURLProtocol.stub(host: host, .failure(.timedOut))
        let sample = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample-wallpapers", withExtension: "json"))
        let loaded = try await loader(sample: sample).load()
        XCTAssertEqual(loaded.source, .sample)
        XCTAssertEqual(loaded.feed.quotes.count, 4)
        XCTAssertEqual(loaded.feed.quotes[0].wallpapers["16x10"]?.isFileURL, true)
    }

    func testOfflineWithNoCacheAndNoSampleThrows() async {
        StubURLProtocol.stub(host: host, .failure(.notConnectedToInternet))
        do {
            _ = try await loader().load()
            XCTFail("Expected an error")
        } catch {
            guard case .unavailable = error as? FeedError else { return XCTFail("Got \(error)") }
        }
    }

    func testTimeoutIsShort() {
        XCTAssertLessThanOrEqual(FeedLoader.requestTimeout, 30)
        let standard = FeedLoader.standard()
        XCTAssertEqual(standard.session.configuration.timeoutIntervalForRequest, FeedLoader.requestTimeout)
        XCTAssertEqual(standard.feedURL.absoluteString, "https://goodthoughts.page/wallpapers.json")
    }
}
