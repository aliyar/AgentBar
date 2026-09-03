import AppKit
import AgentBarKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDependencies.bootstrap()
        NSApp.mainMenu = MainMenu.make()
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

    /// Deep links from the widget: `agentbar://open` shows the panel; `agentbar://focus?pid=N`
    /// brings the app a conversation runs in forward, as clicking its row does.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "agentbar" {
            switch url.host() {
            case "focus":
                let pid = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .first { $0.name == "pid" }?.value.flatMap(Int.init)
                if let pid, let owner = ProcessTree.owningApplicationPID(of: pid),
                   let app = NSRunningApplication(processIdentifier: pid_t(owner)) {
                    app.activate()
                } else {
                    AppDependencies.shared.statusItem.showPopover()
                }
            default:
                AppDependencies.shared.statusItem.showPopover()
            }
        }
    }
}

extension AppDelegate: AppActions {
    func showSettings() { AppDependencies.shared.settingsWindow.show() }
    func showAbout() { AppDependencies.shared.settingsWindow.show(pane: AgentBarSettingsPane.about) }
}
