import XCTest
@testable import GoodThoughts

final class DailyPickTests: XCTestCase {
    private func zone(_ id: String) -> TimeZone { TimeZone(identifier: id)! }

    /// A wall-clock time in a given zone.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0,
                      in tz: String) -> Date {
        let components = DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)
        return DailyPick.calendar(in: zone(tz)).date(from: components)!
    }

    func testEpochIsDayZero() {
        XCTAssertEqual(DailyPick.dayNumber(for: date(2026, 1, 1, in: "UTC"), in: zone("UTC")), 0)
        XCTAssertEqual(DailyPick.dayNumber(for: date(2026, 1, 2, in: "UTC"), in: zone("UTC")), 1)
        XCTAssertEqual(DailyPick.dayNumber(for: date(2026, 11, 4, in: "UTC"), in: zone("UTC")), 307)
        XCTAssertEqual(DailyPick.dayNumber(for: date(2025, 12, 31, in: "UTC"), in: zone("UTC")), -1)
    }

    func testCivilDateMatchesKnownDays() {
        XCTAssertEqual(CivilDate(year: 1970, month: 1, day: 1).daysSinceUnixEpoch, 0)
        XCTAssertEqual(CivilDate(year: 2000, month: 3, day: 1).daysSinceUnixEpoch, 11_017)
        XCTAssertEqual(CivilDate(year: 2028, month: 2, day: 29).daysSinceUnixEpoch
                       - CivilDate(year: 2028, month: 2, day: 28).daysSinceUnixEpoch, 1)
        XCTAssertEqual(CivilDate(year: 2028, month: 3, day: 1).daysSinceUnixEpoch
                       - CivilDate(year: 2028, month: 2, day: 29).daysSinceUnixEpoch, 1)
    }

    func testRollsOverAtLocalMidnight() {
        let tz = "Asia/Qatar"
        let beforeMidnight = date(2026, 11, 4, 23, 59, 59, in: tz)
        let atMidnight = date(2026, 11, 5, 0, 0, 0, in: tz)
        let today = DailyPick.dayNumber(for: beforeMidnight, in: zone(tz))
        XCTAssertEqual(DailyPick.dayNumber(for: atMidnight, in: zone(tz)), today + 1)
        XCTAssertEqual(DailyPick.dayNumber(for: date(2026, 11, 4, 0, 0, 0, in: tz), in: zone(tz)), today)
        XCTAssertNotEqual(DailyPick.index(for: beforeMidnight, count: 60, in: zone(tz)),
                          DailyPick.index(for: atMidnight, count: 60, in: zone(tz)))
    }

    func testSameLocalDateGivesTheSameQuoteInEveryZone() {
        let zones = ["Pacific/Kiritimati", "Asia/Tokyo", "Asia/Qatar", "Europe/London", "America/Los_Angeles",
                     "Pacific/Pago_Pago"]
        let indices = zones.map { tz in
            DailyPick.index(for: date(2026, 11, 4, 9, 30, in: tz), count: 60, in: zone(tz))
        }
        XCTAssertEqual(Set(indices).count, 1, "\(indices)")
    }

    func testTheSameInstantCanBeDifferentDaysInDifferentZones() {
        // 2026-11-04 20:00 UTC is already the 5th in Tokyo but still the 4th in Los Angeles.
        let instant = date(2026, 11, 4, 20, in: "UTC")
        let tokyo = DailyPick.dayNumber(for: instant, in: zone("Asia/Tokyo"))
        let losAngeles = DailyPick.dayNumber(for: instant, in: zone("America/Los_Angeles"))
        XCTAssertEqual(tokyo, losAngeles + 1)
    }

    func testDaylightSavingDaysCountAsOneDayEach() {
        // US clocks go back on 2026-11-01 (a 25-hour day) and forward on 2026-03-08 (23 hours).
        let tz = "America/New_York"
        for (y, m, d) in [(2026, 11, 1), (2026, 3, 8)] {
            let start = DailyPick.dayNumber(for: date(y, m, d, 0, 30, in: tz), in: zone(tz))
            let end = DailyPick.dayNumber(for: date(y, m, d, 23, 30, in: tz), in: zone(tz))
            let next = DailyPick.dayNumber(for: date(y, m, d + 1, 0, 30, in: tz), in: zone(tz))
            XCTAssertEqual(start, end)
            XCTAssertEqual(next, start + 1)
        }
    }

    func testIgnoresTheUsersCalendarSetting() {
        // The pick uses Gregorian dates even when the Mac is set to another calendar.
        let instant = date(2026, 11, 4, in: "Asia/Riyadh")
        let gregorian = DailyPick.dayNumber(for: instant, in: zone("Asia/Riyadh"))
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = zone("Asia/Riyadh")
        XCTAssertEqual(gregorian, 307)
        XCTAssertNotEqual(islamic.component(.year, from: instant), 2026)
    }

    func testIndexIsDayModuloCountInFeedOrder() {
        XCTAssertEqual(DailyPick.index(forDay: 0, count: 60), 0)
        XCTAssertEqual(DailyPick.index(forDay: 59, count: 60), 59)
        XCTAssertEqual(DailyPick.index(forDay: 60, count: 60), 0)
        XCTAssertEqual(DailyPick.index(forDay: 307, count: 60), 7)
    }

    func testDaysBeforeTheEpochWrapToValidIndices() {
        XCTAssertEqual(DailyPick.index(forDay: -1, count: 60), 59)
        XCTAssertEqual(DailyPick.index(forDay: -60, count: 60), 0)
        XCTAssertEqual(DailyPick.index(forDay: -61, count: 60), 59)
    }

    func testCountChangingMovesThePickButStaysInRange() {
        let day = 307
        XCTAssertEqual(DailyPick.index(forDay: day, count: 60), 7)
        XCTAssertEqual(DailyPick.index(forDay: day, count: 61), 2)
        XCTAssertEqual(DailyPick.index(forDay: day, count: 1), 0)
        for count in 1...200 {
            let index = DailyPick.index(forDay: day, count: count)!
            XCTAssertTrue((0..<count).contains(index))
        }
    }

    func testNoQuotesMeansNoPick() {
        XCTAssertNil(DailyPick.index(forDay: 10, count: 0))
    }
}
