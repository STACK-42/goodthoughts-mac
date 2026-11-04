import AppKit
import UserNotifications

/// Whether the app may post notifications, as far as the reminder cares.
enum ReminderAuthorization: Equatable, Sendable {
    /// Never asked.
    case notDetermined
    /// Refused, or turned off later in System Settings.
    case denied
    case authorized
}

/// The parts of the notification centre the reminder uses. Abstracted so tests can
/// use a fake; everything crossing it is a plain value.
protocol NotificationCentering: Sendable {
    func authorization() async -> ReminderAuthorization
    /// Shows the system prompt the first time; afterwards macOS answers without asking.
    /// Returns macOS's error message if it refused to even ask.
    func requestAuthorization() async -> String?
    func pendingIdentifiers() async -> [String]
    func removePending(_ identifiers: [String])
    func schedule(_ reminder: PlannedReminder) async throws
}

/// Local notifications through UNUserNotificationCenter. Nothing is sent anywhere:
/// the system holds the scheduled reminders and fires them on this Mac.
struct SystemNotificationCenter: NotificationCentering {
    private var center: UNUserNotificationCenter { .current() }

    func authorization() async -> ReminderAuthorization {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status: ReminderAuthorization = switch settings.authorizationStatus {
                case .notDetermined: .notDetermined
                case .denied: .denied
                default: .authorized  // authorized, provisional, ephemeral
                }
                continuation.resume(returning: status)
            }
        }
    }

    func requestAuthorization() async -> String? {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { _, error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
    }

    func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    func removePending(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func schedule(_ reminder: PlannedReminder) async throws {
        let text = ReminderContent(quote: reminder.quote)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = text.userInfo
        content.threadIdentifier = "goodthoughts-reminder"
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
}

/// Keeps the next week of reminders scheduled. Calls are queued one after another so
/// two triggers arriving together can't interleave removing and adding.
@MainActor
final class ReminderScheduler {
    private let center: NotificationCentering
    private var queue: Task<Void, Never>?

    init(center: NotificationCentering = SystemNotificationCenter()) {
        self.center = center
    }

    func authorization() async -> ReminderAuthorization {
        await center.authorization()
    }

    /// Asks for permission when it has never been asked. Returns the resulting state,
    /// and macOS's error if it wouldn't ask (for example if it rejects the app's signature).
    func requestPermission() async -> (status: ReminderAuthorization, error: String?) {
        var error: String?
        if await center.authorization() == .notDetermined {
            error = await center.requestAuthorization()
        }
        return (await center.authorization(), error)
    }

    /// Replaces the app's pending reminders with a fresh plan, or clears them when the
    /// reminder is off or not allowed. Other pending notifications are left alone.
    @discardableResult
    func reschedule(enabled: Bool, quotes: [Quote], time: ReminderTime, now: Date,
                    timeZone: TimeZone = .current) async -> ReminderAuthorization {
        let previous = queue
        let center = self.center
        let task = Task<ReminderAuthorization, Never> {
            await previous?.value
            let status = await center.authorization()
            let plan = enabled && status == .authorized
                ? ReminderPlan.make(quotes: quotes, now: now, timeZone: timeZone, time: time) : []
            // Adding a request with an existing identifier replaces it, so only the
            // app's reminders that dropped out of the plan need removing.
            let keep = Set(plan.map(\.identifier))
            let stale = await center.pendingIdentifiers()
                .filter { $0.hasPrefix(ReminderPlan.identifierPrefix) && !keep.contains($0) }
            center.removePending(stale)
            for reminder in plan {
                try? await center.schedule(reminder)
            }
            return status
        }
        queue = Task { _ = await task.value }
        return await task.value
    }
}

/// Opens a reminder's quote page when it's clicked, and shows reminders as banners
/// even while the app is frontmost. Installed at launch.
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ReminderNotificationDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo[ReminderContent.urlKey] as? String
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let link, let url = URL(string: link), url.scheme == "https" {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
