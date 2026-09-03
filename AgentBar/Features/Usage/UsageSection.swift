import AppKit
import SwiftUI
import AgentBarKit

/// One agent's rate-limit windows: a caption, then a rounded group with a row per window -
/// label, tick meter, percent used, time until it starts over.
///
/// The meters show what has been **used**, never what is left. One that fills as you
/// spend needs no explaining; one that empties reads as "nearly gone" at exactly the
/// moment you have barely started.
struct UsageSection: View {
    let agent: Agent
    let limits: [UsageLimit]
    /// When the agent last wrote these numbers.
    let written: Date?
    /// What the agent's account said, when it is asked.
    let account: AccountStatus?
    /// What the agent holds against its windows filling: a balance, or an unlimited
    /// allowance. Not a window, so it is said beside the name rather than metered.
    var credits: Credits?
    /// Whose figures these are: the plan, drawn as a badge, and the account it names
    /// when you rest on it.
    var identity: Identity?
    /// When one of the agent's conversations last moved: a window that has rolled over
    /// is projected forward only while the agent is in use.
    let activeSince: Date?
    let now: Date
    /// Show each window's reset as a clock time instead of the time left. Clicking a
    /// time flips it, for every window at once.
    @Binding var showsClock: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let glass = Palette.glass(scheme)
        VStack(alignment: .leading, spacing: 5) {
            GroupCaption(title: agent.title, badge: identity?.plan, badgeHelp: identity?.description(for: agent),
                         trailing: caption, link: agent.usagePage,
                         linkHelp: "Open \(agent.title)'s usage page")
            GroupBox_ {
                if !agent.isInstalled {
                    Note("Not installed — \(agent.folderPath) is not on this Mac")
                } else if limits.isEmpty, let problem = account?.problem {
                    Note(agent == .cursor ? "Cursor's usage comes from its account: \(problem)" : "Nothing on disk yet, and the account says: \(problem)")
                } else if limits.isEmpty {
                    Note("Nothing reported yet")
                } else {
                    ForEach(Array(limits.enumerated()), id: \.element.id) { index, limit in
                        if index > 0 { Rectangle().fill(glass.hairline).frame(height: 0.5) }
                        UsageRow(limit: limit, now: now, activeSince: activeSince, showsClock: $showsClock)
                    }
                }
            }
        }
    }

    /// Said only when it changes the reading, and only one thing at a time: why the
    /// account did not answer, then how old the numbers are, then what is left to spend
    /// once they run out. A balance beside a figure that cannot be trusted would be the
    /// wrong thing to read first.
    private var caption: String? {
        if let problem = account?.problem {
            if let fetched = account?.fetchedAt {
                return "\(problem) · \(Format.short(now.timeIntervalSince(fetched), coarse: true)) ago"
            }
            return problem
        }
        if !limits.isEmpty, let written, now.timeIntervalSince(written) > 3600 {
            return "\(Format.short(now.timeIntervalSince(written), coarse: true)) ago"
        }
        return credits?.caption
    }
}

/// A limit window: what it is, how much of it is gone, and how long until it starts over.
private struct UsageRow: View {
    let limit: UsageLimit
    let now: Date
    let activeSince: Date?
    @Binding var showsClock: Bool

    @Environment(\.colorScheme) private var scheme

    /// The window has already started over, so the figure describes something that no
    /// longer exists. Drawn as absent rather than as a reading - a stale 96 % in red is a
    /// lie the moment its week has rolled.
    private var rolledOver: Bool { limit.hasRolledOver(by: now) }
    /// The end of the window running now, projected past a rollover while the agent is active.
    private var windowEnd: Date? { limit.currentWindowEnd(now: now, activeSince: activeSince) }
    private var level: Palette.Level { Palette.level(rolledOver ? 0 : limit.percentUsed) }
    /// A window that has rolled over with no use since: history, drawn quietly.
    private var dimmed: Bool { rolledOver && windowEnd == nil }

    private var remaining: String? {
        if let windowEnd {
            return showsClock ? Self.clock(windowEnd, now: now) : Format.short(windowEnd.timeIntervalSince(now))
        }
        if rolledOver {
            // Nothing is running, so the next window is the whole window: its length is
            // what is left once it starts. Its clock time is anyone's guess.
            return showsClock ? nil : limit.windowLength.map { Format.short($0) }
        }
        return nil
    }

    /// "14:05" when the window starts over today, "Thu 14:05" when it is another day.
    static func clock(_ date: Date, now: Date) -> String {
        Format.clock(date, now: now)
    }

    /// "Weekly · all models" is too long for its column; the design writes "Weekly · all".
    private var label: String {
        limit.title.replacingOccurrences(of: " · all models", with: " · all")
    }

    var body: some View {
        let glass = Palette.glass(scheme)
        let tint = Palette.color(level, scheme)
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5, weight: glass.bodyWeight))
                .foregroundStyle(dimmed ? glass.tertiary : glass.body)
                .lineLimit(1)
                .frame(width: 86, alignment: .leading)
            TickMeter(fraction: rolledOver ? 0 : limit.percentUsed / 100, tint: tint, dimmed: dimmed)
            // A window that has started over has nothing spent in it yet: 0%, not a dash.
            // The dash stays on the time, since no one has written when the next one ends.
            Text(rolledOver ? Format.percent(0) : Format.percent(limit.percentUsed))
                .font(.system(size: 9.5))
                .monospacedDigit()
                .foregroundStyle(!rolledOver && level == .hot ? tint : glass.tertiary)
                .frame(width: 24, alignment: .trailing)
            Text(remaining ?? (rolledOver ? "—" : ""))
                .font(.system(size: 12.5, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(dimmed ? glass.tertiary : glass.primary)
                .lineLimit(1)
                .fixedSize()
                // 38 pt fits "1d 1h"; "3d 23h" may take a little more, never a second line.
                .frame(minWidth: 38, alignment: .trailing)
                .contentShape(Rectangle())
                // The time is a toggle: time left ⇄ the clock time it starts over.
                .onTapGesture { showsClock.toggle() }
                .tip(showsClock ? "Click for the time left" : "Click for the time it starts over")
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .tip(helpText)
    }

    private var helpText: String {
        if rolledOver, let remaining, windowEnd != nil {
            return "\(limit.title): a new window started when the last one closed; the used figure arrives with the next read. It starts over \(showsClock ? "at" : "in") \(remaining)."
        }
        if rolledOver {
            let whole = limit.windowLength.map { " The next one runs \(Format.short($0)) from first use." } ?? ""
            return "\(limit.title): this window has started over since the figure was written; nothing has been used in the new one yet.\(whole)"
        }
        let named = limit.fullName.map { "\(limit.title) (\($0))" } ?? limit.title
        let window = limit.windowLength.map { " over \(Format.short($0))" } ?? ""
        let used = "\(named): \(Format.percent(limit.percentUsed)) used\(window)"
        guard let remaining else { return used }
        return showsClock ? "\(used), starts over at \(remaining)" : "\(used), starts over in \(remaining)"
    }
}

// MARK: - Shared pieces of a group

/// The line above a group: its name on the left, a short note on the right.
struct GroupCaption: View {
    let title: String
    /// The plan, next to the name: quiet enough to be read second, there for the glance
    /// that asks "which account is this?".
    var badge: String?
    /// What resting on the badge says: the account behind the figures.
    var badgeHelp: String?
    var trailing: String?
    /// A page to open in the browser, offered by a small arrow that shows on hover.
    var link: URL?
    var linkHelp: String = "Open in the browser"

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        let glass = Palette.glass(scheme)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            let name = Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(glass.primary)
            if let link {
                Button { NSWorkspace.shared.open(link) } label: {
                    name.underline(hovering, pattern: .solid)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tip(linkHelp)
                .onHover { hovering = $0 }
            } else {
                name
            }
            if let badge {
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(glass.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(glass.groupFill, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .lineLimit(1)
                    .fixedSize()
                    .tip(badgeHelp ?? "")
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(glass.tertiary)
            }
        }
        .padding(.horizontal, 1)
    }
}

/// The rounded container a group's rows sit in.
struct GroupBox_<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Palette.glass(scheme).groupFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A group with nothing to draw says why, in one quiet line.
struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.glass(scheme).tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
    }
}

#Preview {
    UsageSection(agent: .claude, limits: Snapshot.sample.limits(for: .claude), written: .now, account: nil,
                 credits: Snapshot.sample.credits[.claude], identity: Snapshot.sample.identities[.claude],
                 activeSince: .now, now: .now, showsClock: .constant(false))
        .padding(11)
        .frame(width: 340)
        .background(GlassBackground())
}
