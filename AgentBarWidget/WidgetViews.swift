import SwiftUI
import WidgetKit
import AgentBarKit

/// The widget's own look, on the system's widget material: rounded groups and tick meters
/// in the app's level colours, everything else in the semantic colours so the material's
/// dark and light both read. It is not the panel shrunk - a widget is glanced at, not read.
enum WidgetPalette {
    static let group = Color.primary.opacity(0.06)
    static let track = Color.primary.opacity(0.14)

    /// The widget's ground: near-black or near-white, flat.
    ///
    /// **Opaque on purpose.** The host paints its own backing under the widget in the
    /// system's appearance (white when macOS is light, near-black when it is dark) and a
    /// translucent ground blends with it: a dark widget came out mid-grey on a light Mac
    /// and a light one came out grey on a dark Mac, so the same theme looked like two
    /// different designs. It is not the desktop showing through - that glass is the
    /// system's own.
    static func ground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }
}

/// The family's view for what the entry holds, narrowed to what it was set to show.
struct UsageWidgetView: View {
    let entry: SnapshotEntry
    let family: WidgetFamily

    var body: some View {
        if let snapshot = entry.snapshot {
            let selection = entry.selection
            let limits = snapshot.liveLimits(at: entry.date).filter(selection.keeps)
            switch family {
            case .systemSmall:
                SmallView(limits: limits, chosen: !selection.windowIDs.isEmpty, snapshot: snapshot, now: entry.date)
            case .systemLarge:
                let agents = Set(limits.map(\.agent))
                LargeView(limits: limits,
                          conversations: selection.showsActive ? snapshot.conversations.filter { agents.contains($0.agent) } : [],
                          snapshot: snapshot, now: entry.date)
            default:
                MediumView(limits: limits, snapshot: snapshot, now: entry.date)
            }
        } else {
            NothingYet()
        }
    }
}

// MARK: Small

/// One window as a card; up to three chosen ones as blocks; otherwise a block per agent
/// with its fullest window, so no agent is out of sight.
private struct SmallView: View {
    let limits: [UsageLimit]
    /// Whether the windows were picked, as opposed to everything being shown.
    let chosen: Bool
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        if limits.isEmpty {
            Empty(snapshot: snapshot, now: now)
        } else if limits.count == 1 {
            WindowCard(limit: limits[0], snapshot: snapshot, now: now, scale: 1)
        } else if chosen, limits.count <= 3 {
            Blocks(limits: limits, snapshot: snapshot, now: now)
        } else {
            Blocks(limits: Rows.fit(limits, in: 0), snapshot: snapshot, now: now)
        }
    }
}

/// Who, which window, the figure large, its meter, and the time left. `scale` grows it
/// for the wider families: the figure, the meter and the spacing all follow.
private struct WindowCard: View {
    let limit: UsageLimit
    let snapshot: Snapshot
    let now: Date
    let scale: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = WidgetLevels.color(limit.percentUsed, scheme)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.agent.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if scale > 1, let note = snapshot.staleNote(at: now) {
                    Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Text(limit.shortTitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(Format.percent(limit.percentUsed))
                .font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Ticks(fraction: limit.percentUsed / 100, tint: tint, ticks: scale > 1 ? 48 : 22, height: 8 * scale)
                .padding(.top, 4 * scale)
            HStack(spacing: 4) {
                Text(limit.timeLeft(at: now))
                    .font(.caption.weight(.medium).monospacedDigit())
                Text("left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if scale == 1, let note = snapshot.staleNote(at: now) {
                    Text(note).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            .padding(.top, 6 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A block per window: the agent, the window and its time left, then its meter and
/// figure. Three fit the small family with room to spare.
private struct Blocks: View {
    let limits: [UsageLimit]
    let snapshot: Snapshot
    let now: Date
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Note(snapshot: snapshot, now: now)
            ForEach(limits.prefix(3)) { limit in
                let tint = WidgetLevels.color(limit.percentUsed, scheme)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(limit.agent.title)
                            .font(.caption.weight(.medium))
                        Text(limit.shortTitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(limit.timeLeft(at: now))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Ticks(fraction: limit.percentUsed / 100, tint: tint, ticks: 20, height: 6)
                        Text(Format.percent(limit.percentUsed))
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(WidgetLevels.level(limit.percentUsed) == .calm ? .secondary : tint)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Medium and large

/// Every chosen window as a row, "Claude · Weekly · Fable" naming each; a single window
/// as a card across the width instead.
private struct MediumView: View {
    let limits: [UsageLimit]
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        if limits.isEmpty {
            Empty(snapshot: snapshot, now: now)
        } else if limits.count == 1 {
            WindowCard(limit: limits[0], snapshot: snapshot, now: now, scale: 1.4)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Note(snapshot: snapshot, now: now)
                Groups(limits: Rows.fit(limits, in: 5), now: now, titled: false)
                Spacer(minLength: 0)
            }
        }
    }
}

/// A titled group per agent, then the conversations running right now; a single window
/// as a large card, its agent's conversations under it.
private struct LargeView: View {
    let limits: [UsageLimit]
    let conversations: [Conversation]
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        if limits.isEmpty {
            Empty(snapshot: snapshot, now: now)
        } else if limits.count == 1 {
            VStack(alignment: .leading, spacing: 12) {
                WindowCard(limit: limits[0], snapshot: snapshot, now: now, scale: 2)
                    .frame(maxHeight: 150)
                Active(conversations: conversations.prefix(6))
                Spacer(minLength: 0)
            }
        } else {
            let rows = Rows.fit(limits, in: 6)
            // Ten rows fill the large family; the conversations get what the windows leave.
            VStack(alignment: .leading, spacing: 8) {
                Note(snapshot: snapshot, now: now)
                Groups(limits: rows, now: now, titled: true)
                Active(conversations: conversations.prefix(min(4, max(1, 10 - rows.count))))
                Spacer(minLength: 0)
            }
        }
    }
}

/// How many window rows a family can hold. Past that, one row per agent - its fullest
/// window - so every agent stays on the widget rather than the last ones falling off.
private enum Rows {
    static func fit(_ limits: [UsageLimit], in max: Int) -> [UsageLimit] {
        if limits.count <= max { return limits }
        return Agent.allCases.compactMap { agent in
            limits.filter { $0.agent == agent }.max { $0.percentUsed < $1.percentUsed }
        }
    }
}

/// "as of 12:04", right-aligned, once the app's last read is old enough to matter; the
/// widget carries no title - the desktop knows whose it is from the gallery.
private struct Note: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        if let note = snapshot.staleNote(at: now) {
            Text(note)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// One rounded group per agent, a row per window; titled groups name the agent above the
/// group, untitled ones in each row.
private struct Groups: View {
    let limits: [UsageLimit]
    let now: Date
    let titled: Bool

    var body: some View {
        let agents = Agent.allCases.filter { agent in limits.contains { $0.agent == agent } }
        ForEach(agents) { agent in
            VStack(alignment: .leading, spacing: 3) {
                if titled {
                    Text(agent.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    let rows = limits.filter { $0.agent == agent }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, limit in
                        if index > 0 { Divider().opacity(0.4) }
                        Row(limit: limit, now: now, showsAgent: !titled)
                    }
                }
                .background(WidgetPalette.group, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct Row: View {
    let limit: UsageLimit
    let now: Date
    let showsAgent: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = WidgetLevels.color(limit.percentUsed, scheme)
        HStack(spacing: 8) {
            Text(showsAgent ? "\(limit.agent.title) · \(limit.shortTitle)" : limit.shortTitle)
                .font(.caption)
                .lineLimit(1)
                .frame(width: showsAgent ? 118 : 96, alignment: .leading)
            Ticks(fraction: limit.percentUsed / 100, tint: tint)
            Text(Format.percent(limit.percentUsed))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(WidgetLevels.level(limit.percentUsed) == .hot ? tint : .secondary)
                .frame(width: 30, alignment: .trailing)
            Text(limit.timeLeft(at: now))
                .font(.caption.weight(.medium).monospacedDigit())
                .lineLimit(1)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
    }
}

/// The running conversations under an "Active" caption; nothing when there are none.
private struct Active: View {
    let conversations: ArraySlice<Conversation>

    var body: some View {
        if !conversations.isEmpty {
            Text("Active")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(spacing: 0) {
                ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                    if index > 0 { Divider().opacity(0.4) }
                    ConversationRow(conversation: conversation)
                }
            }
            .background(WidgetPalette.group, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

/// A conversation: a dot that is green while it works, its name, and its context. Tapping
/// it brings the terminal or editor it runs in forward.
private struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Link(destination: URL(string: "agentbar://focus?pid=\(conversation.pid)")!) {
            HStack(spacing: 6) {
                Circle()
                    .fill(conversation.isBusy ? WidgetLevels.color(0, scheme) : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(conversation.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let percent = conversation.contextPercent {
                    Text(Format.percent(percent))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if let tokens = conversation.contextTokens {
                    Text(Format.compact(tokens))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
        }
    }
}

private struct Empty: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing reported yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = snapshot.staleNote(at: now) {
                Text(note).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The meter: a row of ticks, the lit ones showing how much is spent.
private struct Ticks: View {
    let fraction: Double
    let tint: Color
    var ticks = 24
    var height: CGFloat = 8

    var body: some View {
        let clamped = min(1, max(0, fraction))
        let lit = clamped > 0 ? max(1, Int((Double(ticks) * clamped).rounded())) : 0
        HStack(spacing: 1.5) {
            ForEach(0..<ticks, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(index < lit ? tint : WidgetPalette.track)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}
