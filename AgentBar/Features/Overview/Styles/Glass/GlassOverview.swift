import SwiftUI
import AgentBarKit

/// The glass style's panel: a header, each agent's usage in a rounded group, the
/// conversations running right now, and a footer.
///
/// Draws a snapshot and nothing else: no reading, no timers of its own beyond the
/// half-minute tick that keeps the countdowns honest.
struct GlassOverview: View {
    let snapshot: Snapshot
    let agents: [Agent]
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}
    /// The refresh button's state and action; the accounts are asked again.
    var isRefreshing = false
    var onRefresh: () -> Void = {}
    var presentation: PanelPresentation = .popover

    @Environment(\.colorScheme) private var scheme
    /// Reset times as clock times rather than time left; remembered between opens.
    @AppStorage("showsResetClock") private var showsClock = false

    private var conversations: [Conversation] {
        snapshot.conversations.filter { agents.contains($0.agent) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let glass = Palette.glass(scheme)
        VStack(spacing: 0) {
            header(now: now)
            Rectangle().fill(glass.hairline).frame(height: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                if agents.isEmpty {
                    Note("No coding agent to show. AgentBar reads Claude Code and Codex from their own folders in your home directory; pick the agents in Settings.")
                }
                ForEach(agents) { agent in
                    UsageSection(agent: agent, limits: snapshot.limits(for: agent),
                                 written: snapshot.lastWritten[agent], account: snapshot.accounts[agent],
                                 activeSince: snapshot.latestActivity(for: agent), now: now, showsClock: $showsClock)
                }
                if !agents.isEmpty {
                    ConversationsSection(conversations: conversations)
                }
            }
            .padding(11)
            Rectangle().fill(glass.hairline).frame(height: 0.5)
            footer
        }
    }

    private func header(now: Date) -> some View {
        let glass = Palette.glass(scheme)
        let name = HStack(spacing: 7) {
            MarkView(size: 16, tint: glass.primary, cursor: Palette.color(.calm, scheme))
            Text("AgentBar")
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.14)
                .foregroundStyle(glass.primary)
        }
        let controls = HStack(spacing: 8) {
            RefreshButton(isRefreshing: isRefreshing, action: onRefresh)
            // While a read is in flight the clock gives way to a walking "...", then comes
            // back with the new time; the arrow keeps turning beside it.
            Group {
                if isRefreshing {
                    WalkingDots()
                } else {
                    Text(snapshot.readAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                }
            }
            .font(.system(size: 10))
            .monospacedDigit()
            .foregroundStyle(glass.tertiary)
            .frame(width: 30, alignment: .leading)
            .help(isRefreshing ? "Reading…" : "When the agents were last read")
        }
        return Group {
            switch presentation {
            case .popover:
                HStack(alignment: .center, spacing: 8) {
                    name
                    Spacer()
                    controls
                }
            case .window:
                // The window's own title bar is hidden: the traffic lights sit at the
                // left of this header, the name is centred as a title would be.
                ZStack {
                    name
                    HStack {
                        Color.clear.frame(width: PanelPresentation.trafficLightsInset - 12, height: 1)
                        Spacer()
                        controls
                    }
                }
            }
        }
        .padding(.top, 11)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Spacer()
            FooterButton(symbol: "gearshape", help: "Settings…", action: onSettings)
                .keyboardShortcut(",", modifiers: .command)
            FooterButton(symbol: "power", help: "Quit AgentBar", action: onQuit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 11)
    }
}

/// ".", "..", "..." in step while a read is in flight; the same width as the clock it
/// replaces so nothing else moves.
private struct WalkingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 3 + 1
            Text(String(repeating: ".", count: step))
        }
    }
}

/// Asks the agents' accounts again. Turns while a read is in flight.
private struct RefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var turns = 0.0

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.glass(scheme).tertiary)
                .rotationEffect(.degrees(turns))
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Read again now")
        .onChange(of: isRefreshing) { _, refreshing in
            guard refreshing else { return }
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) { turns += 360 }
        }
        .onChange(of: isRefreshing) { _, refreshing in
            if !refreshing { withAnimation(.easeOut(duration: 0.2)) { turns = 0 } }
        }
    }
}

/// One of the two small translucent buttons at the panel's foot.
private struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let glass = Palette.glass(scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(glass.icon)
                .frame(width: 26, height: 24)
                .background(glass.buttonFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The panel's material: the popover's own blur underneath, a translucent gradient over
/// it at the opacity the user chose (Settings › Appearance, with the Glass style), a
/// hairline border around it. The bottom sits a touch more opaque than the top, as the
/// design's gradient did.
struct GlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage(AppSettings.panelOpacityKey) private var opacity = AppSettings.defaultPanelOpacity

    var body: some View {
        let glass = Palette.glass(scheme)
        LinearGradient(colors: [glass.backgroundTop.opacity(opacity), glass.backgroundBottom.opacity(min(1, opacity + 0.06))],
                       startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .top) { glass.border.frame(height: 0.5) }
    }
}

#Preview("Dark") {
    GlassOverview(snapshot: .sample, agents: Agent.allCases)
        .frame(width: 340)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    GlassOverview(snapshot: .sample, agents: Agent.allCases)
        .frame(width: 340)
        .background(GlassBackground())
        .preferredColorScheme(.light)
}
