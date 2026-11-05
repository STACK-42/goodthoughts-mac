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

/// Whether the reminder comes back later in the day after its first time, and until when.
struct ReminderRepeat: Equatable, Sendable {
    /// The intervals offered in the popover, in hours. 0 is once a day.
    static let choices = [0, 1, 2, 3, 4, 6]
    static let once = ReminderRepeat(everyHours: 0, untilHour: 21)

    /// Hours between reminders; 0 means once a day.
    let everyHours: Int
    /// No repeat fires after this hour, on the hour, so evenings and nights stay quiet.
    let untilHour: Int

    init(everyHours: Int, untilHour: Int) {
        self.everyHours = min(max(everyHours, 0), 12)
        self.untilHour = min(max(untilHour, 0), 23)
    }

    var isOnce: Bool { everyHours == 0 }

    /// The day's reminder times, starting at `start`. A start after `untilHour` still
    /// fires once.
    func times(from start: ReminderTime) -> [ReminderTime] {
        var times = [start]
        guard everyHours > 0 else { return times }
        var hour = start.hour + everyHours
        while hour * 60 + start.minute <= untilHour * 60 {
            times.append(ReminderTime(hour: hour, minute: start.minute))
            hour += everyHours
        }
        return times
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

    /// Stable per date and time, so rescheduling replaces rather than duplicates.
    var identifier: String { ReminderPlan.identifier(for: date, at: time) }

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
    /// macOS keeps at most 64 pending notifications per app and drops the rest, so the
    /// plan stops short of that. The app tops it up every day anyway.
    static let maxPending = 60

    static func identifier(for date: CivilDate, at time: ReminderTime) -> String {
        String(format: "%@%04d-%02d-%02d-%02d%02d", identifierPrefix, date.year, date.month, date.day,
               time.hour, time.minute)
    }

    /// Reminders for the next `days` days that still have one ahead, starting today if
    /// any of today's times is still ahead. Each day's reminders all carry the quote
    /// `DailyPick` gives that date. Never more than `limit` in total.
    static func make(quotes: [Quote], now: Date, timeZone: TimeZone, time: ReminderTime,
                     repeating: ReminderRepeat = .once, days: Int = defaultDays,
                     limit: Int = maxPending) -> [PlannedReminder] {
        guard !quotes.isEmpty, days > 0, limit > 0 else { return [] }
        let calendar = DailyPick.calendar(in: timeZone)
        let today = calendar.startOfDay(for: now)
        let times = repeating.times(from: time)
        var plan: [PlannedReminder] = []
        var daysPlanned = 0
        // days + 1 candidates cover the case where today's times have all passed.
        for offset in 0...days where daysPlanned < days && plan.count < limit {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day,
                  let index = DailyPick.index(forDay: DailyPick.dayNumber(for: day, in: timeZone),
                                              count: quotes.count) else { continue }
            let date = CivilDate(year: year, month: month, day: dayOfMonth)
            let todays = times.compactMap { time -> PlannedReminder? in
                guard let fire = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth,
                                                                    hour: time.hour, minute: time.minute)),
                      fire > now else { return nil }
                return PlannedReminder(date: date, quote: quotes[index], fireDate: fire, time: time)
            }
            guard !todays.isEmpty else { continue }
            plan += todays.prefix(limit - plan.count)
            daysPlanned += 1
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
