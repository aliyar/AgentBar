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
    /// The blocks to draw, in order.
    var sections: [PanelSection] = []
    /// What each agent's status page says, and why one could not be read.
    var statuses: [Agent: ServiceStatus] = [:]
    var statusProblems: [Agent: String] = [:]
    var showsStatus = false
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}
    /// The refresh button's state and action; the accounts are asked again.
    var isRefreshing = false
    var onRefresh: () -> Void = {}
    var presentation: PanelPresentation = .popover
    /// Which screen is showing, and how to get to another.
    var route: PanelRoute = .overview
    var onNavigate: (PanelRoute) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    /// Reset times as clock times rather than time left; remembered between opens.
    @AppStorage("showsResetClock") private var showsClock = false

    private var conversations: [Conversation] {
        snapshot.conversations.filter { agents.contains($0.agent) }
    }

    /// The blocks to draw, or the default arrangement when none was given (previews and
    /// the screenshot harness).
    private var drawn: [PanelSection] {
        sections.isEmpty ? agents.map(PanelSection.agent) + [.conversations] : sections
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
            Group {
                switch route {
                case .overview:
                    overview(now: now)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading))
                            .combined(with: .opacity))
                case .status(let agent):
                    StatusScreen(agent: agent, status: statuses[agent],
                                 problem: statusProblems[agent], now: now)
                        .padding(11)
                        // A pushed screen starts below its title bar, not against it.
                        .padding(.top, 6)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing))
                            .combined(with: .opacity))
                }
            }
            // The screens slide over one another, but the panel must not be clipped while
            // one is half off the edge.
            .clipped()
            Rectangle().fill(glass.hairline).frame(height: 0.5)
            footer
        }
    }

    @ViewBuilder
    private func overview(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if agents.isEmpty {
                Note("No coding agent to show. AgentBar reads Claude Code and Codex from their own folders in your home directory; pick the agents in Settings.")
            }
            ForEach(drawn) { section in
                switch section {
                case .agent(let agent):
                    UsageSection(agent: agent, limits: snapshot.limits(for: agent),
                                 written: snapshot.lastWritten[agent], account: snapshot.accounts[agent],
                                 credits: snapshot.credits[agent], identity: snapshot.identities[agent],
                                 activeSince: snapshot.latestActivity(for: agent), now: now, showsClock: $showsClock,
                                 status: statuses[agent], statusProblem: statusProblems[agent],
                                 showsStatus: showsStatus,
                                 openStatus: { navigate(to: .status(agent)) })
                case .conversations:
                    ConversationsSection(conversations: conversations)
                }
            }
        }
        .padding(11)
    }

    /// The panel's own title bar. On a pushed screen the mark gives way to a back button
    /// and the agent's name, the way a screen that was pushed says where it is and how to
    /// leave — the controls at the right stay where they are throughout.
    private func header(now: Date) -> some View {
        let glass = Palette.glass(scheme)
        let name = Group {
            switch route {
            case .overview:
                HStack(spacing: 7) {
                    MarkView(size: 16, tint: glass.primary, cursor: Palette.color(.calm, scheme))
                    Text("AgentBar")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.14)
                        .foregroundStyle(glass.primary)
                }
            case .status(let agent):
                Button { navigate(to: .overview) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(agent.title) status")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.14)
                    }
                    .foregroundStyle(glass.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tip("Back", "Back to the meters")
                .keyboardShortcut(.escape, modifiers: [])
            }
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
            .tip(isRefreshing ? "Reading…" : "When the agents were last read")
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

    /// One place decides how a screen change looks, so the header and the rows agree.
    private func navigate(to route: PanelRoute) {
        withAnimation(.easeOut(duration: 0.22)) { onNavigate(route) }
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
        .tip("Read again now")
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
        .tip(help)
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
    GlassOverview(snapshot: .sample, agents: Agent.allCases, statuses: ServiceStatus.sampleAll(), showsStatus: true)
        .frame(width: 340)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    GlassOverview(snapshot: .sample, agents: Agent.allCases, statuses: ServiceStatus.sampleAll(), showsStatus: true)
        .frame(width: 340)
        .background(GlassBackground())
        .preferredColorScheme(.light)
}
