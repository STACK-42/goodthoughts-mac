import AppKit

enum ApplyError: Error, Equatable, LocalizedError {
    case noScreens
    case noWallpaper
    case offline
    case downloadFailed(String)
    case couldNotSet(screen: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .noScreens: "No screens found to set the wallpaper on."
        case .noWallpaper: "This quote has no wallpaper yet."
        case .offline: "You're offline. Connect to the internet and try again."
        case .downloadFailed: "The wallpaper couldn't be downloaded. Try again later."
        case .couldNotSet(let screen, _): "macOS wouldn't set the wallpaper on \(screen)."
        }
    }
}

/// A display, as far as applying a wallpaper is concerned.
struct DesktopScreen: Equatable, Sendable {
    let id: String
    let name: String
    /// Any size with the screen's proportions; only the ratio is used.
    let size: CGSize
}

/// The system's desktops. Abstracted so tests can use a fake.
@MainActor
protocol Desktop {
    var screens: [DesktopScreen] { get }
    func setImage(_ file: URL, for screen: DesktopScreen) throws
    func currentImages() -> Set<URL>
}

/// The real desktops, via NSScreen and NSWorkspace.
@MainActor
struct SystemDesktop: Desktop {
    var screens: [DesktopScreen] {
        NSScreen.screens.map { screen in
            DesktopScreen(id: Self.id(of: screen), name: screen.localizedName, size: screen.frame.size)
        }
    }

    func setImage(_ file: URL, for screen: DesktopScreen) throws {
        guard let target = NSScreen.screens.first(where: { Self.id(of: $0) == screen.id }) else {
            throw ApplyError.couldNotSet(screen: screen.name, reason: "screen disconnected")
        }
        // Scale to fill: keep proportions, grow or shrink to cover, and crop the overflow.
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        do {
            try NSWorkspace.shared.setDesktopImageURL(file, for: target, options: options)
        } catch {
            throw ApplyError.couldNotSet(screen: screen.name, reason: error.localizedDescription)
        }
    }

    func currentImages() -> Set<URL> {
        Set(NSScreen.screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0) })
    }

    private static func id(of screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber { return number.stringValue }
        return screen.localizedName
    }
}

/// Sets a quote's wallpaper on every screen. Applies to the current Space only:
/// macOS has no public API for the others (see CLAUDE.md).
@MainActor
struct WallpaperApplier {
    let desktop: Desktop
    let cache: WallpaperCache

    struct Plan: Equatable {
        let screen: DesktopScreen
        let ratioKey: String
        let remote: URL
    }

    /// Which wallpaper each screen gets. Throws before anything is downloaded or changed.
    func plan(for quote: Quote) throws -> [Plan] {
        let screens = desktop.screens
        guard !screens.isEmpty else { throw ApplyError.noScreens }
        return try screens.map { screen in
            guard let key = AspectRatio.closestKey(to: screen.size, among: quote.wallpapers.keys),
                  let remote = quote.wallpapers[key] else { throw ApplyError.noWallpaper }
            return Plan(screen: screen, ratioKey: key, remote: remote)
        }
    }

    /// The cached wallpaper file for the main screen (the one with the menu bar), for the preview.
    func previewFile(for quote: Quote) async throws -> (file: URL, ratio: AspectRatio) {
        let size = desktop.screens.first?.size ?? CGSize(width: 16, height: 10)
        guard let key = AspectRatio.closestKey(to: size, among: quote.wallpapers.keys),
              let remote = quote.wallpapers[key], let ratio = AspectRatio(key) else { throw ApplyError.noWallpaper }
        let file = try await cache.file(quoteID: quote.id, ratioKey: key, remote: remote)
        return (file, ratio)
    }

    /// Downloads everything first and only then changes the desktops, so a failed
    /// download never leaves one screen updated and another not.
    @discardableResult
    func apply(_ quote: Quote) async throws -> [Plan] {
        let plans = try plan(for: quote)
        var files: [URL: URL] = [:]
        for remote in Set(plans.map(\.remote)) {
            let key = plans.first { $0.remote == remote }!.ratioKey
            files[remote] = try await cache.file(quoteID: quote.id, ratioKey: key, remote: remote)
        }
        for plan in plans {
            try desktop.setImage(files[plan.remote]!, for: plan.screen)
        }
        cache.prune(keeping: desktop.currentImages().union(files.values))
        return plans
    }
}
