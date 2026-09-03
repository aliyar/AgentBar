import AppKit
import AgentBarKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDependencies.bootstrap()
        NSApp.mainMenu = MainMenu.make()
        // The Dock draws a running app's tile from this image, and macOS fills it from an
        // icon cache that lags behind a changed icon by days. The asset catalogue is current.
        if let icon = NSImage(named: "AppIcon") { NSApp.applicationIconImage = icon }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only until `start()` reads the Dock setting and flips this to `.regular`.
        NSApp.setActivationPolicy(.accessory)
        AppDependencies.shared.statusItem.install()
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        AppDependencies.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// A click on the Dock icon: the popover, off that icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AppDependencies.shared.showPanelFromDock()
        return false
    }

    /// The Dock icon's right-click menu: what a click opens, and Settings.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let settings = AppDependencies.shared.settings
        let menu = NSMenu()
        let opens = NSMenu(title: "Clicking Opens")
        for choice in AppSettings.DockClick.allCases {
            let item = NSMenuItem(title: choice.title, action: #selector(dockSetClick(_:)), keyEquivalent: "")
            item.representedObject = choice.rawValue
            item.state = settings.dockClickOpens == choice ? .on : .off
            opens.addItem(item)
        }
        let parent = NSMenuItem(title: "Clicking Opens", action: nil, keyEquivalent: "")
        parent.submenu = opens
        menu.addItem(parent)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(AppActions.showSettings), keyEquivalent: "")
        return menu
    }

    @objc private func dockSetClick(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let choice = AppSettings.DockClick(rawValue: raw) else { return }
        AppDependencies.shared.settings.dockClickOpens = choice
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
                    AppDependencies.shared.showPanel()
                }
            default:
                AppDependencies.shared.showPanel()
            }
        }
    }
}

extension AppDelegate: AppActions {
    func showSettings() { AppDependencies.shared.settingsWindow.show() }
    func showAbout() { AppDependencies.shared.settingsWindow.show(pane: AgentBarSettingsPane.about) }
    func showMain() { AppDependencies.shared.showPanel() }
}
