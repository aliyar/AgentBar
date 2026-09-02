import SwiftUI
import AgentBarKit

/// One agent's rate-limit windows, each as a meter that fills as you spend.
///
/// The meters show what has been **used**, never what is left. One that fills as you
/// spend needs no explaining; one that empties reads as "nearly gone" at exactly the
/// moment you have barely started.
struct UsageSection: View {
    let agent: Agent
    let limits: [UsageLimit]
    /// When the agent last wrote these numbers.
    let written: Date?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RuledHeading(text: agent.title, symbol: agent.symbol, tint: Palette.agent(agent),
                         trailing: freshnessNote)
            if !agent.isInstalled {
                Text("Not installed — \(agent.folderPath) is not on this Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else if limits.isEmpty {
                Text("Nothing reported yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(limits) { limit in
                        UsageRow(limit: limit, now: now)
                    }
                }
            }
        }
    }

    /// Said only when it changes the reading: how long ago these numbers were written.
    /// Claude keeps its file current on its own, so this stays quiet there.
    private var freshnessNote: String? {
        guard !limits.isEmpty, let written else { return nil }
        let age = now.timeIntervalSince(written)
        guard age > 3600 else { return nil }
        return "\(Format.short(age, coarse: true)) ago"
    }
}

/// A limit window: what it is, how much of it is gone, and how long until it starts over.
private struct UsageRow: View {
    let limit: UsageLimit
    let now: Date

    /// The window has already started over, so the figure describes something that no
    /// longer exists. Drawn as absent rather than as a reading - a stale 96 % in red is a
    /// lie the moment its week has rolled.
    private var rolledOver: Bool { limit.hasRolledOver(by: now) }
    private var tint: Color { Palette.level(limit.percentUsed) }

    private var remaining: String? {
        guard !rolledOver, let resetsAt = limit.resetsAt else { return nil }
        return Format.short(resetsAt.timeIntervalSince(now))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(rolledOver ? "—" : Format.percent(limit.percentUsed))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rolledOver ? Color.secondary : tint)
                    .frame(minWidth: 38, alignment: .leading)
                Text(limit.title)
                    .font(.system(size: 11))
                    .foregroundStyle(rolledOver ? .tertiary : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let remaining {
                    Text(remaining)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            TickMeter(fraction: limit.percentUsed / 100, tint: tint, dimmed: rolledOver)
        }
        .help(helpText)
    }

    private var helpText: String {
        if rolledOver {
            return "\(limit.title): this window has started over since the figure was written, so there is nothing current to show."
        }
        let used = "\(limit.title): \(Format.percent(limit.percentUsed)) used"
        guard let remaining else { return used }
        return "\(used), starts over in \(remaining)"
    }
}

#Preview {
    UsageSection(agent: .claude, limits: Snapshot.sample.limits(for: .claude), written: .now, now: .now)
        .padding(12)
        .frame(width: 340)
}
