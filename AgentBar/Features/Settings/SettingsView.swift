import SwiftUI
import AgentBarKit

/// AgentBar's panes. v1 settings: agents shown, gauge on/off, Dock on/off, launch at login,
/// updates. Dock and launch at login arrive with their features.
nonisolated enum AgentBarSettingsPane: String, SettingsPane {
    case general, agents, changelog, support, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .agents: "Agents"
        case .changelog: "Changelog"
        case .support: "Support"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .agents: "cpu"
        case .changelog: "list.bullet.rectangle"
        case .support: "questionmark.bubble"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    let selection: SettingsPaneSelection
    @Environment(AppSettings.self) private var settings
    @Environment(UpdateController.self) private var updates
    @Environment(LoginItemController.self) private var loginItem

    static let website = URL(string: "https://agentbar.greatpixels.com")!
    static let supportRows = [
        SupportPane.Row(question: "Have a question?", action: "Visit FAQ", url: website.appending(path: "faq")),
        SupportPane.Row(question: "Need assistance?", action: "Contact Us", url: URL(string: "mailto:support@greatpixels.com")!),
        SupportPane.Row(question: "Found a bug or have an idea?", action: "Share It", url: URL(string: "mailto:support@greatpixels.com?subject=AgentBar%20feedback")!),
    ]

    var body: some View {
        SettingsShell(selection: selection) { (pane: AgentBarSettingsPane) in
            switch pane {
            case .general: general
            case .agents: agents
            case .changelog: ChangelogPane()
            case .support: SupportPane(intro: "Get in touch for any feedback, questions or feature requests.", rows: Self.supportRows)
            case .about: AboutPane(website: Self.website, extra: AnyView(checkForUpdates))
            }
        }
        .onAppear { loginItem.refresh() }
    }

    // MARK: Panes

    @ViewBuilder
    private var general: some View {
        @Bindable var settings = settings
        @Bindable var updates = updates
        @Bindable var loginItem = loginItem
        Section {
            Toggle("Launch at login", isOn: $loginItem.isEnabled)
            if loginItem.requiresApproval {
                LabeledContent {
                    Button("Open Login Items") { loginItem.openSystemSettings() }
                        .controlSize(.small)
                } label: {
                    Text("Approve AgentBar in System Settings › Login Items")
                        .foregroundStyle(.secondary)
                }
            }
            if let error = loginItem.lastError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        } footer: {
            Footnote("AgentBar reads the agents' files only while it runs, and the widget shows what it last read; starting at login keeps both current.")
        }
        Section {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Footnote("For the popover and this window. The menu bar item always follows the menu bar.")
        }
        Section {
            Toggle("Show the fullest window as a percentage", isOn: $settings.gaugeEnabled)
        } header: {
            Text("Menu Bar")
        } footer: {
            Footnote("The menu bar shows how much of the fullest rate-limit window is used, refreshed every minute. Off, it shows the AgentBar symbol.")
        }
        Section {
            Toggle("Check for updates automatically", isOn: $updates.automaticallyChecksForUpdates)
                .disabled(!updates.isStarted)
            checkForUpdates
        } header: {
            Text("Updates")
        }
    }

    @ViewBuilder
    private var agents: some View {
        Section {
            ForEach(Agent.allCases) { agent in
                Toggle(isOn: Binding(get: { settings.isEnabled(agent) }, set: { settings.setEnabled(agent, $0) })) {
                    LabeledContent(agent.title) {
                        if !agent.isInstalled {
                            Text("not installed")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(!agent.isInstalled)
            }
        } footer: {
            Footnote("AgentBar reads each agent's own files under its folder in your home directory (~/.claude, ~/.codex). No account is contacted and nothing is sent anywhere.")
        }
    }

    private var checkForUpdates: some View {
        LabeledContent {
            Button("Check for Updates…") { updates.checkForUpdates() }
                .disabled(!updates.canCheckForUpdates)
        } label: {
            Text(updates.isStarted ? "Version \(updates.currentVersion)" : "Updates are off in this build")
        }
    }
}

#Preview {
    SettingsView(selection: SettingsPaneSelection(initial: AgentBarSettingsPane.general))
        .environment(AppSettings())
        .environment(UpdateController())
        .environment(LoginItemController())
}
