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

    enum ApplyState: Equatable {
        case idle
        case applying
        /// The quote id that was applied.
        case applied(String)
        case failed(ApplyError)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var applyState: ApplyState = .idle
    /// The moment "today" was last worked out. Moves forward on refresh.
    @Published private(set) var now: Date = .now

    private let loader: FeedLoader
    private let applier: WallpaperApplier
    private var lastLoaded: Date?
    private var isLoading = false

    init(loader: FeedLoader = .standard(),
         applier: WallpaperApplier = WallpaperApplier(desktop: SystemDesktop(), cache: .standard())) {
        self.loader = loader
        self.applier = applier
    }

    /// Downloads the quote's wallpaper and sets it on every screen (current Space only).
    func apply(_ quote: Quote) async {
        guard applyState != .applying else { return }
        applyState = .applying
        do {
            try await applier.apply(quote)
            applyState = .applied(quote.id)
        } catch let error as ApplyError {
            applyState = .failed(error)
        } catch {
            applyState = .failed(.downloadFailed(error.localizedDescription))
        }
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
