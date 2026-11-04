import Foundation

/// The few settings the app keeps, in UserDefaults.
@MainActor
final class Preferences {
    private enum Key {
        static let applyDaily = "applyDaily"
        static let lastAutoAppliedDay = "lastAutoAppliedDay"
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
}
