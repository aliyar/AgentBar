import SwiftUI
import AgentBarKit

/// The popover: the overview on the glass material.
struct PopoverView: View {
    @Environment(AgentsModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        OverviewView(snapshot: model.snapshot, agents: settings.agents,
                     onSettings: { AppDependencies.shared.settingsWindow.show() },
                     onQuit: { NSApp.terminate(nil) })
            .frame(width: 340)
            // The popover's own material gives the blur; the gradient on top gives the
            // glass its body, so what is behind the menu bar no longer shows through.
            .background(GlassBackground())
    }
}

#Preview {
    PopoverView()
        .environment(AgentsModel())
        .environment(AppSettings())
}
