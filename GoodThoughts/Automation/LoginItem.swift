import OSLog
import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// Registered, but the user has to allow it in System Settings › Login Items.
    case requiresApproval
}

/// Opening at login. Abstracted so tests don't touch the real login items.
@MainActor
protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSettings()
}

/// The app itself as a login item, through `SMAppService.mainApp` (macOS 13+).
@MainActor
struct SystemLoginItem: LoginItemControlling {
    private static let log = Logger(subsystem: "page.goodthoughts.mac", category: "login-item")

    var status: LoginItemStatus { Self.map(SMAppService.mainApp.status) }

    /// `.notFound` is what the main app reports before it has ever been registered, so
    /// it means "off", not "impossible": treating it as unavailable greyed out the
    /// checkbox and left no way to turn the setting on.
    nonisolated static func map(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: .enabled
        case .notRegistered, .notFound: .disabled
        case .requiresApproval: .requiresApproval
        @unknown default: .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        Self.log.info("Open at login \(enabled ? "on" : "off", privacy: .public); status before: \(service.status.rawValue, privacy: .public)")
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            Self.log.info("Open at login status after: \(service.status.rawValue, privacy: .public)")
        } catch {
            Self.log.error("Open at login failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
