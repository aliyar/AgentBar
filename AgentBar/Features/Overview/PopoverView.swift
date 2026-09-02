import SwiftUI
import AgentBarKit

/// The popover: the agents' meters and conversations, and a way to Settings and out.
struct PopoverView: View {
    @Environment(AgentsModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OverviewView(snapshot: model.snapshot, agents: settings.agents)
            Divider()
                .padding(.horizontal, 12)
            HStack {
                Button("Settings…") { AppDependencies.shared.settingsWindow.show() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
    }
}

#Preview {
    PopoverView()
        .environment(AgentsModel())
        .environment(AppSettings())
}
