import SwiftUI

/// Terminal: the panel as a terminal readout, from the "Phosphor" design handoff of
/// 3 Sep 2026.
/// Green on near-black, monospaced throughout, lowercase dotted keys, `▌` meters,
/// bracketed section headers, a blinking cursor at the prompt. The handoff draws the
/// dark variant; the light one is the same grid in ink on paper.
enum TerminalStyle: PanelStyle {
    static let id = PanelStyleID.terminal
    static let title = "Terminal"
    static let summary = "A terminal readout: monospaced, green on black, block meters."
    static let features: Set<StyleFeature> = [.resetClock, .conversationDetails, .backgroundOpacity]
    /// Narrower than the glass panel: the mono grid is tighter.
    static let width: CGFloat = 330

    static func overview(_ context: OverviewContext) -> AnyView {
        AnyView(TerminalOverview(context: context))
    }
}

/// The handoff's palette, one set per appearance. Every role is the phosphor green at an
/// opacity, so the light variant only swaps the base inks.
struct TerminalPalette {
    let panel: Color
    /// Header and footer fill.
    let band: Color
    let hairline: Color
    let bodyHairline: Color
    let hover: Color
    /// `agentbar` in the header; the section headers at lower opacity.
    let title: Color
    let sectionHeader: Color
    let key: Color
    let value: Color
    let primary: Color
    let dim: Color
    let faint: Color
    let ghost: Color
    let meterLit: Color
    let meterTrack: Color
    let alertMeter: Color
    let alertValue: Color
    let working: Color
    let idle: Color
    let prompt: Color
    let cursor: Color

    static let dark: TerminalPalette = {
        let green = Color(red: 120 / 255, green: 220 / 255, blue: 160 / 255)
        let mint = Color(red: 160 / 255, green: 240 / 255, blue: 195 / 255)
        let paper = Color(red: 200 / 255, green: 255 / 255, blue: 220 / 255)
        let white = Color(red: 210 / 255, green: 255 / 255, blue: 225 / 255)
        return TerminalPalette(
            panel: Color(red: 15 / 255, green: 19 / 255, blue: 16 / 255),
            band: green.opacity(0.05),
            hairline: green.opacity(0.16),
            bodyHairline: green.opacity(0.14),
            hover: green.opacity(0.07),
            title: mint.opacity(0.9),
            sectionHeader: mint.opacity(0.4),
            key: paper.opacity(0.85),
            value: paper.opacity(0.95),
            primary: white.opacity(0.85),
            dim: mint.opacity(0.5),
            faint: mint.opacity(0.4),
            ghost: mint.opacity(0.3),
            meterLit: green.opacity(0.9),
            meterTrack: green.opacity(0.16),
            alertMeter: Color(red: 1, green: 140 / 255, blue: 120 / 255).opacity(0.95),
            alertValue: Color(red: 1, green: 150 / 255, blue: 130 / 255).opacity(0.95),
            working: green.opacity(0.95),
            idle: mint.opacity(0.3),
            prompt: green.opacity(0.7),
            cursor: green.opacity(0.8)
        )
    }()

    static let light: TerminalPalette = {
        let green = Color(red: 30 / 255, green: 130 / 255, blue: 85 / 255)
        let ink = Color(red: 20 / 255, green: 70 / 255, blue: 45 / 255)
        return TerminalPalette(
            panel: Color(red: 243 / 255, green: 246 / 255, blue: 242 / 255),
            band: green.opacity(0.06),
            hairline: green.opacity(0.22),
            bodyHairline: green.opacity(0.18),
            hover: green.opacity(0.08),
            title: ink.opacity(0.95),
            sectionHeader: ink.opacity(0.5),
            key: ink.opacity(0.9),
            value: ink,
            primary: ink.opacity(0.9),
            dim: ink.opacity(0.6),
            faint: ink.opacity(0.5),
            ghost: ink.opacity(0.38),
            meterLit: green.opacity(0.95),
            meterTrack: green.opacity(0.18),
            alertMeter: Color(red: 205 / 255, green: 75 / 255, blue: 55 / 255).opacity(0.95),
            alertValue: Color(red: 195 / 255, green: 65 / 255, blue: 48 / 255),
            working: green,
            idle: ink.opacity(0.35),
            prompt: green.opacity(0.8),
            cursor: green.opacity(0.85)
        )
    }()

    static func of(_ scheme: ColorScheme) -> TerminalPalette {
        scheme == .dark ? .dark : .light
    }

    /// Green, green at reduced opacity, then coral: the handoff has no amber.
    func meter(_ percent: Double) -> Color {
        switch Palette.level(percent) {
        case .calm: meterLit
        case .warm: meterLit.opacity(0.6)
        case .hot: alertMeter
        }
    }

    func figure(_ percent: Double) -> Color {
        Palette.level(percent) == .hot ? alertValue : value
    }
}
