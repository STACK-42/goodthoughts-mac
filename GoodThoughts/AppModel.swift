import Foundation

/// App state shared by the menu bar label and the popover.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready(LoadedFeed)
        case failed(FeedError)
    }

    /// Reload at most this often when the popover opens.
    static let refreshInterval: TimeInterval = 60 * 60

    @Published private(set) var phase: Phase = .loading
    /// The moment "today" was last worked out. Moves forward on refresh.
    @Published private(set) var now: Date = .now

    private let loader: FeedLoader
    private var lastLoaded: Date?
    private var isLoading = false

    init(loader: FeedLoader = .standard()) {
        self.loader = loader
    }

    var feed: LoadedFeed? {
        if case .ready(let loaded) = phase { return loaded }
        return nil
    }

    var todayNumber: Int { DailyPick.dayNumber(for: now) }

    func quote(forDay day: Int) -> Quote? {
        guard let quotes = feed?.feed.quotes,
              let index = DailyPick.index(forDay: day, count: quotes.count) else { return nil }
        return quotes[index]
    }

    var todaysQuote: Quote? { quote(forDay: todayNumber) }

    /// Loads the feed unless it was loaded recently. `force` always reloads.
    func refresh(force: Bool = false) async {
        now = .now
        if !force, let lastLoaded, Date.now.timeIntervalSince(lastLoaded) < Self.refreshInterval { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await loader.load()
            phase = .ready(loaded)
            lastLoaded = .now
        } catch let error as FeedError {
            // Keep showing what we had if a reload fails.
            if feed == nil { phase = .failed(error) }
        } catch {
            if feed == nil { phase = .failed(.unavailable(error.localizedDescription)) }
        }
    }
}
