import SwiftUI
import AgentBarKit

/// AgentBar's panes. v1 settings: agents shown, gauge on/off, Dock on/off, launch at login,
/// updates. Dock and launch at login arrive with their features.
nonisolated enum AgentBarSettingsPane: String, SettingsPane {
    case general, appearance, menuBar, agents, status, support, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .menuBar: "Menu Bar"
        case .agents: "Agents"
        case .status: "Status"
        case .support: "Support"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .menuBar: "menubar.rectangle"
        case .agents: "cpu"
        case .status: "waveform.path.ecg"
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
    /// Whether macOS will show a message at all, so a switch that cannot do anything says so.
    @State private var notificationsAllowed = true
    /// The row the pointer is over while something is being dragged.
    @State private var dropTarget: PanelSection?

    static let website = URL(string: "https://agentbar.greatpixels.com")!
    static let supportRows = [
        SupportPane.Row(question: "Have a question?", action: "Visit FAQ", url: URL(string: "https://agentbar.greatpixels.com/#faq")!),
        SupportPane.Row(question: "Need assistance?", action: "Contact Us", url: URL(string: "mailto:support@greatpixels.com")!),
        SupportPane.Row(question: "Found a bug or have an idea?", action: "Share It", url: URL(string: "mailto:support@greatpixels.com?subject=AgentBar%20feedback")!),
    ]

    var body: some View {
        SettingsShell(selection: selection) { (pane: AgentBarSettingsPane) in
            switch pane {
            case .general: general
            case .appearance: appearance
            case .menuBar: menuBar
            case .agents: agents
            case .status: serviceStatus
            case .support: SupportPane(intro: "Get in touch for any feedback, questions or feature requests.", rows: Self.supportRows)
            case .about: AboutPane(website: Self.website, extra: AnyView(checkForUpdates))
            }
        }
        .onAppear {
            loginItem.refresh()
            Task { notificationsAllowed = await AppDependencies.shared.notifier.isAllowed() }
        }
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
    }

    /// What the menu bar item shows besides the symbol: which windows as bars, whose time
    /// left beside them. Its own pane: it is a surface of the app, not a matter of how the
    /// panel is painted, and the two together made one pane about two subjects.
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
            ForEach(settings.sectionOrder) { section in
                sectionRow(section)
            }
        } footer: {
            Footnote("What the panel draws, and the order it draws it in. Drag a row by its handle to move it. The menu bar's bars and the widget follow the agents' order too.")
        }
        #if DEBUG
        // A development aid, kept out of what users see.
        Section {
            Toggle("Preview with sample data", isOn: $settings.showsSampleData)
        } footer: {
            Footnote("Shows made-up windows and conversations in the panel and the menu bar, so every row can be seen without waiting for the agents. Nothing is read while it is on.")
        }
        #endif
    }

    /// One block of the panel: its place in the order, whether it is shown, and - for an
    /// agent - whether it is on this Mac at all. The handle is drawn rather than left to
    /// be discovered: a row that can be dragged and does not say so is a row nobody drags.
    @ViewBuilder
    private func sectionRow(_ section: PanelSection) -> some View {
        let installed = section.agent.map(\.isInstalled) ?? true
        Toggle(isOn: Binding(get: { settings.isShown(section) }, set: { settings.setShown(section, $0) })) {
            LabeledContent {
                if !installed {
                    Text("not installed").foregroundStyle(.tertiary)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(section.title)
                }
            }
        }
        .disabled(!installed)
        // The row under the pointer lights up: it says where the one being carried will
        // land before it lands there.
        .padding(.vertical, 1)
        .background(dropTarget == section ? Color.accentColor.opacity(0.16) : .clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .draggable(section.rawValue) {
            Text(section.title).padding(.horizontal, 8).padding(.vertical, 4)
        }
        .dropDestination(for: String.self) { items, _ in
            dropTarget = nil
            guard let moved = items.first.flatMap(PanelSection.init(rawValue:)) else { return false }
            withAnimation(.easeOut(duration: 0.18)) { settings.move(moved, onto: section) }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTarget = section
            } else if dropTarget == section {
                dropTarget = nil
            }
        }
    }

    /// Whether the agents' status pages are read, and who gets told when one changes.
    /// Its own pane: it is about the services behind the agents, not about which agents
    /// the panel draws, and the two together made one pane about two subjects.
    @ViewBuilder
    private var serviceStatus: some View {
        @Bindable var settings = settings
        Section {
            Toggle("Check service status", isOn: $settings.checksStatus)
        } footer: {
            Footnote("Each agent's own status page, read every five minutes and every minute while something is wrong. AgentBar reads the parts you run on (\(Self.watched)), so an outage elsewhere on the page does not raise an alarm. These pages are public: no account is involved and nothing about you is sent.")
        }
        if settings.checksStatus {
            Section {
                Toggle("A service stops working", isOn: $settings.notifiesDown)
                Toggle("It works again", isOn: $settings.notifiesBack)
                if !notificationsAllowed, settings.announcesAnything {
                    LabeledContent {
                        Button("Open Notification Settings") { AppDependencies.shared.notifier.openSystemSettings() }
                            .controlSize(.small)
                    } label: {
                        Text("macOS is not showing AgentBar's notifications")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Tell Me When")
            } footer: {
                Footnote("For every agent shown above. A change is announced once two readings agree, so a moment's flap says nothing; a page that cannot be reached is never reported as an outage; and an outage already under way when AgentBar starts is not announced at all.")
            }
        }
    }

    /// The components each agent is read from, said once in the footer above. What the app
    /// watches should be checkable against the page by reading it.
    private static var watched: String {
        Agent.allCases.map { "\($0.title): \($0.statusComponents.joined(separator: ", "))" }
            .joined(separator: "; ")
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
