import SwiftUI
import WidgetKit
import AgentBarKit

/// The widget only decodes the snapshot the app wrote into the App Group; it reads no
/// agent's folder and asks no account. Tapping it opens the app; tapping a conversation in
/// the large widget brings the terminal or editor it runs in forward.
@main
struct AgentBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    static let kind = "com.greatpixels.AgentBar.usage"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotProvider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
                .widgetURL(URL(string: "agentbar://open"))
        }
        .configurationDisplayName("Agents")
        .description("How much of each coding agent's quota is used, when it starts over, and what is running right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

/// Reads the shared file. A timeline of one entry: the app reloads the widget whenever it
/// writes, and a fresh entry every 15 minutes keeps the "as of" note and the countdowns
/// honest in between.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .sample : SnapshotStore()?.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = SnapshotStore()?.read()
        let entries = (0..<4).map { step in
            SnapshotEntry(date: Date().addingTimeInterval(Double(step) * 15 * 60), snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct UsageWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall: SmallView(snapshot: snapshot, now: entry.date)
            case .systemLarge: LargeView(snapshot: snapshot, now: entry.date)
            default: MediumView(snapshot: snapshot, now: entry.date)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Open AgentBar once")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// The fullest live window as a ring, its figure and its name.
private struct SmallView: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        if let worst = snapshot.worstLimit(at: now) {
            VStack(alignment: .leading, spacing: 4) {
                Gauge(value: worst.percentUsed, in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text(Format.percent(worst.percentUsed))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Levels.color(worst.percentUsed))
                .frame(width: 58, height: 58)
                Spacer(minLength: 0)
                Text(worst.agent.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(worst.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                ResetText(limit: worst, now: now)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Empty(snapshot: snapshot, now: now)
        }
    }
}

/// Every live window as a row: agent, name, meter, percent, time left.
private struct MediumView: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Header(snapshot: snapshot, now: now)
            let live = snapshot.limits.filter { !$0.hasRolledOver(by: now) }
            if live.isEmpty {
                Empty(snapshot: snapshot, now: now)
            } else {
                ForEach(live.prefix(5)) { limit in
                    LimitRow(limit: limit, now: now)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// The windows, then the conversations running right now.
private struct LargeView: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Header(snapshot: snapshot, now: now)
            let live = snapshot.limits.filter { !$0.hasRolledOver(by: now) }
            ForEach(live.prefix(7)) { limit in
                LimitRow(limit: limit, now: now)
            }
            if !snapshot.conversations.isEmpty {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                ForEach(snapshot.conversations.prefix(4)) { conversation in
                    ConversationRow(conversation: conversation)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct Header: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        HStack {
            Text("AgentBar")
                .font(.caption.weight(.semibold))
            Spacer()
            // The widget is only as fresh as the app's last read; say so once it is old.
            if now.timeIntervalSince(snapshot.readAt) > 10 * 60 {
                Text("as of \(snapshot.readAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct LimitRow: View {
    let limit: UsageLimit
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Text("\(limit.agent.title) · \(limit.title)")
                .font(.caption)
                .lineLimit(1)
                .frame(width: 118, alignment: .leading)
            TickMeter(fraction: limit.percentUsed / 100, tint: Levels.color(limit.percentUsed))
            Text(Format.percent(limit.percentUsed))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
            ResetText(limit: limit, now: now)
                .font(.caption.weight(.medium).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        Link(destination: URL(string: "agentbar://focus?pid=\(conversation.pid)")!) {
            HStack(spacing: 6) {
                Circle()
                    .fill(conversation.isBusy ? Levels.calm : Color.secondary.opacity(0.4))
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
        }
    }
}

/// Time left, counting down between the app's writes.
private struct ResetText: View {
    let limit: UsageLimit
    let now: Date

    var body: some View {
        if let resetsAt = limit.resetsAt, resetsAt > now {
            Text(Format.short(resetsAt.timeIntervalSince(now)))
        } else {
            Text("—")
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
            if now.timeIntervalSince(snapshot.readAt) > 10 * 60 {
                Text("as of \(snapshot.readAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A row of ticks, the lit ones showing how much is spent (the app's meter, in fewer ticks).
private struct TickMeter: View {
    let fraction: Double
    let tint: Color
    var ticks = 24

    var body: some View {
        let clamped = min(1, max(0, fraction))
        let lit = clamped > 0 ? max(1, Int((Double(ticks) * clamped).rounded())) : 0
        HStack(spacing: 1.5) {
            ForEach(0..<ticks, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(index < lit ? tint : Color.primary.opacity(0.12))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 8)
    }
}

/// Green, amber, red at the app's thresholds (60 / 85).
private enum Levels {
    static let calm = Color(red: 0.16, green: 0.62, blue: 0.44)
    static let warm = Color(red: 0.85, green: 0.58, blue: 0.14)
    static let hot = Color(red: 0.83, green: 0.29, blue: 0.26)

    static func color(_ percent: Double) -> Color {
        switch percent {
        case ..<60: calm
        case ..<85: warm
        default: hot
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    UsageWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}
