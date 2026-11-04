import Foundation

/// App state shared by the menu bar label and the popover.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready(LoadedFeed)
        case failed(FeedError)
    }

    enum ApplyState: Equatable {
        case idle
        case applying
        /// The quote id that was applied.
        case applied(String)
        case failed(ApplyError)
    }

    /// Reload at most this often when the popover opens.
    static let refreshInterval: TimeInterval = 60 * 60

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var applyState: ApplyState = .idle
    /// Days from today the popover is showing. 0 is today.
    @Published var dayOffset = 0
    /// The moment "today" was last worked out. Moves forward on refresh.
    @Published private(set) var now: Date
    /// Set today's wallpaper automatically on the first chance each day.
    @Published private(set) var applyDaily: Bool
    @Published private(set) var loginItem: LoginItemStatus
    @Published private(set) var loginItemError: String?

    private let loader: FeedLoader
    private let applier: WallpaperApplier
    private let preferences: Preferences
    private let login: LoginItemControlling
    private let clock: @Sendable () -> Date
    private var lastLoaded: Date?
    private var isLoading = false
    private var watcher: DayWatcher?

    init(loader: FeedLoader = .standard(),
         applier: WallpaperApplier = WallpaperApplier(desktop: SystemDesktop(), cache: .standard()),
         preferences: Preferences = Preferences(),
         login: LoginItemControlling = SystemLoginItem(),
         clock: @escaping @Sendable () -> Date = { Date() }) {
        self.loader = loader
        self.applier = applier
        self.preferences = preferences
        self.login = login
        self.clock = clock
        now = clock()
        applyDaily = preferences.applyDaily
        loginItem = login.status
    }

    // MARK: Days and quotes

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

    /// The calendar date of a day number, for labels.
    func date(forDay day: Int) -> Date {
        DailyPick.calendar().date(byAdding: .day, value: day - todayNumber, to: now) ?? now
    }

    // MARK: Loading

    /// Loads the feed unless it was loaded recently. `force` always reloads.
    func refresh(force: Bool = false) async {
        now = clock()
        if !force, let lastLoaded, now.timeIntervalSince(lastLoaded) < Self.refreshInterval { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await loader.load()
            phase = .ready(loaded)
            lastLoaded = clock()
        } catch let error as FeedError {
            // Keep showing what we had if a reload fails.
            if feed == nil { phase = .failed(error) }
        } catch {
            if feed == nil { phase = .failed(.unavailable(error.localizedDescription)) }
        }
    }

    // MARK: Applying

    /// The wallpaper image file shown in the popover's preview.
    func previewFile(for quote: Quote) async -> (file: URL, ratio: AspectRatio)? {
        try? await applier.previewFile(for: quote)
    }

    /// Downloads the quote's wallpaper and sets it on every screen (current Space only).
    @discardableResult
    func apply(_ quote: Quote) async -> Bool {
        guard applyState != .applying else { return false }
        applyState = .applying
        do {
            try await applier.apply(quote)
            applyState = .applied(quote.id)
            return true
        } catch let error as ApplyError {
            applyState = .failed(error)
        } catch {
            applyState = .failed(.downloadFailed(error.localizedDescription))
        }
        return false
    }

    // MARK: Daily automation

    /// Starts watching for the date changing, the Mac waking and the time zone changing.
    func startWatching() {
        guard watcher == nil else { return }
        let watcher = DayWatcher { [weak self] in await self?.dayMayHaveChanged() }
        watcher.start()
        self.watcher = watcher
    }

    /// Called at launch, at midnight, on wake, on a time zone change and every half hour.
    /// Moves "today" forward, reloads the feed on a new day, and applies the day's
    /// wallpaper if that's switched on and hasn't happened yet today.
    func dayMayHaveChanged() async {
        let previousDay = todayNumber
        now = clock()
        let newDay = todayNumber != previousDay
        if newDay { dayOffset = 0 }
        await refresh(force: newDay || feed == nil)
        await applyTodayIfDue()
    }

    /// Applies today's quote once per day when daily apply is on. A failure isn't
    /// recorded, so the next trigger tries again.
    func applyTodayIfDue() async {
        guard applyDaily, preferences.lastAutoAppliedDay != todayNumber, let quote = todaysQuote else { return }
        let day = todayNumber
        if await apply(quote) { preferences.lastAutoAppliedDay = day }
    }

    func setApplyDaily(_ enabled: Bool) async {
        applyDaily = enabled
        preferences.applyDaily = enabled
        // Same path as a new day, so it loads the feed first if it hasn't arrived yet.
        if enabled { await dayMayHaveChanged() }
    }

    // MARK: Login item

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            try login.setEnabled(enabled)
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItem = login.status
    }

    func refreshLoginItem() {
        loginItem = login.status
    }

    func openLoginItemsSettings() {
        login.openSettings()
    }
}
