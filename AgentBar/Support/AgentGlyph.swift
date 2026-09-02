import SwiftUI
import AgentBarKit

/// An agent's mark: its own logo from the asset catalogue (template SVGs, so they take
/// whatever colour they are given).
struct AgentGlyph: View {
    let agent: Agent
    /// The point size the mark is drawn at.
    var size: CGFloat

    private var assetName: String {
        switch agent {
        case .claude: "claude"
        case .codex: "codex"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
