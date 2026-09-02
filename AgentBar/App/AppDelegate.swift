import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDependencies.bootstrap()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only. The Dock presence (a later milestone) flips this to `.regular`.
        NSApp.setActivationPolicy(.accessory)
        AppDependencies.shared.statusItem.install()
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        AppDependencies.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
