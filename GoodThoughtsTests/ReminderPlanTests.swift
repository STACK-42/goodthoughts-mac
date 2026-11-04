import XCTest
@testable import GoodThoughts

final class ReminderPlanTests: XCTestCase {
    private let quotes: [Quote] = (0..<11).map { i in
        Quote(id: "q\(i)", number: String(format: "No. %03d", i + 1), text: "Quote \(i)", author: "Author \(i)",
              source: "", language: .english, url: URL(string: "https://goodthoughts.page/q/q\(i)/"), wallpapers: [:])
    }
    private let nine = ReminderTime.default

    private func zone(_ id: String) -> TimeZone { TimeZone(identifier: id)! }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0, in tz: String) -> Date {
        DailyPick.calendar(in: zone(tz)).date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func local(_ date: Date, _ tz: String) -> DateComponents {
        DailyPick.calendar(in: zone(tz)).dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    private func plan(_ now: Date, _ tz: String, time: ReminderTime? = nil, days: Int = 7) -> [PlannedReminder] {
        ReminderPlan.make(quotes: quotes, now: now, timeZone: zone(tz), time: time ?? nine, days: days)
    }

    func testStartsTodayWhenTheTimeIsStillAhead() {
        let reminders = plan(date(2026, 11, 5, 8, 59, in: "Asia/Qatar"), "Asia/Qatar")
        XCTAssertEqual(reminders.count, 7)
        XCTAssertEqual(reminders.first?.date, CivilDate(year: 2026, month: 11, day: 5))
        XCTAssertEqual(reminders.last?.date, CivilDate(year: 2026, month: 11, day: 11))
        XCTAssertEqual(reminders.first?.identifier, "reminder-2026-11-05")
    }

    func testStartsTomorrowWhenTodaysTimeHasPassed() {
        for (h, m) in [(9, 0), (9, 1), (18, 30)] {
            let reminders = plan(date(2026, 11, 5, h, m, in: "Asia/Qatar"), "Asia/Qatar")
            XCTAssertEqual(reminders.count, 7, "\(h):\(m)")
            XCTAssertEqual(reminders.first?.date, CivilDate(year: 2026, month: 11, day: 6), "\(h):\(m)")
            XCTAssertEqual(reminders.last?.date, CivilDate(year: 2026, month: 11, day: 12), "\(h):\(m)")
        }
    }

    func testDayBoundaries() {
        let tz = "Europe/London"
        XCTAssertEqual(plan(date(2026, 11, 5, 23, 59, 59, in: tz), tz).first?.date, CivilDate(year: 2026, month: 11, day: 6))
        XCTAssertEqual(plan(date(2026, 11, 6, 0, 0, 0, in: tz), tz).first?.date, CivilDate(year: 2026, month: 11, day: 6))
        // A midnight reminder half a minute after midnight waits for the next one.
        let midnight = plan(date(2026, 11, 6, 0, 0, 30, in: tz), tz, time: ReminderTime(hour: 0, minute: 0))
        XCTAssertEqual(midnight.first?.date, CivilDate(year: 2026, month: 11, day: 7))
        // Month and year ends roll over.
        let newYear = plan(date(2026, 12, 29, 10, in: tz), tz)
        XCTAssertEqual(newYear.map(\.identifier), ["reminder-2026-12-30", "reminder-2026-12-31", "reminder-2027-01-01",
                                                   "reminder-2027-01-02", "reminder-2027-01-03", "reminder-2027-01-04",
                                                   "reminder-2027-01-05"])
    }

    func testEveryReminderFiresAtTheChosenLocalTime() {
        let tz = "Asia/Tokyo"
        let reminders = plan(date(2026, 11, 5, 6, in: tz), tz, time: ReminderTime(hour: 7, minute: 45))
        for reminder in reminders {
            let parts = local(reminder.fireDate, tz)
            XCTAssertEqual([parts.hour, parts.minute], [7, 45])
            XCTAssertEqual(CivilDate(year: parts.year!, month: parts.month!, day: parts.day!), reminder.date)
            let trigger = reminder.triggerComponents
            XCTAssertEqual([trigger.year, trigger.month, trigger.day, trigger.hour, trigger.minute],
                           [reminder.date.year, reminder.date.month, reminder.date.day, 7, 45])
            XCTAssertNil(trigger.timeZone, "Triggers follow the Mac's zone at fire time")
        }
    }

    func testDaylightSavingWeeksKeepTheLocalTime() {
        let tz = "America/New_York"
        // Clocks go back on Sunday 2026-11-01 and forward on Sunday 2026-03-08.
        for start in [date(2026, 10, 29, 10, in: tz), date(2026, 3, 5, 10, in: tz)] {
            let reminders = plan(start, tz)
            XCTAssertEqual(reminders.count, 7)
            XCTAssertTrue(reminders.allSatisfy { local($0.fireDate, tz).hour == 9 && local($0.fireDate, tz).minute == 0 })
            let gaps = zip(reminders, reminders.dropFirst()).map { $1.fireDate.timeIntervalSince($0.fireDate) / 3600 }
            XCTAssertEqual(Set(gaps), [24, start < date(2026, 6, 1, in: tz) ? 23 : 25], "\(gaps)")
        }
    }

    func testAgreesWithDailyPickForEveryDate() {
        for tz in ["Asia/Qatar", "America/Los_Angeles", "Pacific/Kiritimati", "Pacific/Pago_Pago"] {
            for reminder in plan(date(2026, 11, 5, 7, in: tz), tz, days: 30) {
                let expected = DailyPick.index(for: reminder.fireDate, count: quotes.count, in: zone(tz))!
                XCTAssertEqual(reminder.quote, quotes[expected], "\(tz) \(reminder.identifier)")
                let civil = CivilDate(year: reminder.date.year, month: reminder.date.month, day: reminder.date.day)
                XCTAssertEqual(DailyPick.dayNumber(for: reminder.fireDate, in: zone(tz)),
                               civil.daysSinceUnixEpoch - DailyPick.epoch.daysSinceUnixEpoch)
            }
        }
    }

    func testIdentifiersAreUniquePerDate() {
        let reminders = plan(date(2026, 11, 5, 7, in: "UTC"), "UTC", days: 7)
        XCTAssertEqual(Set(reminders.map(\.identifier)).count, 7)
        XCTAssertTrue(reminders.allSatisfy { $0.identifier.hasPrefix(ReminderPlan.identifierPrefix) })
    }

    func testEmptyFeedOrNoDaysPlansNothing() {
        XCTAssertEqual(ReminderPlan.make(quotes: [], now: Date(), timeZone: .current, time: nine), [])
        XCTAssertEqual(plan(Date(), "UTC", days: 0), [])
    }

    func testContent() {
        let glassman = Quote(id: "glassman", number: "No. 009", text: "Kindness costs nothing.", author: "Charles F. Glassman",
                             source: "", language: .english, url: URL(string: "https://goodthoughts.page/q/glassman-kindness/"),
                             wallpapers: [:])
        let content = ReminderContent(quote: glassman)
        XCTAssertEqual(content.title, "No. 009 · Charles F. Glassman")
        XCTAssertEqual(content.body, "Kindness costs nothing.")
        XCTAssertEqual(content.userInfo, ["url": "https://goodthoughts.page/q/glassman-kindness/"])

        let arabic = Quote(id: "throat", number: "No. 013", text: "لا يعرف الناس عني غير حنجرة، يا ليتهم عرفوا ما خلف حنجرتي.",
                           author: "", source: "", language: .arabic, url: nil, wallpapers: [:])
        XCTAssertEqual(ReminderContent(quote: arabic).title, "No. 013")
        XCTAssertEqual(ReminderContent(quote: arabic).body, arabic.text)
        XCTAssertEqual(ReminderContent(quote: arabic).userInfo, [:])
    }
}
