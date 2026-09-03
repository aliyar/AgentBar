import Foundation
import Observation
import AgentBarKit

/// The handful of settings v1 has, backed by UserDefaults. Nothing is added here for a
/// feature that "might want" it.
@Observable
final class AppSettings {
    private enum Keys {
        static let gauge = "gaugeEnabled"
        /// Stored as exclusions, so an agent added by an update is on until turned off.
        static let disabledAgents = "disabledAgents"
        static let appearance = "appearance"
        static let panelStyle = "panelStyle"
        static let dock = "dockEnabled"
        static let dockClick = "dockClickOpens"
        static let panelOpacity = panelOpacityKey
        static let sampleData = "sampleData"
        static let menuBarBars = "menuBarBars"
        static let menuBarTime = "menuBarTime"
        /// Shared with `OverviewView`'s `@AppStorage`: clicking a time in the panel flips it too.
        static let resetClock = "showsResetClock"
    }

    /// Whose time left the menu bar shows next to the bars.
    enum MenuBarTime: Hashable {
        /// The fullest of the windows shown as bars.
        case fullest
        /// One window, by `UsageLimit.id`.
        case window(String)
        case none

        var rawValue: String {
            switch self {
            case .fullest: "fullest"
            case .none: "none"
            case .window(let id): id
            }
        }

        init(rawValue: String) {
            switch rawValue {
            case "fullest": self = .fullest
            case "none": self = .none
            default: self = .window(rawValue)
            }
        }
    }

    private let defaults: UserDefaults

    /// Show the fullest live window as a percentage in the menu bar instead of the symbol.
    /// Off by default: a bare "78%" does not say what it is; how the item should look is
    /// still to be designed.
    var gaugeEnabled: Bool {
        didSet { defaults.set(gaugeEnabled, forKey: Keys.gauge) }
    }

    /// Be in the Dock too. Off by default.
    var dockEnabled: Bool {
        didSet { defaults.set(dockEnabled, forKey: Keys.dock) }
    }

    /// What a click on the Dock icon opens.
    enum DockClick: String, CaseIterable {
        case popover, window

        var title: String {
            switch self {
            case .popover: "The panel, above the Dock"
            case .window: "A window"
            }
        }
    }

    var dockClickOpens: DockClick {
        didSet { defaults.set(dockClickOpens.rawValue, forKey: Keys.dockClick) }
    }

    /// The agents the popover and the gauge take into account.
    var enabledAgents: Set<Agent> {
        didSet { defaults.set(Self.excluded(from: enabledAgents), forKey: Keys.disabledAgents) }
    }

    private static func excluded(from included: Set<Agent>) -> [String] {
        Agent.allCases.filter { !included.contains($0) }.map(\.rawValue)
    }

    private static func included(excluding key: String, in defaults: UserDefaults) -> Set<Agent> {
        let off = Set(defaults.stringArray(forKey: key) ?? [])
        return Set(Agent.allCases.filter { !off.contains($0.rawValue) })
    }

    /// The popover's and the Settings window's appearance; the status item follows the menu bar.
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// How the panel is drawn (glass, terminal, …); the appearance picks the variant.
    var panelStyle: PanelStyleID {
        didSet { defaults.set(panelStyle.rawValue, forKey: Keys.panelStyle) }
    }

    /// Shared with the styles' `@AppStorage`, which read the same key.
    static let panelOpacityKey = "panelOpacity"
    static let defaultPanelOpacity = 0.85

    /// The panel's background, 0 (only the popover's own blur) to 1 (opaque); every style
    /// that has a background honours it.
    var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
    }

    /// Draw the handoff's sample snapshot instead of what the agents wrote: a way to see
    /// every row of the panel without waiting for the agents to fill them.
    var showsSampleData: Bool {
        didSet { defaults.set(showsSampleData, forKey: Keys.sampleData) }
    }

    /// The windows drawn as bars in the menu bar, by `UsageLimit.id`. Empty means the
    /// default: Claude's windows.
    var menuBarBars: [String] {
        didSet { defaults.set(menuBarBars, forKey: Keys.menuBarBars) }
    }

    var menuBarTime: MenuBarTime {
        didSet { defaults.set(menuBarTime.rawValue, forKey: Keys.menuBarTime) }
    }

    /// Reset times in the panel as clock times ("14:05") rather than time left ("4h 52m").
    var showsResetClock: Bool {
        didSet { defaults.set(showsResetClock, forKey: Keys.resetClock) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gaugeEnabled = defaults.object(forKey: Keys.gauge) as? Bool ?? false
        dockEnabled = defaults.bool(forKey: Keys.dock)
        dockClickOpens = defaults.string(forKey: Keys.dockClick).flatMap(DockClick.init(rawValue:)) ?? .popover
        enabledAgents = Self.included(excluding: Keys.disabledAgents, in: defaults)
        // Dark by default: both styles were designed dark-first.
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .dark
        panelStyle = defaults.string(forKey: Keys.panelStyle).flatMap(PanelStyleID.init(rawValue:)) ?? .glass
        panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? Self.defaultPanelOpacity
        showsSampleData = defaults.bool(forKey: Keys.sampleData)
        menuBarBars = defaults.stringArray(forKey: Keys.menuBarBars) ?? []
        menuBarTime = MenuBarTime(rawValue: defaults.string(forKey: Keys.menuBarTime) ?? "fullest")
        showsResetClock = defaults.bool(forKey: Keys.resetClock)
    }

    /// Enabled agents in their canonical order.
    var agents: [Agent] { Agent.allCases.filter { enabledAgents.contains($0) } }

    func isEnabled(_ agent: Agent) -> Bool { enabledAgents.contains(agent) }

    func setEnabled(_ agent: Agent, _ enabled: Bool) {
        if enabled { enabledAgents.insert(agent) } else { enabledAgents.remove(agent) }
    }

}
