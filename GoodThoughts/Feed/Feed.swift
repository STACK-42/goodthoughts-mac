import Foundation

/// The wallpaper feed published by the site at `https://goodthoughts.page/wallpapers.json`.
/// See "Feed contract" in CLAUDE.md. Unknown fields are ignored everywhere.
struct Feed: Equatable, Sendable {
    /// The newest major version this build understands.
    static let supportedMajorVersion = 1

    let version: FeedVersion
    let generated: Date?
    let quotes: [Quote]

    /// Decodes a feed. Wallpaper URLs may be relative; they resolve against `baseURL`
    /// (the feed's own URL, or the bundle's resource folder for the sample feed).
    static func decode(_ data: Data, baseURL: URL?) throws -> Feed {
        let decoder = JSONDecoder()
        if let baseURL { decoder.userInfo[.feedBaseURL] = baseURL }
        // Check the version on its own first, so a future major version reports
        // "update the app" even if the rest of its shape no longer matches.
        let envelope: VersionEnvelope
        do {
            envelope = try decoder.decode(VersionEnvelope.self, from: data)
        } catch {
            throw FeedError.invalid(String(describing: error))
        }
        guard envelope.version.major <= supportedMajorVersion else {
            throw FeedError.unsupportedVersion(envelope.version.raw)
        }
        do {
            let body = try decoder.decode(Body.self, from: data)
            return Feed(version: envelope.version, generated: body.generated, quotes: body.quotes)
        } catch {
            throw FeedError.invalid(String(describing: error))
        }
    }

    private struct VersionEnvelope: Decodable {
        let version: FeedVersion
    }

    private struct Body: Decodable {
        let generated: Date?
        let quotes: [Quote]

        enum CodingKeys: String, CodingKey { case generated, quotes }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let stamp = try container.decodeIfPresent(String.self, forKey: .generated)
            generated = stamp.flatMap(Self.parseDate)
            quotes = try container.decode([Quote].self, forKey: .quotes)
        }

        private static func parseDate(_ string: String) -> Date? {
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: string) { return date }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: string)
        }
    }
}

/// `"major.minor"`. The minor number goes up for additions, the major for breaking changes.
struct FeedVersion: Equatable, Sendable, Decodable {
    let raw: String
    let major: Int
    let minor: Int

    init(_ raw: String) throws {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard let first = parts.first, let major = Int(first), major >= 0 else {
            throw FeedError.invalid("Unreadable feed version \"\(raw)\"")
        }
        self.raw = raw
        self.major = major
        self.minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }

    init(from decoder: Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(String.self))
    }
}

struct Quote: Equatable, Sendable, Identifiable, Decodable {
    let id: String
    /// Display string such as "No. 001".
    let number: String
    let text: String
    /// Empty when unknown.
    let author: String
    /// Empty when unknown.
    let source: String
    let language: QuoteLanguage
    let url: URL?
    /// Keyed by aspect ratio name, such as "16x10". Unknown or unreadable entries are kept
    /// out by `AspectRatio`; values that aren't URLs are dropped here.
    let wallpapers: [String: URL]

    enum CodingKeys: String, CodingKey {
        case id, number, text, author, source, lang, url, wallpapers
    }

    init(id: String, number: String, text: String, author: String, source: String,
         language: QuoteLanguage, url: URL?, wallpapers: [String: URL]) {
        self.id = id
        self.number = number
        self.text = text
        self.author = author
        self.source = source
        self.language = language
        self.url = url
        self.wallpapers = wallpapers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = decoder.userInfo[.feedBaseURL] as? URL
        id = try container.decode(String.self, forKey: .id)
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        text = try container.decode(String.self, forKey: .text)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        language = QuoteLanguage(rawValue: try container.decodeIfPresent(String.self, forKey: .lang) ?? "en")
        url = try container.decodeIfPresent(String.self, forKey: .url).flatMap { URL(string: $0) }
        let raw = try container.decodeIfPresent([String: String].self, forKey: .wallpapers) ?? [:]
        wallpapers = raw.compactMapValues { URL(string: $0, relativeTo: base)?.absoluteURL }
    }
}

/// A BCP 47 language code from the feed. Only "en" and "ar" are used today, but an
/// unexpected code still decodes rather than failing the whole feed.
struct QuoteLanguage: RawRepresentable, Equatable, Hashable, Sendable {
    static let english = QuoteLanguage(rawValue: "en")
    static let arabic = QuoteLanguage(rawValue: "ar")

    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue.lowercased() }

    private static let rightToLeft: Set<String> = ["ar", "fa", "he", "ur", "ps", "yi"]

    var isRightToLeft: Bool {
        let base = rawValue.split(separator: "-").first.map(String.init) ?? rawValue
        return Self.rightToLeft.contains(base)
    }
}

enum FeedError: Error, Equatable, LocalizedError {
    /// The feed's major version is newer than this build understands.
    case unsupportedVersion(String)
    case invalid(String)
    case httpStatus(Int)
    /// Couldn't reach the feed and there was nothing cached.
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "Update the app to read the new quote feed."
        case .invalid: "The quote feed couldn't be read."
        case .httpStatus(let code): "The quote feed returned an error (\(code))."
        case .unavailable: "Can't reach goodthoughts. Check your connection."
        }
    }
}

extension CodingUserInfoKey {
    static let feedBaseURL = CodingUserInfoKey(rawValue: "feedBaseURL")!
}
