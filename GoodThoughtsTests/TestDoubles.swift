import Foundation
@testable import GoodThoughts

@MainActor
final class FakeDesktop: Desktop {
    var screens: [DesktopScreen]
    var failOn: String?
    private(set) var set: [String: URL] = [:]
    private(set) var setCount = 0

    init(_ screens: [DesktopScreen]) { self.screens = screens }

    func setImage(_ file: URL, for screen: DesktopScreen) throws {
        if screen.id == failOn { throw ApplyError.couldNotSet(screen: screen.name, reason: "test") }
        set[screen.id] = file
        setCount += 1
    }

    func currentImages() -> Set<URL> { Set(set.values) }
}

@MainActor
final class FakeLoginItem: LoginItemControlling {
    var status: LoginItemStatus = .disabled
    var failure: Error?
    var approvalNeeded = false
    private(set) var openedSettings = false

    func setEnabled(_ enabled: Bool) throws {
        if let failure { throw failure }
        status = enabled ? (approvalNeeded ? .requiresApproval : .enabled) : .disabled
    }

    func openSettings() { openedSettings = true }
}

/// A clock tests can move forward.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(days: Int) {
        lock.lock(); defer { lock.unlock() }
        current = DailyPick.calendar().date(byAdding: .day, value: days, to: current)!
    }
}
