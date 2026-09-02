import SwiftUI
import AgentBarKit

/// Colours picked for both themes rather than taken from the system's saturated set,
/// which shouts on a light background and glows on a dark one.
enum Palette {
    static let calm = Color(red: 0.16, green: 0.62, blue: 0.44)
    static let warm = Color(red: 0.85, green: 0.58, blue: 0.14)
    static let hot = Color(red: 0.83, green: 0.29, blue: 0.26)

    /// What a meter is drawn on. Heavier in light, where a faint grey vanishes.
    static func track(_ scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.14 : 0.11)
    }

    /// Green, amber, then red as a window tightens.
    static func level(_ percent: Double) -> Color {
        switch percent {
        case ..<60: calm
        case ..<85: warm
        default: hot
        }
    }

    static func agent(_ agent: Agent) -> Color {
        switch agent {
        case .claude: Color(red: 0.83, green: 0.41, blue: 0.24)
        case .codex: Color(red: 0.35, green: 0.42, blue: 0.86)
        }
    }
}
