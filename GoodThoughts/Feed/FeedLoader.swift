import Foundation

/// A feed and where it came from.
struct LoadedFeed: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        /// Fresh from goodthoughts.page.
        case network
        /// The last good copy on disk, because the network failed.
        case cache
        /// The sample feed bundled into debug builds, because there was no network and no cache.
        case sample
    }

    let feed: Feed
    let source: Source
    /// Why the network copy wasn't used, when it wasn't.
    let networkError: FeedError?

    /// The site published a feed with a newer major version than this build reads.
    var updateRequired: Bool {
        if case .unsupportedVersion = networkError { return true }
        return false
    }
}

/// Fetches the feed, keeps the last good copy on disk, and falls back to it when offline.
struct FeedLoader: Sendable {
    static let liveURL = URL(string: "https://goodthoughts.page/wallpapers.json")!
    static let requestTimeout: TimeInterval = 15

    let feedURL: URL
    let session: URLSession
    /// Folder for the cached feed. Created on first write.
    let cacheDirectory: URL
    /// Last resort when there's no network and no cache. Set only in debug builds.
    let sampleFeedURL: URL?

    var cacheFile: URL { cacheDirectory.appendingPathComponent("wallpapers.json") }

    static func standard() -> FeedLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout * 2
        configuration.waitsForConnectivity = false
        #if DEBUG
        let sample = Bundle.main.url(forResource: "sample-wallpapers", withExtension: "json")
        #else
        let sample: URL? = nil
        #endif
        return FeedLoader(
            feedURL: liveURL,
            session: URLSession(configuration: configuration),
            cacheDirectory: AppSupport.directory,
            sampleFeedURL: sample
        )
    }

    func load() async throws -> LoadedFeed {
        let networkError: FeedError
        do {
            let data = try await fetch()
            let feed = try Feed.decode(data, baseURL: feedURL)
            try? writeCache(data)
            return LoadedFeed(feed: feed, source: .network, networkError: nil)
        } catch let error as FeedError {
            networkError = error
        } catch {
            networkError = .unavailable(error.localizedDescription)
        }

        if let cached = readCache() {
            return LoadedFeed(feed: cached, source: .cache, networkError: networkError)
        }
        if let sampleFeedURL,
           let data = try? Data(contentsOf: sampleFeedURL),
           let feed = try? Feed.decode(data, baseURL: sampleFeedURL.deletingLastPathComponent()) {
            return LoadedFeed(feed: feed, source: .sample, networkError: networkError)
        }
        throw networkError
    }

    private func fetch() async throws -> Data {
        let request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: Self.requestTimeout)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedError.unavailable(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.httpStatus(http.statusCode)
        }
        return data
    }

    private func readCache() -> Feed? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        // Relative wallpaper URLs in the cached copy still belong to the feed's address.
        return try? Feed.decode(data, baseURL: feedURL)
    }

    private func writeCache(_ data: Data) throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try data.write(to: cacheFile, options: .atomic)
    }
}

enum AppSupport {
    /// `~/Library/Application Support/goodthoughts`, inside the app's sandbox container.
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("goodthoughts", isDirectory: true)
    }
}
