import SwiftUI
import AgentBarKit

/// An agent's mark: its own logo from the asset catalogue (template SVGs, so they take
/// whatever colour they are given).
struct AgentGlyph: View {
    let agent: Agent
    /// The point size the mark is drawn at.
    var size: CGFloat

    private var assetName: String? {
        switch agent {
        case .claude: "claude"
        case .codex: "codex"
        case .cursor: "cursor"
        }
    }

    var body: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: agent.symbol)
                .font(.system(size: size * 0.9, weight: .medium))
                .frame(width: size, height: size)
        }
    }
}
