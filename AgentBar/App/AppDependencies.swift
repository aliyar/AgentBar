import OSLog
import AppKit
import SwiftUI
import AgentBarKit

/// Composition root. Created in `applicationWillFinishLaunching`, before any scene exists.
final class AppDependencies {
    private(set) static var shared: AppDependencies!

    let settings: AppSettings
    let model: AgentsModel
    /// What the agents' own status pages say. Its own model: it asks public pages on a
    /// cadence of its own and must keep asking with nothing on screen.
    let status: StatusModel
    let notifier = StatusNotifier()
    /// Where each panel is: the popover and the Dock window keep their own place, so
    /// opening one does not move the other.
    let popoverNavigation = PanelNavigation()
    let windowNavigation = PanelNavigation()
    let statusItem: StatusItemController
    let updates: UpdateController
    let loginItem = LoginItemController()
    let settingsWindow: SettingsWindowController
    /// The Dock presence: the popover off the Dock icon, and the same panel in a window.
    let dockWindow: PanelWindowController
    let dockAnchor = DockIconAnchor()
    private var notificationsObserved = false

    private init() {
        settings = AppSettings()
        model = AgentsModel()
        status = StatusModel()
        statusItem = StatusItemController()
        updates = UpdateController()
        let settings = settings, updates = updates, loginItem = loginItem, model = model, status = status
        let windowNavigation = windowNavigation
        dockWindow = PanelWindowController(title: "AgentBar", minimumSize: NSSize(width: 330, height: 300)) {
            AnyView(DockWindowView().environment(model).environment(status).environment(windowNavigation)
                .environment(settings).environment(updates))
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
        observeNotifications()
        let model = model
        let settings = settings
        let updates = updates
        let status = status
        statusItem.imageName = "MenuBarIcon"
        let popoverNavigation = popoverNavigation
        statusItem.panelRoot = {
            AnyView(PopoverView().environment(model).environment(status).environment(popoverNavigation)
                .environment(settings).environment(updates))
        }
        notifier.onOpen = { [weak self] in self?.showPanel() }
        status.onTransition = { [weak self] agent, transition, reading in
            self?.announce(transition, for: agent, status: reading)
        }
        statusItem.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onPanelOpened = { [weak self] in
            self?.panelVisibilityChanged()
            model.refresh(.popoverOpened)
            status.refresh(.popoverOpened)
        }
        statusItem.onPanelClosed = { [weak self] in
            self?.dockAnchor.release()
            self?.panelVisibilityChanged()
            // A menu bar panel opens on the thing it is for, not on wherever you were.
            self?.popoverNavigation.reset()
        }
        dockWindow.onVisibilityChange = { [weak self] visible in
            self?.panelVisibilityChanged()
            if !visible { self?.windowNavigation.reset() }
            if visible {
                model.refresh(.popoverOpened)
                status.refresh(.popoverOpened)
            }
        }
    }

    /// One settled change of state, filtered by what the user asked to hear about. The
    /// model decides *that* something changed; this decides whether to say it. Which
    /// agents is already settled: the model only watches the ones the panel shows.
    private func announce(_ transition: StatusWatch.Transition, for agent: Agent, status reading: ServiceStatus) {
        switch transition {
        case .wentDown: guard settings.notifiesDown else { return }
        case .cameBack: guard settings.notifiesBack else { return }
        }
        notifier.post(transition, for: agent, status: reading)
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
        // Not in the Dock, yet clicked there: the icon is one the user pinned ("Keep in
        // Dock"). That is a launch, so the panel opens where the app lives - the menu bar.
        guard settings.presence.inDock else {
            statusItem.showPopover()
            return
        }
        guard settings.dockClickOpens == .popover else {
            dockWindow.show()
            return
        }
        showPopoverFromDock()
    }

    /// The popover off the Dock icon whatever the click setting says; toggles when it is
    /// already up. Falls back to `showPanel()` when the pointer is not on the Dock.
    func showPopoverFromDock() {
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
    /// Dock, the popover off the menu bar item otherwise.
    func showPanel() {
        if settings.dockEnabled || !statusItem.isInstalled {
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
        // Launch at login is on by default: the first launch registers it (macOS tells
        // the user, and Settings › General can turn it off); later launches leave the
        // user's choice alone.
        if settings.takeFirstLaunch(), !loginItem.isEnabled, !loginItem.requiresApproval {
            loginItem.register()
        }
        model.start()
        status.start()
        updates.start()
        Log.app.notice("AgentBar started")
    }

    /// Settings flow into the model; the model never reads UserDefaults itself.
    private func observeSettings() {
        let (agents, gauge, sample, checksStatus) = withObservationTracking {
            (settings.agents, settings.gaugeEnabled, settings.showsSampleData, settings.checksStatus)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSettings() }
        }
        model.agents = agents
        model.gaugeEnabled = gauge
        model.showsSampleData = sample
        // Every shown agent's account is asked; the files are the fallback.
        model.liveAgents = Set(agents)
        status.agents = agents
        status.isEnabled = checksStatus
        status.showsSampleData = sample
    }

    /// macOS is asked for permission the first time the user asks to be told something,
    /// not at launch: a menu bar app that wants notifications before it has anything to
    /// say is asking about a feature the user has not met yet.
    private func observeNotifications() {
        let announces = withObservationTracking {
            settings.announcesAnything
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeNotifications() }
        }
        // The first pass only starts the observation. The defaults have every switch on,
        // and asking because of a default is asking at launch by another name; permission
        // is asked when the user turns one on, and otherwise when there is a first message
        // to show, which is when the request explains itself.
        guard notificationsObserved else { notificationsObserved = true; return }
        guard announces else { return }
        Task { await notifier.requestAuthorization() }
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

    /// Where the app's icon goes: the menu bar, the Dock, or both. One is always on.
    private func observeDock() {
        let presence = withObservationTracking {
            settings.presence
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeDock() }
        }
        DockPresence.set(presence.inDock)
        if presence.inMenuBar { statusItem.install() } else { statusItem.remove() }
        if !presence.inDock, dockWindow.isVisible { dockWindow.close() }
    }

    /// The status item shows the gauge - Claude's windows as bars and the time left on
    /// the fullest - or the symbol when the gauge is off or nothing is reported.
    private func observeGauge() {
        let (snapshot, gauge, agents, bars, time, failing) = withObservationTracking {
            (model.snapshot, model.gaugeEnabled, model.agents, settings.menuBarBars, settings.menuBarTime, status.failing)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeGauge() }
        }
        statusItem.gauge = gauge ? MenuBarGauge.make(from: snapshot, agents: agents, bars: bars, time: time, now: .now) : nil
        // The mark is drawn on whatever the item is showing, gauge or symbol.
        statusItem.alert = !failing.isEmpty
        let unwell = failing.map(\.title).joined(separator: ", ")
        statusItem.summary = if !failing.isEmpty {
            "AgentBar — \(unwell) \(failing.count == 1 ? "is" : "are") down"
        } else if snapshot.isEmpty {
            "AgentBar — nothing reported yet"
        } else {
            "AgentBar"
        }
    }
}
