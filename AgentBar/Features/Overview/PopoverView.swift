import SwiftUI
import AgentBarKit

/// The popover: the overview in the chosen style.
struct PopoverView: View {
    @Environment(AgentsModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        OverviewView(style: settings.panelStyle, context: OverviewContext(
            snapshot: model.snapshot, agents: settings.agents,
            isRefreshing: model.isRefreshing,
            onRefresh: { model.refresh(.manual) },
            onSettings: { AppDependencies.shared.settingsWindow.show() },
            onQuit: { NSApp.terminate(nil) }))
            .frame(width: PanelStyles.style(settings.panelStyle).width)
    }
}

#Preview {
    PopoverView()
        .environment(AgentsModel())
        .environment(AppSettings())
}
