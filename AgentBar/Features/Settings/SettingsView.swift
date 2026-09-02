import SwiftUI

/// v1 settings: agents shown, gauge on/off, Dock on/off, launch at login, updates.
/// Only the updates section exists yet; the others arrive with their features.
struct SettingsView: View {
    @Environment(UpdateController.self) private var updates

    var body: some View {
        @Bindable var updates = updates
        Form {
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecksForUpdates)
                    .disabled(!updates.isStarted)
                LabeledContent("Version", value: updates.currentVersion)
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .navigationTitle("AgentBar Settings")
    }
}

#Preview {
    SettingsView().environment(UpdateController())
}
