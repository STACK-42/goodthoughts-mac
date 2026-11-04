import Foundation

/// Works out which quote belongs to a day: days since a fixed epoch, counted on the
/// local calendar date, modulo the number of quotes, in feed order. Every Mac shows the
/// same quote on the same local date, with no server involved.
enum DailyPick {
    /// Day 0. Changing it shifts every Mac's quote, so don't.
    static let epoch = CivilDate(year: 2026, month: 1, day: 1)

    /// Gregorian whatever the user's calendar setting, so a Mac set to the Islamic or
    /// Japanese calendar still lands on the same day number as everyone else.
    static func calendar(in timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Days from the epoch to the local date of `date` in `timeZone`. Negative before the epoch.
    static func dayNumber(for date: Date, in timeZone: TimeZone = .current) -> Int {
        let parts = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        let local = CivilDate(year: parts.year ?? epoch.year, month: parts.month ?? 1, day: parts.day ?? 1)
        return local.daysSinceUnixEpoch - epoch.daysSinceUnixEpoch
    }

    /// The index into the feed's quotes for a day number, or nil when there are no quotes.
    static func index(forDay day: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let remainder = day % count
        return remainder >= 0 ? remainder : remainder + count
    }

    static func index(for date: Date, count: Int, in timeZone: TimeZone = .current) -> Int? {
        index(forDay: dayNumber(for: date, in: timeZone), count: count)
    }
}

/// A calendar date with no time or time zone.
struct CivilDate: Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// Days since 1970-01-01 in the proleptic Gregorian calendar (Howard Hinnant's
    /// days_from_civil). Pure arithmetic, so daylight-saving days of 23 or 25 hours
    /// can't throw the count off.
    var daysSinceUnixEpoch: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
