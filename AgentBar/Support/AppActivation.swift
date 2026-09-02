import AppKit
import OSLog

enum AppActivation {
    /// Cooperative activation (macOS 14+). Falls back to the legacy forceful variant when the
    /// cooperative request is refused, which happens for accessory apps that were not the
    /// last-interacted app (e.g. when a menu bar click triggers us).
    static func activate() {
        NSApp.activate()
        if !NSApp.isActive {
            // Deprecated in macOS 14 ("may have no effect"), but still what makes an accessory
            // app's window come forward after a status-item click on macOS 14–26. Called through
            // a selector to avoid the deprecation warning.
            let selector = NSSelectorFromString("activateIgnoringOtherApps:")
            if NSApp.responds(to: selector) {
                NSApp.perform(selector, with: true)
            }
        }
    }

    /// Opens the SwiftUI `Settings` scene and makes sure it is in front of other apps' windows.
    static func openSettings() {
        activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringSettingsToFront()
    }

    static func bringSettingsToFront() {
        Task { @MainActor in
            for _ in 0..<15 {
                if let window = NSApp.windows.first(where: isSettingsWindow) {
                    activate()
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    // Activation can land a tick later; re-assert once.
                    try? await Task.sleep(for: .milliseconds(120))
                    if !NSApp.isActive { activate(); window.makeKeyAndOrderFront(nil) }
                    return
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
            Log.app.notice("settings window not found after opening")
        }
    }

    /// SwiftUI's Settings scene window: identifier "com_apple_SwiftUI_Settings_window" (macOS 13+),
    /// falling back to title/class heuristics.
    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if let id = window.identifier?.rawValue.lowercased(), id.contains("settings") || id.contains("preferences") { return true }
        if window.title.localizedCaseInsensitiveContains("settings") { return true }
        return String(describing: type(of: window)).lowercased().contains("settings")
    }
}
