import Foundation

/// The few settings the app keeps, in UserDefaults.
@MainActor
final class Preferences {
    private enum Key {
        static let applyDaily = "applyDaily"
        static let lastAutoAppliedDay = "lastAutoAppliedDay"
        static let reminderEnabled = "reminderEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var applyDaily: Bool {
        get { defaults.bool(forKey: Key.applyDaily) }
        set { defaults.set(newValue, forKey: Key.applyDaily) }
    }

    /// The `DailyPick` day number last applied automatically, so it happens once a day.
    var lastAutoAppliedDay: Int? {
        get { defaults.object(forKey: Key.lastAutoAppliedDay) as? Int }
        set { defaults.set(newValue, forKey: Key.lastAutoAppliedDay) }
    }

    /// The morning reminder notification. Off by default.
    var reminderEnabled: Bool {
        get { defaults.bool(forKey: Key.reminderEnabled) }
        set { defaults.set(newValue, forKey: Key.reminderEnabled) }
    }

    /// When the reminder goes off. 09:00 until changed.
    var reminderTime: ReminderTime {
        get {
            guard let hour = defaults.object(forKey: Key.reminderHour) as? Int,
                  let minute = defaults.object(forKey: Key.reminderMinute) as? Int else { return .default }
            return ReminderTime(hour: hour, minute: minute)
        }
        set {
            defaults.set(newValue.hour, forKey: Key.reminderHour)
            defaults.set(newValue.minute, forKey: Key.reminderMinute)
        }
    }
}
