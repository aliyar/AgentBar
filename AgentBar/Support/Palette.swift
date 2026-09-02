import AppKit
import SwiftUI
import AgentBarKit

/// The design's colours. Two sets, one per appearance: on glass, small type needs more
/// opacity than on an opaque window, and the level colours are brighter on the dark page.
enum Palette {
    // MARK: Level colours (thresholds 60 / 85)

    enum Level { case calm, warm, hot }

    static func level(_ percent: Double) -> Level {
        switch percent {
        case ..<60: .calm
        case ..<85: .warm
        default: .hot
        }
    }

    static func color(_ level: Level, _ scheme: ColorScheme) -> Color {
        Color(nsColor: nsColor(level, dark: scheme == .dark))
    }

    static func level(_ percent: Double, _ scheme: ColorScheme) -> Color {
        color(level(percent), scheme)
    }

    static func nsColor(_ level: Level, dark: Bool) -> NSColor {
        switch (level, dark) {
        case (.calm, true): NSColor(srgbRed: 0.231, green: 0.761, blue: 0.541, alpha: 1)   // #3BC28A
        case (.calm, false): NSColor(srgbRed: 0.122, green: 0.541, blue: 0.384, alpha: 1)  // #1F8A62
        case (.warm, true): NSColor(srgbRed: 0.867, green: 0.627, blue: 0.227, alpha: 1)   // #DDA03A
        case (.warm, false): NSColor(srgbRed: 0.659, green: 0.478, blue: 0.118, alpha: 1)  // #A87A1E
        case (.hot, true): NSColor(srgbRed: 0.851, green: 0.361, blue: 0.322, alpha: 1)    // #D95C52
        case (.hot, false): NSColor(srgbRed: 0.753, green: 0.224, blue: 0.184, alpha: 1)   // #C0392F
        }
    }

    // MARK: Agent colours

    static func agent(_ agent: Agent, _ scheme: ColorScheme) -> Color {
        switch (agent, scheme) {
        case (.claude, .dark): Color(red: 0.878, green: 0.541, blue: 0.376)   // #E08A60
        case (.claude, _): Color(red: 0.690, green: 0.333, blue: 0.173)       // #B0552C
        case (.codex, .dark): Color(red: 0.533, green: 0.580, blue: 0.910)    // #8894E8
        case (.codex, _): Color(red: 0.290, green: 0.349, blue: 0.722)        // #4A59B8
        }
    }

    /// The squircle behind an agent's glyph.
    static func agentTint(_ agent: Agent, _ scheme: ColorScheme) -> Color {
        switch agent {
        case .claude: Color(red: 0.831, green: 0.412, blue: 0.239).opacity(scheme == .dark ? 0.16 : 0.14)
        case .codex: Color(red: 0.349, green: 0.420, blue: 0.859).opacity(scheme == .dark ? 0.16 : 0.13)
        }
    }

    // MARK: Glass tokens

    /// What the panel is made of, per appearance.
    struct Glass {
        let backgroundTop: Color
        let backgroundBottom: Color
        let border: Color
        let hairline: Color
        let groupFill: Color
        let selectedRow: Color
        let hoverRow: Color
        let track: Color
        let primary: Color
        let body: Color
        let secondary: Color
        let tertiary: Color
        let buttonFill: Color
        let icon: Color
        /// The ring around the working dot: the panel's own colour, so the dot sits on it.
        let dotRing: Color
        /// Row labels and names. Light-on-dark text reads heavier than dark-on-light (the
        /// glow of white strokes), so the dark panel sets its text one weight lighter.
        var bodyWeight: Font.Weight = .regular

        /// Dark: the system's own semantic colours, as a dark window and its grouped form
        /// use them. The design's white-on-dark washes read too light against a dark desk.
        static let dark = Glass(
            backgroundTop: Color(nsColor: .windowBackgroundColor).opacity(0.78),
            backgroundBottom: Color(nsColor: .windowBackgroundColor).opacity(0.84),
            // Separators at their faintest: `separatorColor` reads as bright lines on a dark panel.
            border: Color(nsColor: .quinaryLabel),
            hairline: Color(nsColor: .quinaryLabel),
            groupFill: Color(nsColor: .tertiarySystemFill),
            selectedRow: Color(nsColor: .secondarySystemFill),
            hoverRow: Color(nsColor: .secondarySystemFill).opacity(0.6),
            track: .black.opacity(0.28),
            primary: Color(nsColor: .labelColor),
            // Row labels and session names sit back; only the figures and the caption titles
            // take the full label colour.
            body: Color(nsColor: .labelColor).opacity(0.72),
            secondary: Color(nsColor: .secondaryLabelColor),
            tertiary: Color(nsColor: .tertiaryLabelColor),
            buttonFill: Color(nsColor: .tertiarySystemFill),
            icon: Color(nsColor: .secondaryLabelColor),
            dotRing: Color(nsColor: .windowBackgroundColor),
            bodyWeight: .light
        )

        static let light = Glass(
            backgroundTop: .white.opacity(0.72),
            backgroundBottom: Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255).opacity(0.68),
            border: .white.opacity(0.6),
            hairline: .black.opacity(0.08),
            groupFill: .white.opacity(0.7),
            selectedRow: .white.opacity(0.8),
            hoverRow: .black.opacity(0.05),
            track: .black.opacity(0.12),
            primary: .black.opacity(0.9),
            body: .black.opacity(0.84),
            secondary: .black.opacity(0.64),
            tertiary: .black.opacity(0.52),
            buttonFill: .white.opacity(0.7),
            icon: .black.opacity(0.6),
            dotRing: .white
        )
    }

    static func glass(_ scheme: ColorScheme) -> Glass {
        scheme == .dark ? .dark : .light
    }
}
