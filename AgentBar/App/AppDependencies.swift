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
    /// The Dock presence: the popover off the Dock icon, and the same panel in a window.
    let dockWindow: PanelWindowController
    let dockAnchor = DockIconAnchor()

    private init() {
        settings = AppSettings()
        model = AgentsModel()
        statusItem = StatusItemController()
        updates = UpdateController()
        let settings = settings, updates = updates, loginItem = loginItem, model = model
        dockWindow = PanelWindowController(title: "AgentBar", minimumSize: NSSize(width: 330, height: 300)) {
            AnyView(DockWindowView().environment(model).environment(settings).environment(updates))
        }
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
        statusItem.imageName = "MenuBarIcon"
        statusItem.panelRoot = {
            AnyView(PopoverView().environment(model).environment(settings).environment(updates))
        }
        statusItem.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onPanelOpened = { [weak self] in
            self?.panelVisibilityChanged()
            model.refresh(.popoverOpened)
        }
        statusItem.onPanelClosed = { [weak self] in
            self?.dockAnchor.release()
            self?.panelVisibilityChanged()
        }
        dockWindow.onVisibilityChange = { [weak self] visible in
            self?.panelVisibilityChanged()
            if visible { model.refresh(.popoverOpened) }
        }
    }

    /// The panel is "on screen" while either the popover or the Dock window shows it; the
    /// model reads faster then.
    private func panelVisibilityChanged() {
        model.isPopoverVisible = statusItem.isPopoverShown || dockWindow.isVisible
    }

    /// A click on the app's icon in the Dock: the popover, hanging off that icon, as the
    /// menu bar icon opens it. A second click closes it. When the pointer says the click
    /// did not come from the Dock (Finder, Spotlight), the panel opens as `showPanel` does.
    func showPanelFromDock() {
        guard settings.dockClickOpens == .popover else {
            dockWindow.show()
            return
        }
        if statusItem.isPopoverShown {
            statusItem.closePopover()
            return
        }
        guard let anchor = dockAnchor.dockIconUnderPointer() else {
            showPanel()
            return
        }
        statusItem.showPopover(from: anchor.view, edge: anchor.edge)
    }

    /// What `agentbar://open` and the Window menu open: the window when the app is in the
    /// Dock, the popover otherwise.
    func showPanel() {
        if settings.dockEnabled {
            dockWindow.show()
        } else {
            statusItem.showPopover()
        }
    }

    func start() {
        observeSettings()
        observeDock()
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
        dockWindow.appearance = appearance.nsAppearance
    }

    /// In the Dock with a window, or a menu bar item only. Turning it on opens the window;
    /// turning it off closes it and leaves the popover.
    private func observeDock() {
        let inDock = withObservationTracking {
            settings.dockEnabled
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeDock() }
        }
        DockPresence.set(inDock)
        if !inDock, dockWindow.isVisible { dockWindow.close() }
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
