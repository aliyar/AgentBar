import SwiftUI
import AgentBarKit

/// The panel in a window: the same overview as the popover, in the chosen style, at the
/// style's width. The window's own title bar is hidden and the panel's header takes its
/// place, traffic lights at its left; the window takes the content's height and can grow.
struct DockWindowView: View {
    @Environment(AgentsModel.self) private var model
    @Environment(StatusModel.self) private var status
    @Environment(PanelNavigation.self) private var navigation
    @Environment(AppSettings.self) private var settings

    var body: some View {
        OverviewView(style: settings.panelStyle, context: OverviewContext(
            snapshot: model.snapshot, agents: settings.agents, sections: settings.sections,
            statuses: status.statuses, statusProblems: status.problems,
            presentation: .window,
            route: navigation.route, onNavigate: { navigation.go(to: $0) },
            isRefreshing: model.isRefreshing || status.isRefreshing,
            onRefresh: { model.refresh(.manual); status.refresh(.manual) },
            onSettings: { AppDependencies.shared.settingsWindow.show() },
            onQuit: { NSApp.terminate(nil) }))
            .frame(width: PanelStyles.style(settings.panelStyle).width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))
            // Up under the (hidden) title bar: the header is the title bar.
            .ignoresSafeArea(edges: .top)
    }
}
