import SwiftUI
import AgentBarKit

/// The panel in the chosen style. The popover and the Dock window both draw this; the
/// style decides everything below it.
struct OverviewView: View {
    let style: PanelStyleID
    let context: OverviewContext

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        PanelStyles.style(style).overview(context)
            // One tip layer per panel, at its root: the cards are drawn over everything
            // and placed inside the panel's own frame.
            .tipLayer(style: style == .terminal ? .terminal(TerminalPalette.of(scheme)) : .glass(Palette.glass(scheme)))
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
