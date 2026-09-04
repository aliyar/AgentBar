import SwiftUI

/// The panel from the design handoff: translucent glass, rounded groups, tick meters.
enum GlassStyle: PanelStyle {
    static let id = PanelStyleID.glass
    static let title = "Glass"
    static let summary = "Translucent panel, rounded groups, tick meters."
    static let features: Set<StyleFeature> = [.resetClock, .conversationDetails, .backgroundOpacity]
    static let width: CGFloat = 340

    static func overview(_ context: OverviewContext) -> AnyView {
        AnyView(
            GlassOverview(snapshot: context.snapshot, agents: context.agents, sections: context.sections,
                          statuses: context.statuses, statusProblems: context.statusProblems,
                          showsStatus: context.showsStatus,
                          onSettings: context.onSettings, onQuit: context.onQuit,
                          isRefreshing: context.isRefreshing, onRefresh: context.onRefresh,
                          presentation: context.presentation,
                          route: context.route, onNavigate: context.onNavigate)
                // The popover's own material gives the blur; the gradient on top gives
                // the glass its body, so what is behind the menu bar no longer shows through.
                .background(GlassBackground())
        )
    }
}
