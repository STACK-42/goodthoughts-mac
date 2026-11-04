import XCTest
@testable import GoodThoughts

@MainActor
private final class FakeDesktop: Desktop {
    var screens: [DesktopScreen]
    var failOn: String?
    private(set) var set: [String: URL] = [:]

    init(_ screens: [DesktopScreen]) { self.screens = screens }

    func setImage(_ file: URL, for screen: DesktopScreen) throws {
        if screen.id == failOn { throw ApplyError.couldNotSet(screen: screen.name, reason: "test") }
        set[screen.id] = file
    }

    func currentImages() -> Set<URL> { Set(set.values) }
}

@MainActor
final class WallpaperApplierTests: XCTestCase {
    private var directory: URL!
    private var host: String!

    private let laptop = DesktopScreen(id: "1", name: "Built-in Display", size: CGSize(width: 1512, height: 982))
    private let monitor = DesktopScreen(id: "2", name: "Studio Display", size: CGSize(width: 2560, height: 1440))

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperApplierTests-\(UUID().uuidString)", isDirectory: true)
        host = "img-\(UUID().uuidString.lowercased()).test"
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var png: Data {
        get throws {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample-001-16x9", withExtension: "png"))
            return try Data(contentsOf: url)
        }
    }

    private func quote(_ keys: [String] = ["16x10", "16x9"]) -> Quote {
        var wallpapers: [String: URL] = [:]
        for key in keys { wallpapers[key] = URL(string: "https://\(host!)/q/a/\(key).png")! }
        return Quote(id: "a", number: "No. 001", text: "t", author: "", source: "", language: .english,
                     url: nil, wallpapers: wallpapers)
    }

    private func applier(_ desktop: FakeDesktop) -> WallpaperApplier {
        WallpaperApplier(desktop: desktop, cache: WallpaperCache(directory: directory, session: StubURLProtocol.session()))
    }

    func testEachScreenGetsItsClosestRatio() async throws {
        StubURLProtocol.stub(host: host, .data(try png))
        let desktop = FakeDesktop([laptop, monitor])
        let plans = try await applier(desktop).apply(quote())
        XCTAssertEqual(plans.map(\.ratioKey), ["16x10", "16x9"])
        XCTAssertTrue(desktop.set["1"]!.lastPathComponent.hasPrefix("a-16x10-"))
        XCTAssertTrue(desktop.set["2"]!.lastPathComponent.hasPrefix("a-16x9-"))
        XCTAssertTrue(desktop.set.values.allSatisfy { $0.path.hasPrefix(self.directory.path) })
        XCTAssertTrue(desktop.set.values.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    func testScreensSharingARatioShareOneDownload() async throws {
        StubURLProtocol.stub(host: host, .data(try png))
        let other = DesktopScreen(id: "3", name: "LG", size: CGSize(width: 3840, height: 2160))
        let desktop = FakeDesktop([monitor, other])
        try await applier(desktop).apply(quote())
        XCTAssertEqual(StubURLProtocol.requestCount(host: host), 1)
        XCTAssertEqual(desktop.set["2"], desktop.set["3"])
    }

    func testCachedFilesAreReused() async throws {
        StubURLProtocol.stub(host: host, .data(try png))
        try await applier(FakeDesktop([monitor])).apply(quote())
        StubURLProtocol.stub(host: host, .failure(.notConnectedToInternet))
        let desktop = FakeDesktop([monitor])
        try await applier(desktop).apply(quote())
        XCTAssertNotNil(desktop.set["2"], "Applying a cached wallpaper works offline")
        XCTAssertEqual(StubURLProtocol.requestCount(host: host), 1)
    }

    func testOfflineChangesNothing() async {
        StubURLProtocol.stub(host: host, .failure(.notConnectedToInternet))
        let desktop = FakeDesktop([laptop, monitor])
        await assertThrows(.offline) { try await self.applier(desktop).apply(self.quote()) }
        XCTAssertTrue(desktop.set.isEmpty)
    }

    func testFailedDownloadChangesNoScreen() async throws {
        StubURLProtocol.stub(host: host, .data(Data("Not found".utf8), status: 404))
        let desktop = FakeDesktop([laptop, monitor])
        await assertThrows(.downloadFailed("HTTP 404")) { try await self.applier(desktop).apply(self.quote()) }
        XCTAssertTrue(desktop.set.isEmpty)
        let saved = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        XCTAssertTrue(saved.isEmpty, "Nothing is cached from a failed download")
    }

    func testANonImageResponseIsAFailedDownload() async {
        StubURLProtocol.stub(host: host, .data(Data("<html>captive portal</html>".utf8)))
        let desktop = FakeDesktop([monitor])
        await assertThrows(.downloadFailed("not an image")) { try await self.applier(desktop).apply(self.quote()) }
        XCTAssertTrue(desktop.set.isEmpty)
    }

    func testNoScreens() async {
        await assertThrows(.noScreens) { try await self.applier(FakeDesktop([])).apply(self.quote()) }
    }

    func testQuoteWithoutWallpapers() async {
        await assertThrows(.noWallpaper) { try await self.applier(FakeDesktop([self.monitor])).apply(self.quote([])) }
    }

    func testMacOSRefusingIsReported() async throws {
        StubURLProtocol.stub(host: host, .data(try png))
        let desktop = FakeDesktop([monitor])
        desktop.failOn = "2"
        await assertThrows(.couldNotSet(screen: "Studio Display", reason: "test")) {
            try await self.applier(desktop).apply(self.quote())
        }
    }

    func testPruneKeepsWallpapersInUseAndRecentFiles() throws {
        let cache = WallpaperCache(directory: directory, session: StubURLProtocol.session())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let old = directory.appendingPathComponent("old.png")
        let inUse = directory.appendingPathComponent("in-use.png")
        let recent = directory.appendingPathComponent("recent.png")
        for file in [old, inUse, recent] { try Data([1]).write(to: file) }
        let longAgo = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        for file in [old, inUse] {
            try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: file.path)
        }
        cache.prune(keeping: [inUse])
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inUse.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func testANewURLGetsANewFileName() {
        let cache = WallpaperCache(directory: directory, session: .shared)
        let a = cache.fileURL(quoteID: "q/../x", ratioKey: "16x9", remote: URL(string: "https://a/v1.png")!)
        let b = cache.fileURL(quoteID: "q/../x", ratioKey: "16x9", remote: URL(string: "https://a/v2.png")!)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL,
                       "Quote ids can't escape the cache folder")
    }

    private func assertThrows(_ expected: ApplyError, _ body: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ApplyError, expected, file: file, line: line)
        }
    }
}
