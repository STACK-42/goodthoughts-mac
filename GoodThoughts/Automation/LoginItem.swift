import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// Registered, but the user has to allow it in System Settings › Login Items.
    case requiresApproval
    case unavailable
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
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
