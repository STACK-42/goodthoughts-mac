import AppKit

/// Calls back when the day might have changed: at midnight, when the Mac wakes, when
/// the time zone or clock changes, and every half hour as a backstop (which also
/// retries a morning apply that failed because the Mac was offline).
@MainActor
final class DayWatcher {
    static let backstopInterval: TimeInterval = 30 * 60

    private let onChange: @MainActor () async -> Void
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?

    init(onChange: @escaping @MainActor () async -> Void) {
        self.onChange = onChange
    }

    func start() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observe(center, .NSCalendarDayChanged)
        observe(center, .NSSystemTimeZoneDidChange)
        observe(center, .NSSystemClockDidChange)
        observe(workspace, NSWorkspace.didWakeNotification)
        observe(workspace, NSWorkspace.screensDidWakeNotification)

        let timer = Timer(timeInterval: Self.backstopInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        fire()
    }

    func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
        observers.append((center, token))
    }

    private func fire() {
        Task { await onChange() }
    }
}
