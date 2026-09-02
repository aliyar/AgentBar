import SwiftUI
import AgentBarKit

/// v1 settings: agents shown, gauge on/off, Dock on/off, launch at login, updates.
/// Dock and launch at login arrive with their features.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UpdateController.self) private var updates

    var body: some View {
        @Bindable var settings = settings
        @Bindable var updates = updates
        Form {
            Section("Menu Bar") {
                Toggle("Show the fullest window as a percentage", isOn: $settings.gaugeEnabled)
                Text("Off, the menu bar shows the AgentBar symbol instead.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Agents") {
                ForEach(Agent.allCases) { agent in
                    Toggle(isOn: Binding(get: { settings.isEnabled(agent) }, set: { settings.setEnabled(agent, $0) })) {
                        HStack {
                            Text(agent.title)
                            if !agent.isInstalled {
                                Text("not installed")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(!agent.isInstalled)
                }
                Text("AgentBar reads each agent's own files under its folder in your home directory. Nothing is sent anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecksForUpdates)
                    .disabled(!updates.isStarted)
                LabeledContent("Version", value: updates.currentVersion)
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .navigationTitle("AgentBar Settings")
    }
}

#Preview {
    SettingsView().environment(AppSettings()).environment(UpdateController())
}
