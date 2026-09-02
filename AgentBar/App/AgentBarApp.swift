import SwiftUI

@main
struct AgentBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // `body` is evaluated before the app delegate's launch callbacks run.
        AppDependencies.bootstrap()
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(AppDependencies.shared.settings)
                .environment(AppDependencies.shared.updates)
        }
        .windowResizability(.contentSize)
    }
}
