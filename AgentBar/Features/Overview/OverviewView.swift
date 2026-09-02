import SwiftUI
import AgentBarKit

/// Everything the app knows about the agents, in one column: the conversations running
/// right now, then each agent's usage. The popover and the Dock window both draw this.
///
/// Draws a snapshot and nothing else: no reading, no timers of its own beyond the
/// half-minute tick that keeps the countdowns honest.
struct OverviewView: View {
    let snapshot: Snapshot
    let agents: [Agent]

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
        VStack(alignment: .leading, spacing: 18) {
            if agents.isEmpty {
                Text("No coding agent to show. AgentBar reads Claude Code and Codex from their own folders in your home directory; pick the agents in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !conversations.isEmpty {
                ConversationsSection(conversations: conversations)
            }
            ForEach(agents) { agent in
                UsageSection(agent: agent, limits: snapshot.limits(for: agent),
                             written: snapshot.lastWritten[agent], now: now)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

#Preview {
    OverviewView(snapshot: .sample, agents: Agent.allCases)
        .frame(width: 340)
}
