import SwiftUI
import AgentBarKit

/// The popover: the overview in the chosen style.
struct PopoverView: View {
    @Environment(AgentsModel.self) private var model
    @Environment(StatusModel.self) private var status
    @Environment(PanelNavigation.self) private var navigation
    @Environment(AppSettings.self) private var settings

    var body: some View {
        OverviewView(style: settings.panelStyle, context: OverviewContext(
            snapshot: model.snapshot, agents: settings.agents, sections: settings.sections,
            statuses: status.statuses, statusProblems: status.problems,
            route: navigation.route, onNavigate: { navigation.go(to: $0) },
            isRefreshing: model.isRefreshing || status.isRefreshing,
            onRefresh: { model.refresh(.manual); status.refresh(.manual) },
            onSettings: { AppDependencies.shared.settingsWindow.show() },
            onQuit: { NSApp.terminate(nil) }))
            .frame(width: PanelStyles.style(settings.panelStyle).width)
    }
}

#Preview {
    PopoverView()
        .environment(AgentsModel())
        .environment(StatusModel())
        .environment(PanelNavigation())
        .environment(AppSettings())
}
