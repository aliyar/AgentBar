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
        static let sectionOrder = "sectionOrder"
        static let conversations = "showsConversations"
        static let appearance = "appearance"
        static let panelStyle = "panelStyle"
        static let presence = "presence"
        /// The switch this replaced; read once so an earlier choice survives.
        static let dock = "dockEnabled"
        static let dockClick = "dockClickOpens"
        static let panelOpacity = panelOpacityKey
        static let sampleData = "sampleData"
        /// Set after the first launch has registered the login item, so a user who turns
        /// it off later is not opted back in.
        static let loginItemOffered = "loginItemOffered"
        static let menuBarBars = "menuBarBars"
        static let menuBarTime = "menuBarTime"
        /// Shared with `OverviewView`'s `@AppStorage`: clicking a time in the panel flips it too.
        static let resetClock = "showsResetClock"
        static let statusChecks = "statusChecks"
        static let notifiesDown = "notifiesDown"
        static let notifiesBack = "notifiesBack"
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

    /// The menu bar gauge (bars and the time left) instead of the symbol. On by default.
    var gaugeEnabled: Bool {
        didSet { defaults.set(gaugeEnabled, forKey: Keys.gauge) }
    }

    /// Where the app's own icon goes. One of the two is always on, so there is always a
    /// way back to the app - which is why this is one setting with three values rather
    /// than two switches that could both be off.
    enum Presence: String, CaseIterable {
        case menuBar, dock, both

        var title: String {
            switch self {
            case .menuBar: "The menu bar"
            case .dock: "The Dock"
            case .both: "Both"
            }
        }

        var inMenuBar: Bool { self != .dock }
        var inDock: Bool { self != .menuBar }
    }

    var presence: Presence {
        didSet { defaults.set(presence.rawValue, forKey: Keys.presence) }
    }

    /// In the Dock (alone or with the menu bar).
    var dockEnabled: Bool { presence.inDock }

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

    /// The order the panel's blocks come in - each agent's group and the conversations
    /// running right now. The panel draws them in this order; the menu bar's bars and the
    /// widget follow the agents' part of it, because both draw a snapshot sorted by it.
    ///
    /// Stored as names rather than positions, so a block added by an update joins the end
    /// of the list instead of being lost or landing somewhere arbitrary.
    var sectionOrder: [PanelSection] {
        didSet { defaults.set(sectionOrder.map(\.rawValue), forKey: Keys.sectionOrder) }
    }

    /// The conversations block. An agent is hidden through `enabledAgents`; this one has
    /// no agent, so it has a switch of its own.
    var showsConversations: Bool {
        didSet { defaults.set(showsConversations, forKey: Keys.conversations) }
    }

    private static func order(in defaults: UserDefaults) -> [PanelSection] {
        let stored = (defaults.stringArray(forKey: Keys.sectionOrder) ?? []).compactMap(PanelSection.init(rawValue:))
        // Anything the stored list does not name - a new block, or a name that no longer
        // exists having been dropped by `compactMap` - keeps its canonical place at the end.
        return stored + PanelSection.all.filter { !stored.contains($0) }
    }

    /// Puts `section` where `other` sits now. Dropping a row onto another takes that row's
    /// place; everything between shuffles up or down to make room.
    func move(_ section: PanelSection, onto other: PanelSection) {
        guard section != other, let to = sectionOrder.firstIndex(of: other) else { return }
        var order = sectionOrder
        order.removeAll { $0 == section }
        order.insert(section, at: min(to, order.count))
        sectionOrder = order
    }

    func isShown(_ section: PanelSection) -> Bool {
        switch section {
        case .agent(let agent): isEnabled(agent)
        case .conversations: showsConversations
        }
    }

    func setShown(_ section: PanelSection, _ shown: Bool) {
        switch section {
        case .agent(let agent): setEnabled(agent, shown)
        case .conversations: showsConversations = shown
        }
    }

    /// The blocks to draw, in the order the user put them.
    var sections: [PanelSection] { sectionOrder.filter { isShown($0) } }

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
    /// every row of the panel without waiting for the agents to fill them. A development
    /// aid: Release builds neither offer nor honour it.
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

    /// Read each agent's status page. Off means the panel shows no status at all and no
    /// page is asked - the one switch that turns the whole feature off.
    var checksStatus: Bool {
        didSet { defaults.set(checksStatus, forKey: Keys.statusChecks) }
    }

    /// Say so when a service stops working.
    var notifiesDown: Bool {
        didSet { defaults.set(notifiesDown, forKey: Keys.notifiesDown) }
    }

    /// Say so when it works again. The one this feature is for.
    var notifiesBack: Bool {
        didSet { defaults.set(notifiesBack, forKey: Keys.notifiesBack) }
    }

    /// Whether anything at all is announced. Which agents is not a question of its own:
    /// it is the agents shown, the same list everything else in the app works from.
    var announcesAnything: Bool {
        checksStatus && (notifiesDown || notifiesBack)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // The defaults a first launch lands on: the gauge in the menu bar, the app in the
        // menu bar and the Dock both, and launch at login (registered once, see
        // `AppDependencies.start`). Each can be turned off in Settings.
        gaugeEnabled = defaults.object(forKey: Keys.gauge) as? Bool ?? true
        presence = defaults.string(forKey: Keys.presence).flatMap(Presence.init(rawValue:))
            ?? (defaults.object(forKey: Keys.dock) == nil || defaults.bool(forKey: Keys.dock) ? .both : .menuBar)
        dockClickOpens = defaults.string(forKey: Keys.dockClick).flatMap(DockClick.init(rawValue:)) ?? .popover
        enabledAgents = Self.included(excluding: Keys.disabledAgents, in: defaults)
        sectionOrder = Self.order(in: defaults)
        showsConversations = defaults.object(forKey: Keys.conversations) as? Bool ?? true
        // Dark by default: both styles were designed dark-first.
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .dark
        panelStyle = defaults.string(forKey: Keys.panelStyle).flatMap(PanelStyleID.init(rawValue:)) ?? .glass
        panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? Self.defaultPanelOpacity
        #if DEBUG
        showsSampleData = defaults.bool(forKey: Keys.sampleData)
        #else
        showsSampleData = false
        #endif
        menuBarBars = defaults.stringArray(forKey: Keys.menuBarBars) ?? []
        menuBarTime = MenuBarTime(rawValue: defaults.string(forKey: Keys.menuBarTime) ?? "fullest")
        showsResetClock = defaults.bool(forKey: Keys.resetClock)
        // The status of a service you depend on is not an opt-in curiosity, and the pages
        // are public: on by default, both directions.
        checksStatus = defaults.object(forKey: Keys.statusChecks) as? Bool ?? true
        notifiesDown = defaults.object(forKey: Keys.notifiesDown) as? Bool ?? true
        notifiesBack = defaults.object(forKey: Keys.notifiesBack) as? Bool ?? true
    }

    /// True once per install: the first launch registers the login item and remembers it did.
    ///
    /// Absent means one of two very different things. On a fresh install nothing of ours is on
    /// disk yet and the app may put itself in Login Items. On a copy that predates the key
    /// there are settings already, and 1.0.0 shipped without it, so reading absent as "never
    /// asked" would opt those installs in behind their back. Anything of our own on disk
    /// counts as asked.
    func takeFirstLaunch() -> Bool {
        let offered = defaults.object(forKey: Keys.loginItemOffered) as? Bool
            ?? (defaults.object(forKey: Keys.gauge) != nil
                || defaults.object(forKey: Keys.appearance) != nil
                || defaults.object(forKey: Keys.sectionOrder) != nil)
        guard !offered else { return false }
        defaults.set(true, forKey: Keys.loginItemOffered)
        return true
    }

    /// The agents to show, in the order the user put them.
    var agents: [Agent] { sectionOrder.compactMap(\.agent).filter { enabledAgents.contains($0) } }

    func isEnabled(_ agent: Agent) -> Bool { enabledAgents.contains(agent) }

    func setEnabled(_ agent: Agent, _ enabled: Bool) {
        if enabled { enabledAgents.insert(agent) } else { enabledAgents.remove(agent) }
    }

}
