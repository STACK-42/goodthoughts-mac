import XCTest
@testable import GoodThoughts

@MainActor
final class UpdaterTests: XCTestCase {
    private func info(_ key: String) -> Any? { Bundle.main.object(forInfoDictionaryKey: key) }

    func testFeedIsTheLatestGitHubReleaseAppcastOverHTTPS() throws {
        let feed = try XCTUnwrap(info("SUFeedURL") as? String)
        XCTAssertEqual(feed, "https://github.com/STACK-42/goodthoughts-mac/releases/latest/download/appcast.xml")
    }

    func testPublicKeyIsAnEd25519Key() throws {
        let key = try XCTUnwrap(info("SUPublicEDKey") as? String)
        let bytes = try XCTUnwrap(Data(base64Encoded: key), "SUPublicEDKey isn't base64")
        XCTAssertEqual(bytes.count, 32, "An Ed25519 public key is 32 bytes")
    }

    func testSandboxedInstallIsEnabled() {
        XCTAssertEqual(info("SUEnableInstallerLauncherService") as? Bool, true,
                       "A sandboxed app can't install updates without Sparkle's installer service")
        XCTAssertEqual(info("SUEnableAutomaticChecks") as? Bool, true)
    }

    func testVersionsAreComparable() throws {
        let build = try XCTUnwrap(info("CFBundleVersion") as? String)
        XCTAssertNotNil(build.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression),
                        "Sparkle compares CFBundleVersion; keep it numeric like 1.2.0")
    }

    func testUnitTestsDoNotStartTheUpdater() {
        XCTAssertFalse(Updater().isAvailable)
    }
}
