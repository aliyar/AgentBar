import Foundation
import Observation
import OSLog
import ServiceManagement

/// Launch at login through `SMAppService` (macOS 13+). The system may ask the user to
/// approve the app in System Settings › Login Items; `requiresApproval` says so.
@Observable
final class LoginItemController {
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var lastError: String?

    var isEnabled: Bool {
        get { status == .enabled }
        set { newValue ? register() : unregister() }
    }

    var requiresApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func register() {
        do {
            try SMAppService.mainApp.register()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            Log.app.error("login item register failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func unregister() {
        do {
            try SMAppService.mainApp.unregister()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
