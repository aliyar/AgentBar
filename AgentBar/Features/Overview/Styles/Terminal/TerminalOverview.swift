import AppKit
import SwiftUI
import AgentBarKit

/// The Terminal panel: the glass style's layout drawn as a terminal readout, with the
/// handoff's type, colours and spacing. `agentbar   12:04`, then `[ CLAUDE ]` with a row
/// per window (dotted key, `▌` meter, percent, time left), the same for every agent,
/// `[ ACTIVE · 3 ]` with a `●`/`○` per conversation, and a prompt at the foot:
/// `› ▊` on the left, `:settings :quit` on the right. `:r` (refresh) sits by the clock.
struct TerminalOverview: View {
    let context: OverviewContext

    @Environment(\.colorScheme) private var scheme
    @State private var expandedID: String?
    /// Shared with the glass style and Settings: reset times as clock times.
    @AppStorage("showsResetClock") private var showsClock = false

    static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

    var body: some View {
        let palette = TerminalPalette.of(scheme)
        TimelineView(.periodic(from: .now, by: 30)) { tick in
            VStack(alignment: .leading, spacing: 0) {
                header(palette: palette)
                    .background(palette.band)
                Rectangle().fill(palette.hairline).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 12) {
                    if context.agents.isEmpty {
                        Text("no agents. pick them in :settings")
                            .font(Self.mono(10.5)).foregroundStyle(palette.faint)
                    }
                    ForEach(context.agents) { agent in
                        usage(agent, now: tick.date, palette: palette)
                    }
                    if !context.conversations.isEmpty {
                        Rectangle().fill(palette.bodyHairline).frame(height: 0.5)
                        active(palette: palette)
                    }
                }
                .padding(.top, 11)
                .padding(.horizontal, 13)
                .padding(.bottom, 12)
                Rectangle().fill(palette.hairline).frame(height: 0.5)
                footer(palette: palette)
                    .background(palette.band)
            }
        }
        .background(palette.panel)
    }

    // MARK: Header

    private func header(palette: TerminalPalette) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("agentbar")
                .font(Self.mono(10.5))
                .tracking(0.63)
                .foregroundStyle(palette.title)
            Spacer()
            Command(":r", palette: palette, color: palette.ghost, help: "Read again now (:refresh)", action: context.onRefresh)
                .opacity(context.isRefreshing ? 0.5 : 1)
            Text(context.snapshot.readAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                .font(Self.mono(9.5))
                .monospacedDigit()
                .foregroundStyle(palette.faint)
                .help("When the agents were last read")
                .padding(.leading, 4)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 13)
    }

    // MARK: Usage

    @ViewBuilder
    private func usage(_ agent: Agent, now: Date, palette: TerminalPalette) -> some View {
        let limits = context.snapshot.limits(for: agent)
        let activeSince = context.snapshot.latestActivity(for: agent)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: agent.title, palette: palette)
                Spacer()
                if let note = note(for: agent, limits: limits, now: now) {
                    Text(note).font(Self.mono(9.5)).foregroundStyle(palette.ghost)
                }
            }
            if !agent.isInstalled {
                Text("not installed").font(Self.mono(10.5)).foregroundStyle(palette.faint)
            } else if limits.isEmpty {
                Text(context.snapshot.accounts[agent]?.problem.map { "account: \($0)" } ?? "nothing reported yet")
                    .font(Self.mono(10.5)).foregroundStyle(palette.faint)
            } else {
                ForEach(limits) { limit in
                    let rolled = limit.hasRolledOver(by: now)
                    let used = rolled ? 0 : limit.percentUsed
                    let windowEnd = limit.currentWindowEnd(now: now, activeSince: activeSince)
                    let dimmed = rolled && windowEnd == nil
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Self.label(limit.title))
                            .font(Self.mono(11))
                            .foregroundStyle(dimmed ? palette.faint : palette.key)
                            .lineLimit(1)
                            .frame(width: 100, alignment: .leading)
                        BlockMeter(fraction: used / 100, lit: palette.meter(used), track: palette.meterTrack, dimmed: dimmed)
                        Spacer(minLength: 4)
                        Text(Format.percent(used))
                            .font(Self.mono(9.5))
                            .monospacedDigit()
                            .foregroundStyle(Palette.level(used) == .hot ? palette.alertValue : palette.dim)
                            .frame(width: 30, alignment: .trailing)
                        Text(Self.reset(limit, windowEnd: windowEnd, now: now, clock: showsClock))
                            .font(Self.mono(11))
                            .monospacedDigit()
                            .foregroundStyle(dimmed ? palette.faint : palette.value)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: 40, alignment: .trailing)
                            .contentShape(Rectangle())
                            .onTapGesture { showsClock.toggle() }
                            .help(showsClock ? "Click for the time left" : "Click for the time it starts over")
                    }
                }
            }
        }
    }

    /// `stale 5h` when the numbers are old, or why the account did not answer.
    private func note(for agent: Agent, limits: [UsageLimit], now: Date) -> String? {
        if let problem = context.snapshot.accounts[agent]?.problem { return problem }
        guard !limits.isEmpty, let written = context.snapshot.lastWritten[agent] else { return nil }
        let age = now.timeIntervalSince(written)
        return age > 3600 ? "stale \(Self.compact(age))" : nil
    }

    /// "Session (5h)" → "session.5h", "Weekly · all models" → "weekly.all", "Weekly · Fable" → "weekly.fable".
    static func label(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: " models", with: "")
            .replacingOccurrences(of: " · ", with: ".")
            .replacingOccurrences(of: " (", with: ".")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: ".")
    }

    /// "1d 1h", "4h 52m": the same words as the glass style; the column has the room.
    static func compact(_ seconds: TimeInterval) -> String {
        Format.short(seconds)
    }

    /// The last column: time left, or the clock time the window starts over; a rolled-over
    /// window with no use since shows its full length (nothing on the clock).
    static func reset(_ limit: UsageLimit, windowEnd: Date?, now: Date, clock: Bool) -> String {
        if let windowEnd {
            if clock { return Format.clock(windowEnd, now: now).lowercased() }
            return compact(windowEnd.timeIntervalSince(now))
        }
        if clock { return "—" }
        return limit.windowLength.map { compact($0) } ?? "—"
    }

    // MARK: Active

    private func active(palette: TerminalPalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(text: "ACTIVE · \(context.conversations.count)", palette: palette)
            ForEach(context.conversations) { conversation in
                TerminalConversationRow(conversation: conversation, palette: palette,
                                        expanded: expandedID == conversation.id) {
                    expandedID = expandedID == conversation.id ? nil : conversation.id
                }
            }
        }
    }

    // MARK: Footer

    private func footer(palette: TerminalPalette) -> some View {
        HStack(spacing: 8) {
            Text("›").font(Self.mono(10.5)).foregroundStyle(palette.prompt)
            Blink(period: context.isRefreshing ? 0.55 : 1.1) {
                Text("▊").font(Self.mono(10.5)).foregroundStyle(palette.cursor)
            }
            Spacer()
            Command(":settings", palette: palette, color: palette.key, help: "Settings…", action: context.onSettings)
                .keyboardShortcut(",", modifiers: .command)
            Command(":quit", palette: palette, color: palette.key, help: "Quit AgentBar", action: context.onQuit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
    }
}

// MARK: - Pieces

/// `[ CLAUDE ]`
private struct SectionHeader: View {
    let text: String
    let palette: TerminalPalette

    var body: some View {
        Text("[ \(text.uppercased()) ]")
            .font(TerminalOverview.mono(9.5))
            .tracking(1.33)
            .foregroundStyle(palette.sectionHeader)
    }
}

/// Two runs of `▌` in one row: the lit ones, then the track. A non-zero value lights at
/// least one, as the app's other meters do.
private struct BlockMeter: View {
    let fraction: Double
    let lit: Color
    let track: Color
    var dimmed = false
    var blocks = 10
    var size: CGFloat = 11

    var body: some View {
        let clamped = min(1, max(0, fraction))
        let count = dimmed ? 0 : (clamped > 0 ? max(1, Int((Double(blocks) * clamped).rounded())) : 0)
        (Text(String(repeating: "▌", count: count)).foregroundStyle(lit)
            + Text(String(repeating: "▌", count: blocks - count)).foregroundStyle(track.opacity(dimmed ? 0.6 : 1)))
            .font(TerminalOverview.mono(size))
            .tracking(-0.5)
            .lineLimit(1)
    }
}

/// `● port the reader into the package   ▌▌▌▌▌▌ 41%`
private struct TerminalConversationRow: View {
    let conversation: Conversation
    let palette: TerminalPalette
    let expanded: Bool
    let toggle: () -> Void

    @State private var hovering = false

    private var app: NSRunningApplication? {
        conversation.appPID.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
    }

    private var details: String {
        [app?.localizedName, conversation.model, conversation.effort, conversation.branch]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ").lowercased()
    }

    var body: some View {
        let busy = conversation.isBusy
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if busy {
                    Blink(period: 1.4) {
                        Text("●").font(TerminalOverview.mono(10.5)).foregroundStyle(palette.working)
                    }
                } else {
                    Text("○").font(TerminalOverview.mono(10.5)).foregroundStyle(palette.idle)
                }
                Text(conversation.name.lowercased())
                    .font(TerminalOverview.mono(10.5))
                    .foregroundStyle(busy ? palette.primary : palette.primary.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if let percent = conversation.contextPercent {
                    BlockMeter(fraction: percent / 100, lit: palette.meter(percent), track: palette.meterTrack, blocks: 6, size: 9.5)
                    Text(Format.percent(percent))
                        .font(TerminalOverview.mono(9.5)).monospacedDigit()
                        .foregroundStyle(Palette.level(percent) == .hot ? palette.alertValue : (busy ? palette.dim : palette.ghost))
                        .frame(width: 28, alignment: .trailing)
                } else if let tokens = conversation.contextTokens {
                    Text(Format.compact(tokens))
                        .font(TerminalOverview.mono(9.5)).monospacedDigit()
                        .foregroundStyle(busy ? palette.dim : palette.ghost)
                        .frame(width: 28, alignment: .trailing)
                }
            }
            if expanded, !details.isEmpty {
                Text(details)
                    .font(TerminalOverview.mono(9))
                    .foregroundStyle(palette.faint)
                    .lineLimit(1)
                    .padding(.leading, 17)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(hovering ? palette.hover : .clear))
        .padding(.horizontal, -4)
        .contentShape(Rectangle())
        // First click opens the row; the second brings the app it runs in forward.
        .onTapGesture {
            if expanded { app?.activate() } else { toggle() }
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: expanded)
    }
}

/// A word at the prompt that does something. Lifts and underlines under the pointer.
private struct Command: View {
    let word: String
    let palette: TerminalPalette
    let color: Color
    let help: String
    let action: () -> Void

    init(_ word: String, palette: TerminalPalette, color: Color, help: String, action: @escaping () -> Void) {
        self.word = word
        self.palette = palette
        self.color = color
        self.help = help
        self.action = action
    }

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(word)
                .font(TerminalOverview.mono(10.5))
                .foregroundStyle(hovering ? palette.value : color)
                .underline(hovering, color: palette.meterLit.opacity(0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// A hard terminal blink: full, then nearly off, no easing. Step timing from a periodic
/// timeline, so every blinking thing in the panel keeps exact time.
private struct Blink<Content: View>: View {
    let period: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: period / 2)) { tick in
            let phase = Int((tick.date.timeIntervalSinceReferenceDate / (period / 2)).rounded(.down)) % 2
            content().opacity(phase == 0 ? 1 : 0.12)
        }
    }
}

#Preview("Dark") {
    TerminalOverview(context: OverviewContext(snapshot: .sample, agents: Agent.allCases))
        .frame(width: TerminalStyle.width)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    TerminalOverview(context: OverviewContext(snapshot: .sample, agents: Agent.allCases))
        .frame(width: TerminalStyle.width)
        .preferredColorScheme(.light)
}
