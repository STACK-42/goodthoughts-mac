import CryptoKit
import Foundation
import ImageIO

/// Downloads wallpaper PNGs into Application Support and reuses them.
/// Each file is named after the quote, the ratio and a hash of its URL, so a redesigned
/// wallpaper at a new URL gets a new file and macOS doesn't keep showing a stale one.
struct WallpaperCache: Sendable {
    let directory: URL
    let session: URLSession

    static func standard() -> WallpaperCache {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        return WallpaperCache(
            directory: AppSupport.directory.appendingPathComponent("wallpapers", isDirectory: true),
            session: URLSession(configuration: configuration)
        )
    }

    func fileURL(quoteID: String, ratioKey: String, remote: URL) -> URL {
        let digest = SHA256.hash(data: Data(remote.absoluteString.utf8))
        let hash = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
        let safeID = quoteID.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "-" ? String($0) : "_" }
            .joined()
            .prefix(80)
        return directory.appendingPathComponent("\(safeID)-\(ratioKey)-\(hash).png")
    }

    /// Returns a local file for the wallpaper, downloading it unless it's already cached.
    func file(quoteID: String, ratioKey: String, remote: URL) async throws -> URL {
        let local = fileURL(quoteID: quoteID, ratioKey: ratioKey, remote: remote)
        if Self.isImage(at: local) { return local }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: remote)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw ApplyError.offline
        } catch {
            throw ApplyError.downloadFailed(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ApplyError.downloadFailed("HTTP \(http.statusCode)")
        }
        guard Self.isImage(data) else { throw ApplyError.downloadFailed("not an image") }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: local, options: .atomic)
        } catch {
            throw ApplyError.downloadFailed("couldn't save: \(error.localizedDescription)")
        }
        return local
    }

    /// Deletes cached wallpapers older than `age` that aren't in `keep` (the ones on screen now).
    func prune(olderThan age: TimeInterval = 14 * 24 * 60 * 60, keeping keep: Set<URL>, now: Date = .now) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let kept = Set(keep.map { $0.standardizedFileURL.path })
        for file in files where !kept.contains(file.standardizedFileURL.path) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, now.timeIntervalSince(modified) > age {
                try? fm.removeItem(at: file)
            }
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed,
    ]

    static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0 && CGImageSourceGetType(source) != nil
    }

    static func isImage(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), !data.isEmpty else { return false }
        return isImage(data)
    }
}
