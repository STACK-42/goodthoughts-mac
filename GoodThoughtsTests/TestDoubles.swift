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

/// Holds "scheduled" reminders in memory and plays the permission states.
final class FakeNotificationCenter: NotificationCentering, @unchecked Sendable {
    private let lock = NSLock()
    private var _status: ReminderAuthorization
    private var _statusAfterRequest: ReminderAuthorization
    private var _requestError: String?
    private var _requests = 0
    private var _pending: [String: PlannedReminder?]

    /// `foreign` are other pending notifications that must be left alone.
    init(status: ReminderAuthorization = .authorized, afterRequest: ReminderAuthorization = .authorized,
         requestError: String? = nil, foreign: [String] = []) {
        _status = status
        _statusAfterRequest = afterRequest
        _requestError = requestError
        _pending = Dictionary(uniqueKeysWithValues: foreign.map { ($0, nil) })
    }

    private func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }

    var requestCount: Int { locked { _requests } }
    var pendingIDs: [String] { locked { _pending.keys.sorted() } }
    var scheduled: [PlannedReminder] { locked { _pending.values.compactMap { $0 }.sorted { $0.fireDate < $1.fireDate } } }
    func set(status: ReminderAuthorization) { locked { _status = status } }
    func seed(_ identifier: String) { locked { _pending[identifier] = .some(nil) } }

    func authorization() async -> ReminderAuthorization { locked { _status } }

    func requestAuthorization() async -> String? {
        locked {
            _requests += 1
            if _status == .notDetermined && _requestError == nil { _status = _statusAfterRequest }
            return _requestError
        }
    }

    func pendingIdentifiers() async -> [String] { locked { Array(_pending.keys) } }

    func removePending(_ identifiers: [String]) {
        locked { for id in identifiers { _pending.removeValue(forKey: id) } }
    }

    func schedule(_ reminder: PlannedReminder) async throws {
        locked { _pending[reminder.identifier] = reminder }
    }
}
