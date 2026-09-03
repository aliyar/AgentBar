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
}

/// Everything a style needs to draw the panel: the data, the moment, and the actions.
struct OverviewContext {
    let snapshot: Snapshot
    let agents: [Agent]
    var isRefreshing = false
    var onRefresh: () -> Void = {}
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    var conversations: [Conversation] {
        snapshot.conversations.filter { agents.contains($0.agent) }
    }
}

/// The styles the app ships, in Settings order.
enum PanelStyles {
    static let all: [any PanelStyle.Type] = [GlassStyle.self, TerminalStyle.self]

    static func style(_ id: PanelStyleID) -> any PanelStyle.Type {
        all.first { $0.id == id } ?? GlassStyle.self
    }
}
