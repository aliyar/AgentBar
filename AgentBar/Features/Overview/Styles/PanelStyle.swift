import SwiftUI
import AgentBarKit

/// How the panel is drawn. The theme (System / Light / Dark) says which of a style's two
/// variants is on screen; the style says what the panel looks like at all - the glass
/// panel from the design handoff, a terminal, whatever comes next. Every surface that
/// draws a snapshot (the popover today; the Dock window and the widget later) asks the
/// chosen style for its view.
///
/// Styles differ in what they show, not only in colours: a style declares its `features`
/// so Settings can hide an option the current style ignores, and a new style is a folder
/// under `Styles/` plus one line in `PanelStyles.all`.
protocol PanelStyle {
    static var id: PanelStyleID { get }
    static var title: String { get }
    /// One line for the Settings picker.
    static var summary: String { get }
    static var features: Set<StyleFeature> { get }
    /// The panel's width in points; a mono grid may want it tighter than the glass panel.
    static var width: CGFloat { get }

    @MainActor static func overview(_ context: OverviewContext) -> AnyView

    /// The style's own options, shown under the Style picker in Settings › Appearance.
    /// Empty by default; a style with knobs of its own returns Form sections.
    @MainActor static func settings(_ settings: AppSettings) -> AnyView
}

extension PanelStyle {
    @MainActor static func settings(_ settings: AppSettings) -> AnyView { AnyView(EmptyView()) }
}

/// The stored identity of a style. Order here is the order in Settings.
nonisolated enum PanelStyleID: String, CaseIterable, Codable, Sendable {
    case glass, terminal
}

/// What a style can show; a style that lacks one gets its setting hidden.
nonisolated enum StyleFeature: Sendable {
    /// Reset times can be shown as clock times instead of time left.
    case resetClock
    /// Conversations open to a detail line.
    case conversationDetails
    /// The background honours the panel opacity setting.
    case backgroundOpacity
}

/// One block of the panel's body, in the order the user put them. An agent's group, or
/// the conversations running right now - both are things the panel stacks, and neither is
/// more fixed than the other, so both are moved and hidden the same way.
enum PanelSection: Hashable, Identifiable {
    case agent(Agent)
    case conversations

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .agent(let agent): "agent:\(agent.rawValue)"
        case .conversations: "conversations"
        }
    }

    init?(rawValue: String) {
        if rawValue == "conversations" { self = .conversations; return }
        guard rawValue.hasPrefix("agent:"),
              let agent = Agent(rawValue: String(rawValue.dropFirst(6))) else { return nil }
        self = .agent(agent)
    }

    /// What Settings calls it.
    var title: String {
        switch self {
        case .agent(let agent): agent.title
        case .conversations: "Active conversations"
        }
    }

    /// Every section there can be, in the order a fresh install lands on: the agents as
    /// they are declared, then what is running right now.
    static var all: [PanelSection] { Agent.allCases.map(PanelSection.agent) + [.conversations] }

    var agent: Agent? {
        if case .agent(let agent) = self { return agent }
        return nil
    }
}

/// Which screen the panel is showing. The panel is one surface with a stack of one: the
/// overview, or one agent's status pushed over it, with a way back. Nothing else is
/// reachable this way, and nothing should be without a reason as good.
enum PanelRoute: Equatable {
    case overview
    case status(Agent)
}

/// Where the panel is drawn. In a window the system title bar is hidden and the panel's
/// own header stands in for it: the traffic lights sit at its left, so the header leaves
/// them room and centres the name.
enum PanelPresentation {
    case popover, window

    /// The width the window's close/minimise/zoom buttons take at the header's left.
    static let trafficLightsInset: CGFloat = 70
}

/// Everything a style needs to draw the panel: the data, the moment, and the actions.
struct OverviewContext {
    let snapshot: Snapshot
    let agents: [Agent]
    /// The blocks to draw, in order. Empty means "every agent, then the conversations" -
    /// what a preview or the screenshot harness wants without having to say so.
    var sections: [PanelSection] = []
    /// What each agent's status page says. Empty while the check is turned off, and the
    /// panel then draws no status at all.
    var statuses: [Agent: ServiceStatus] = [:]
    /// Why an agent's page could not be read; its last good status stays beside it.
    var statusProblems: [Agent: String] = [:]
    var presentation: PanelPresentation = .popover
    /// The screen being shown, and the way to another. Each surface keeps its own; opening
    /// the panel again starts at the overview.
    var route: PanelRoute = .overview
    var onNavigate: (PanelRoute) -> Void = { _ in }
    var isRefreshing = false
    var onRefresh: () -> Void = {}
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    var conversations: [Conversation] {
        snapshot.conversations.filter { agents.contains($0.agent) }
    }

    /// Whether the status of a service is being shown at all.
    var showsStatus: Bool { !statuses.isEmpty || !statusProblems.isEmpty }

    /// `sections`, or the default arrangement when none was given.
    var drawnSections: [PanelSection] {
        sections.isEmpty ? agents.map(PanelSection.agent) + [.conversations] : sections
    }
}

/// The styles the app ships, in Settings order.
enum PanelStyles {
    static let all: [any PanelStyle.Type] = [GlassStyle.self, TerminalStyle.self]

    static func style(_ id: PanelStyleID) -> any PanelStyle.Type {
        all.first { $0.id == id } ?? GlassStyle.self
    }
}
