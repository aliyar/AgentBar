import SwiftUI
import AgentBarKit

/// The panel in the chosen style. The popover and the Dock window both draw this; the
/// style decides everything below it.
struct OverviewView: View {
    let style: PanelStyleID
    let context: OverviewContext

    var body: some View {
        PanelStyles.style(style).overview(context)
    }
}

#Preview("Glass") {
    OverviewView(style: .glass, context: OverviewContext(snapshot: .sample, agents: Agent.allCases))
        .frame(width: 340)
}

#Preview("Terminal") {
    OverviewView(style: .terminal, context: OverviewContext(snapshot: .sample, agents: Agent.allCases))
        .frame(width: TerminalStyle.width)
}
