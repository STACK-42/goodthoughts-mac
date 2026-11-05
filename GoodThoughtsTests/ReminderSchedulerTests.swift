import XCTest
@testable import GoodThoughts

@MainActor
final class ReminderSchedulerTests: XCTestCase {
    private let quotes: [Quote] = (0..<5).map { i in
        Quote(id: "q\(i)", number: "No. 00\(i)", text: "t\(i)", author: "", source: "", language: .english,
              url: nil, wallpapers: [:])
    }
    private let now = DailyPick.calendar().date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 7))!

    func testSchedulesAWeekAndLeavesOtherNotificationsAlone() async {
        let center = FakeNotificationCenter(foreign: ["someone-else"])
        let status = await ReminderScheduler(center: center)
            .reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertTrue(center.pendingIDs.contains("someone-else"))
    }

    func testReschedulingReplacesRatherThanDuplicates() async {
        let center = FakeNotificationCenter()
        center.seed("reminder-2026-10-01")  // a stale one from an older version's plan
        let scheduler = ReminderScheduler(center: center)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: ReminderTime(hour: 6, minute: 15), now: now)
        XCTAssertEqual(center.pendingIDs.count, 7)
        XCTAssertFalse(center.pendingIDs.contains("reminder-2026-10-01"))
        XCTAssertTrue(center.scheduled.allSatisfy { $0.time == ReminderTime(hour: 6, minute: 15) })
    }

    func testSwitchingFromRepeatsBackToOnceRemovesTheExtras() async {
        let center = FakeNotificationCenter()
        let scheduler = ReminderScheduler(center: center)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: .default,
                                   repeating: ReminderRepeat(everyHours: 3, untilHour: 21), now: now)
        XCTAssertEqual(center.pendingIDs.count, 35)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, repeating: .once, now: now)
        XCTAssertEqual(center.pendingIDs.count, 7)
        XCTAssertTrue(center.scheduled.allSatisfy { $0.time == .default })
    }

    func testTurningItOffRemovesOnlyOurReminders() async {
        let center = FakeNotificationCenter(foreign: ["someone-else"])
        let scheduler = ReminderScheduler(center: center)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        await scheduler.reschedule(enabled: false, quotes: quotes, time: .default, now: now)
        XCTAssertEqual(center.pendingIDs, ["someone-else"])
    }

    func testRefusedPermissionSchedulesNothingAndDoesNotAskAgain() async {
        let center = FakeNotificationCenter(status: .notDetermined, afterRequest: .denied)
        let scheduler = ReminderScheduler(center: center)
        let first = await scheduler.requestPermission()
        XCTAssertEqual(first.status, .denied)
        XCTAssertEqual(center.requestCount, 1)
        _ = await scheduler.requestPermission()
        XCTAssertEqual(center.requestCount, 1, "Never re-prompt once macOS has an answer")
        let status = await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        XCTAssertEqual(status, .denied)
        XCTAssertTrue(center.pendingIDs.isEmpty)
    }

    func testTurningNotificationsOffLaterClearsThePlan() async {
        let center = FakeNotificationCenter()
        let scheduler = ReminderScheduler(center: center)
        await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        center.set(status: .denied)
        let status = await scheduler.reschedule(enabled: true, quotes: quotes, time: .default, now: now)
        XCTAssertEqual(status, .denied)
        XCTAssertTrue(center.pendingIDs.isEmpty)
    }

    func testMacOSRefusingToAskIsReported() async {
        let center = FakeNotificationCenter(status: .notDetermined, requestError: "Notifications are not allowed for this application")
        let result = await ReminderScheduler(center: center).requestPermission()
        XCTAssertEqual(result.status, .notDetermined)
        XCTAssertEqual(result.error, "Notifications are not allowed for this application")
    }
}
