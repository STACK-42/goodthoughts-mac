import ServiceManagement
import XCTest
@testable import GoodThoughts

@MainActor
final class AutomationTests: XCTestCase {
    private var feedHost: String!
    private var imageHost: String!
    private var directory: URL!
    private var suiteName: String!
    private var clock: TestClock!
    private var desktop: FakeDesktop!
    private var login: FakeLoginItem!
    private var notifications: FakeNotificationCenter!

    override func setUp() async throws {
        let id = UUID().uuidString.lowercased()
        feedHost = "feed-\(id).test"
        imageHost = "img-\(id).test"
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("AutomationTests-\(id)")
        suiteName = "AutomationTests-\(id)"
        // Noon, so adding days never lands on a daylight-saving edge.
        let noon = DailyPick.calendar().date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        clock = TestClock(noon)
        desktop = FakeDesktop([DesktopScreen(id: "1", name: "Display", size: CGSize(width: 1920, height: 1080))])
        login = FakeLoginItem()
        notifications = FakeNotificationCenter(status: .notDetermined)

        let quotes = (0..<5).map { i in
            #"{"id": "q\#(i)", "text": "Quote \#(i)", "wallpapers": {"16x9": "https://\#(imageHost!)/q\#(i).png"}}"#
        }
        let feed = #"{"version": "1.0", "quotes": [\#(quotes.joined(separator: ","))]}"#
        StubURLProtocol.stub(host: feedHost, .data(Data(feed.utf8)))
        let png = try Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample-001-16x9", withExtension: "png")))
        StubURLProtocol.stub(host: imageHost, .data(png))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeModel() -> AppModel {
        let session = StubURLProtocol.session()
        let clock = self.clock!
        return AppModel(
            loader: FeedLoader(feedURL: URL(string: "https://\(feedHost!)/wallpapers.json")!, session: session,
                               cacheDirectory: directory.appendingPathComponent("feed"), sampleFeedURL: nil),
            applier: WallpaperApplier(desktop: desktop, cache: WallpaperCache(directory: directory.appendingPathComponent("img"), session: session)),
            preferences: Preferences(defaults: UserDefaults(suiteName: suiteName)!),
            login: login,
            reminders: ReminderScheduler(center: notifications),
            clock: { clock.now }
        )
    }

    private func appliedFile() -> String? { desktop.set["1"]?.lastPathComponent }

    func testSwitchingOnAppliesTodayRightAway() async {
        let model = makeModel()
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 0, "Off by default")
        await model.setApplyDaily(true)
        XCTAssertEqual(desktop.setCount, 1)
        XCTAssertEqual(model.applyState, .applied(model.todaysQuote!.id))
    }

    func testAppliesOnlyOnceADay() async {
        let model = makeModel()
        await model.setApplyDaily(true)
        await model.dayMayHaveChanged()
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 1)
    }

    func testAppliesTheNewQuoteOnTheNextDay() async {
        let model = makeModel()
        await model.setApplyDaily(true)
        let first = model.todaysQuote!.id
        model.dayOffset = -3
        clock.advance(days: 1)
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 2)
        XCTAssertNotEqual(model.todaysQuote!.id, first)
        XCTAssertTrue(appliedFile()!.hasPrefix(model.todaysQuote!.id + "-"))
        XCTAssertEqual(model.dayOffset, 0, "A new day brings the popover back to today")
    }

    func testDoesNothingWhenSwitchedOff() async {
        let model = makeModel()
        await model.dayMayHaveChanged()
        clock.advance(days: 1)
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 0)
    }

    func testAFailedMorningApplyIsRetried() async throws {
        StubURLProtocol.stub(host: imageHost, .failure(.notConnectedToInternet))
        let model = makeModel()
        await model.setApplyDaily(true)
        XCTAssertEqual(model.applyState, .failed(.offline))
        XCTAssertEqual(desktop.setCount, 0)

        let png = try Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample-001-16x9", withExtension: "png")))
        StubURLProtocol.stub(host: imageHost, .data(png))
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 1)
    }

    func testRelaunchingTheSameDayDoesNotReapply() async {
        await makeModel().setApplyDaily(true)
        let relaunched = makeModel()
        XCTAssertTrue(relaunched.applyDaily, "The setting persists")
        await relaunched.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 1)
    }

    func testSwitchingOffStopsIt() async {
        let model = makeModel()
        await model.setApplyDaily(true)
        await model.setApplyDaily(false)
        clock.advance(days: 1)
        await model.dayMayHaveChanged()
        XCTAssertEqual(desktop.setCount, 1)
    }

    func testOpenAtLogin() {
        let model = makeModel()
        XCTAssertEqual(model.loginItem, .disabled)
        model.setLaunchAtLogin(true)
        XCTAssertEqual(model.loginItem, .enabled)
        model.setLaunchAtLogin(false)
        XCTAssertEqual(model.loginItem, .disabled)
    }

    func testNeverRegisteredCountsAsOffNotUnavailable() {
        // SMAppService.mainApp reports .notFound before the first registration.
        XCTAssertEqual(SystemLoginItem.map(.notFound), .disabled)
        XCTAssertEqual(SystemLoginItem.map(.notRegistered), .disabled)
        XCTAssertEqual(SystemLoginItem.map(.enabled), .enabled)
        XCTAssertEqual(SystemLoginItem.map(.requiresApproval), .requiresApproval)
    }

    func testOpenAtLoginNeedingApproval() {
        login.approvalNeeded = true
        let model = makeModel()
        model.setLaunchAtLogin(true)
        XCTAssertEqual(model.loginItem, .requiresApproval)
        model.openLoginItemsSettings()
        XCTAssertTrue(login.openedSettings)
    }

    func testOpenAtLoginErrorsAreShown() {
        login.failure = NSError(domain: "SMAppServiceErrorDomain", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"])
        let model = makeModel()
        model.setLaunchAtLogin(true)
        XCTAssertEqual(model.loginItem, .disabled)
        XCTAssertEqual(model.loginItemError, "Operation not permitted")
    }

    func testMorningReminderFollowsTheSettings() async {
        let model = makeModel()
        await model.dayMayHaveChanged()
        XCTAssertFalse(model.reminderEnabled, "Off by default")
        XCTAssertEqual(model.reminderTime, .default)
        XCTAssertTrue(notifications.pendingIDs.isEmpty)

        await model.setReminderEnabled(true)
        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertEqual(model.reminderAuthorization, .authorized)
        XCTAssertEqual(notifications.scheduled.count, 7)

        await model.setReminderTime(ReminderTime(hour: 7, minute: 30))
        XCTAssertTrue(notifications.scheduled.allSatisfy { $0.time == ReminderTime(hour: 7, minute: 30) })
        XCTAssertEqual(makeModel().reminderTime, ReminderTime(hour: 7, minute: 30), "The time persists")

        clock.advance(days: 1)
        await model.dayMayHaveChanged()
        XCTAssertEqual(notifications.scheduled.count, 7, "A new day tops the week back up")

        await model.setReminderEnabled(false)
        XCTAssertTrue(notifications.pendingIDs.isEmpty)
    }
}
