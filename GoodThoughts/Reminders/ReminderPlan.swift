import Foundation

/// The time of day the morning reminder goes off, in local time.
struct ReminderTime: Equatable, Sendable {
    static let `default` = ReminderTime(hour: 9, minute: 0)

    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

/// One reminder to schedule: which local date, which quote, and when it fires.
struct PlannedReminder: Equatable, Sendable {
    /// The local calendar date the reminder belongs to.
    let date: CivilDate
    let quote: Quote
    /// The instant it goes off, in the time zone it was planned for.
    let fireDate: Date
    let time: ReminderTime

    /// Stable per date, so rescheduling replaces rather than duplicates.
    var identifier: String { ReminderPlan.identifier(for: date) }

    /// The trigger's wall-clock components. No time zone, so the system fires it at
    /// this local time in whatever zone the Mac is in then.
    var triggerComponents: DateComponents {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: date.year, month: date.month,
                       day: date.day, hour: time.hour, minute: time.minute)
    }
}

/// Which quotes to remind about, for which dates, at what times. Pure, so it can be
/// tested without the notification centre.
enum ReminderPlan {
    static let identifierPrefix = "reminder-"
    static let defaultDays = 7

    static func identifier(for date: CivilDate) -> String {
        String(format: "%@%04d-%02d-%02d", identifierPrefix, date.year, date.month, date.day)
    }

    /// The next `days` reminders at `time`, starting today if that time is still ahead
    /// and tomorrow otherwise. Each date gets the quote `DailyPick` gives that date.
    static func make(quotes: [Quote], now: Date, timeZone: TimeZone, time: ReminderTime,
                     days: Int = defaultDays) -> [PlannedReminder] {
        guard !quotes.isEmpty, days > 0 else { return [] }
        let calendar = DailyPick.calendar(in: timeZone)
        let today = calendar.startOfDay(for: now)
        var plan: [PlannedReminder] = []
        var offset = 0
        // days + 1 candidates cover the case where today's time has already passed.
        while plan.count < days, offset <= days {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day,
                  let fire = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth,
                                                                hour: time.hour, minute: time.minute)),
                  fire > now else { continue }
            let dayNumber = DailyPick.dayNumber(for: day, in: timeZone)
            guard let index = DailyPick.index(forDay: dayNumber, count: quotes.count) else { continue }
            plan.append(PlannedReminder(date: CivilDate(year: year, month: month, day: dayOfMonth),
                                        quote: quotes[index], fireDate: fire, time: time))
        }
        return plan
    }
}

/// What a reminder says.
struct ReminderContent: Equatable, Sendable {
    static let urlKey = "url"

    let title: String
    let body: String
    let url: URL?

    /// "No. 009 · Charles F. Glassman", or just the number when there's no author.
    init(quote: Quote) {
        let parts = [quote.number, quote.author].filter { !$0.isEmpty }
        title = parts.isEmpty ? "goodthoughts" : parts.joined(separator: " · ")
        body = quote.text
        url = quote.url
    }

    var userInfo: [String: String] {
        url.map { [Self.urlKey: $0.absoluteString] } ?? [:]
    }
}
