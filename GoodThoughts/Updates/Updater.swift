import Combine
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

/// Automatic updates through Sparkle, from the appcast attached to the latest GitHub
/// Release (SUFeedURL in project.yml). Each update is checked against the EdDSA
/// public key in Info.plist (SUPublicEDKey) before it's installed.
///
/// Sparkle comes in through Swift Package Manager in the Xcode build. The Command
/// Line Tools build in scripts/run.sh can't link packages, so there the updater is
/// simply absent and `isAvailable` is false.
@MainActor
final class Updater: ObservableObject {
    @Published private(set) var canCheck = false

    #if canImport(Sparkle)
    private let controller: SPUStandardUpdaterController?
    private let userDriverDelegate = GentleReminders()
    #endif

    init() {
        #if canImport(Sparkle)
        // Unit tests run inside the app; don't let them start background update checks.
        guard !Self.isRunningTests else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)
        self.controller = controller
        // As in Sparkle's SwiftUI guide: mirror canCheckForUpdates for the Updates link.
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        #endif
    }

    var isAvailable: Bool {
        #if canImport(Sparkle)
        return controller != nil
        #else
        return false
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

#if canImport(Sparkle)
/// A menu bar app has no Dock icon to badge, so Sparkle is told that scheduled update
/// alerts may appear quietly instead of jumping in front of whatever the user is doing.
private final class GentleReminders: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
#endif
