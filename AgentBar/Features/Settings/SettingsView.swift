import SwiftUI
import AgentBarKit

/// AgentBar's panes. v1 settings: agents shown, gauge on/off, Dock on/off, launch at login,
/// updates. Dock and launch at login arrive with their features.
nonisolated enum AgentBarSettingsPane: String, SettingsPane {
    case general, appearance, agents, changelog, support, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .agents: "Agents"
        case .changelog: "Changelog"
        case .support: "Support"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
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
    @Environment(AgentsModel.self) private var model

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
            case .appearance: appearance
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
            Picker("Show AgentBar in", selection: $settings.presence) {
                ForEach(AppSettings.Presence.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if settings.presence.inDock {
                Picker("Clicking the Dock icon opens", selection: $settings.dockClickOpens) {
                    ForEach(AppSettings.DockClick.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        } footer: {
            Footnote("The menu bar item, an icon in the Dock and ⌘-Tab, or both. Either opens the same panel; Window › AgentBar (⌘0) opens it in a window.")
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
    private var appearance: some View {
        @Bindable var settings = settings
        Section {
            Picker("Theme", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Footnote("For the popover, the Dock window and this window. The menu bar item follows the menu bar. The widget has its own theme: right-click it and choose Edit “AgentBar”.")
        }
        Section {
            Picker("Style", selection: $settings.panelStyle) {
                ForEach(PanelStyleID.allCases, id: \.self) { id in
                    Text(PanelStyles.style(id).title).tag(id)
                }
            }
        } footer: {
            Footnote("How the panel is drawn. \(PanelStyles.style(settings.panelStyle).summary) Each style has a light and a dark variant; the theme above picks which.")
        }
        // What follows depends on the style: its own options, and only the shared
        // options it honours.
        PanelStyles.style(settings.panelStyle).settings(settings)
        if PanelStyles.style(settings.panelStyle).features.contains(.backgroundOpacity) {
            Section {
                LabeledContent("Background opacity") {
                    HStack(spacing: 10) {
                        Slider(value: $settings.panelOpacity, in: 0...1, step: 0.05)
                            .frame(width: 160)
                        Text(settings.panelOpacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } footer: {
                Footnote("How much of what is behind the panel shows through: 0% leaves only the popover's own blur, 100% is opaque.")
            }
        }
        if PanelStyles.style(settings.panelStyle).features.contains(.resetClock) {
            Section {
                Picker("Show resets as", selection: $settings.showsResetClock) {
                    Text("Time left").tag(false)
                    Text("Clock time").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Windows")
            } footer: {
                Footnote("\"4h 52m\" or \"14:05\". Clicking a time in the panel flips this too.")
            }
        }
        menuBar
    }

    /// What the menu bar item shows besides the symbol: which windows as bars, whose time
    /// left beside them.
    @ViewBuilder
    private var menuBar: some View {
        @Bindable var settings = settings
        let windows = model.snapshot.limits.filter { settings.agents.contains($0.agent) }
        Section {
            Picker("Show", selection: $settings.gaugeEnabled) {
                Text("The AgentBar symbol").tag(false)
                Text("Usage bars and time left").tag(true)
            }
            if settings.gaugeEnabled {
                if windows.isEmpty {
                    Text("Windows appear here once an agent reports them.")
                        .foregroundStyle(.secondary)
                }
                ForEach(windows) { window in
                    Toggle(isOn: Binding(
                        get: { settings.menuBarBars.isEmpty ? window.agent == .claude : settings.menuBarBars.contains(window.id) },
                        set: { on in
                            var chosen = settings.menuBarBars.isEmpty ? windows.filter { $0.agent == .claude }.map(\.id) : settings.menuBarBars
                            if on { if !chosen.contains(window.id) { chosen.append(window.id) } } else { chosen.removeAll { $0 == window.id } }
                            // Kept in the windows' own order, so the bars never reorder.
                            settings.menuBarBars = windows.map(\.id).filter { chosen.contains($0) }
                        }
                    )) {
                        LabeledContent(window.title) { Text(window.agent.title).foregroundStyle(.tertiary) }
                    }
                }
            }
        } header: {
            Text("Menu Bar")
        } footer: {
            Footnote(settings.gaugeEnabled
                ? "A bar per window, filled as it is used and coloured by how full it is, refreshed every minute. Claude's windows by default; turn every bar off and the bars fall back to whatever is reported."
                : "The AgentBar symbol, or a bar per window with the time left on one of them.")
        }
        if settings.gaugeEnabled {
            Section {
                Picker("Time left of", selection: $settings.menuBarTime) {
                    Text("The fullest window shown").tag(AppSettings.MenuBarTime.fullest)
                    ForEach(windows) { window in
                        Text("\(window.title) (\(window.agent.title))").tag(AppSettings.MenuBarTime.window(window.id))
                    }
                    Text("None").tag(AppSettings.MenuBarTime.none)
                }
            } footer: {
                Footnote("Written in that window's colour: green, amber, then red as it fills.")
            }
        }
    }

    @ViewBuilder
    private var agents: some View {
        @Bindable var settings = settings
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
        }
        Section {
            Toggle("Preview with sample data", isOn: $settings.showsSampleData)
        } footer: {
            Footnote("Shows made-up windows and conversations in the panel and the menu bar, so every row can be seen without waiting for the agents. Nothing is read while it is on.")
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
        .environment(AgentsModel())
}
