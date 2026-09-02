import OSLog
import AppKit
import SwiftUI
import AgentBarKit

/// Composition root. Created in `applicationWillFinishLaunching`, before any scene exists.
final class AppDependencies {
    private(set) static var shared: AppDependencies!

    let settings: AppSettings
    let model: AgentsModel
    let statusItem: StatusItemController
    let updates: UpdateController
    let loginItem = LoginItemController()
    let settingsWindow: SettingsWindowController

    private init() {
        settings = AppSettings()
        model = AgentsModel()
        statusItem = StatusItemController()
        updates = UpdateController()
        let settings = settings, updates = updates, loginItem = loginItem
        settingsWindow = SettingsWindowController(
            size: SettingsShell<AgentBarSettingsPane, EmptyView>.size,
            minimumSize: SettingsShell<AgentBarSettingsPane, EmptyView>.minimumSize,
            initialPane: AgentBarSettingsPane.general
        ) { selection in
            AnyView(SettingsView(selection: selection).environment(settings).environment(updates).environment(loginItem))
        }
        wire()
    }

    static func bootstrap() {
        guard shared == nil else { return }
        shared = AppDependencies()
    }

    private func wire() {
        let model = model
        let settings = settings
        let updates = updates
        statusItem.symbolName = "gauge.with.dots.needle.33percent"
        statusItem.panelRoot = {
            AnyView(PopoverView().environment(model).environment(settings).environment(updates))
        }
        statusItem.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onPanelOpened = {
            model.isPopoverVisible = true
            model.refresh()
        }
        statusItem.onPanelClosed = { model.isPopoverVisible = false }
    }

    func start() {
        observeSettings()
        observeGauge()
        observeAppearance()
        loginItem.refresh()
        model.start()
        updates.start()
        Log.app.notice("AgentBar started")
    }

    /// Settings flow into the model; the model never reads UserDefaults itself.
    private func observeSettings() {
        let (agents, gauge) = withObservationTracking {
            (settings.agents, settings.gaugeEnabled)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSettings() }
        }
        model.agents = agents
        model.gaugeEnabled = gauge
    }

    /// The user's appearance choice goes to the popover and the Settings window, never through
    /// `NSApp.appearance`: that would drag the status item along and draw a black glyph on a
    /// dark menu bar.
    private func observeAppearance() {
        let appearance = withObservationTracking {
            settings.appearance
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeAppearance() }
        }
        statusItem.appearance = appearance.nsAppearance
        settingsWindow.appearance = appearance.nsAppearance
    }

    /// The status item shows the fullest live window, or the symbol when there is none.
    private func observeGauge() {
        let (snapshot, gauge) = withObservationTracking {
            (model.snapshot, model.gaugeEnabled)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeGauge() }
        }
        if gauge, let worst = snapshot.worstLimit() {
            statusItem.title = Format.percent(worst.percentUsed)
            statusItem.summary = "AgentBar — the fullest window is \(Format.percent(worst.percentUsed)) used (\(worst.agent.title), \(worst.title))"
        } else {
            statusItem.title = nil
            statusItem.summary = snapshot.isEmpty ? "AgentBar — nothing reported yet" : "AgentBar"
        }
    }
}
