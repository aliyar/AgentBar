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
        let settings = settings, updates = updates, loginItem = loginItem, model = model
        settingsWindow = SettingsWindowController(
            size: SettingsShell<AgentBarSettingsPane, EmptyView>.size,
            minimumSize: SettingsShell<AgentBarSettingsPane, EmptyView>.minimumSize,
            initialPane: AgentBarSettingsPane.general
        ) { selection in
            AnyView(SettingsView(selection: selection).environment(settings).environment(updates).environment(loginItem).environment(model))
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
            model.refresh(.popoverOpened)
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
        let (agents, gauge, sample) = withObservationTracking {
            (settings.agents, settings.gaugeEnabled, settings.showsSampleData)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSettings() }
        }
        model.agents = agents
        model.gaugeEnabled = gauge
        model.showsSampleData = sample
        // Every shown agent's account is asked; the files are the fallback.
        model.liveAgents = Set(agents)
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

    /// The status item shows the gauge - Claude's windows as bars and the time left on
    /// the fullest - or the symbol when the gauge is off or nothing is reported.
    private func observeGauge() {
        let (snapshot, gauge, agents, bars, time) = withObservationTracking {
            (model.snapshot, model.gaugeEnabled, model.agents, settings.menuBarBars, settings.menuBarTime)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeGauge() }
        }
        statusItem.gauge = gauge ? MenuBarGauge.make(from: snapshot, agents: agents, bars: bars, time: time, now: .now) : nil
        statusItem.summary = snapshot.isEmpty ? "AgentBar — nothing reported yet" : "AgentBar"
    }
}
