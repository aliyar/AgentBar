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
    /// Shared with the glass style and Settings: how opaque the panel is.
    @AppStorage(AppSettings.panelOpacityKey) private var opacity = AppSettings.defaultPanelOpacity

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
                    if !context.agents.isEmpty {
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
        // The popover's own blur shows through as the opacity drops.
        .background(palette.panel.opacity(opacity))
    }

    // MARK: Header

    private func header(palette: TerminalPalette) -> some View {
        let name = HStack(spacing: 6) {
            MarkView(size: 13, tint: palette.title, cursor: palette.meterLit)
            Text("agentbar")
                .font(Self.mono(10.5))
                .tracking(0.63)
                .foregroundStyle(palette.title)
        }
        let controls = HStack(spacing: 4) {
            Command(":r", palette: palette, color: palette.ghost, help: "Read again now (:refresh)", flashes: true, action: context.onRefresh)
                .opacity(context.isRefreshing ? 0.5 : 1)
            // While a read is in flight the clock gives way to a walking "...", then comes
            // back with the new time.
            Group {
                if context.isRefreshing {
                    WalkingDots(palette: palette)
                } else {
                    Text(context.snapshot.readAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                }
            }
            .font(Self.mono(9.5))
            .monospacedDigit()
            .foregroundStyle(palette.faint)
            .frame(width: 34, alignment: .leading)
            .tip(context.isRefreshing ? "Reading…" : "When the agents were last read")
            .padding(.leading, 4)
        }
        return Group {
            switch context.presentation {
            case .popover:
                HStack(alignment: .center, spacing: 6) {
                    name
                    Spacer()
                    controls
                }
            case .window:
                // The traffic lights sit at the left; the name takes the title's place.
                ZStack {
                    name
                    HStack {
                        Color.clear.frame(width: PanelPresentation.trafficLightsInset - 13, height: 1)
                        Spacer()
                        controls
                    }
                }
            }
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
            AgentHeader(agent: agent, identity: context.snapshot.identities[agent],
                        note: note(for: agent, limits: limits, now: now), palette: palette)
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
                            .tip(showsClock ? "Click for the time left" : "Click for the time it starts over")
                    }
                }
            }
        }
    }

    /// One note at a time, in the order that changes the reading: why the account did not
    /// answer, then how old the numbers are, then the balance left once they run out.
    private func note(for agent: Agent, limits: [UsageLimit], now: Date) -> String? {
        if let problem = context.snapshot.accounts[agent]?.problem { return problem }
        if !limits.isEmpty, let written = context.snapshot.lastWritten[agent],
           now.timeIntervalSince(written) > 3600 {
            return "stale \(Self.compact(now.timeIntervalSince(written)))"
        }
        return context.snapshot.credits[agent]?.caption
    }

    /// "Weekly · all models" → "weekly.all", "Session · Spark" → "session.spark".
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
        // A limit that starts over on no date anyone writes (extra usage, credits) has
        // nothing to say here. The dash means "this window has rolled over" and would be
        // read as a reading; blank is the honest column.
        guard limit.resetsAt != nil else { return "" }
        if clock { return "—" }
        return limit.windowLength.map { compact($0) } ?? "—"
    }

    // MARK: Active

    private func active(palette: TerminalPalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(text: "ACTIVE · \(context.conversations.count)", palette: palette)
            if context.conversations.isEmpty {
                Text("nothing running")
                    .font(Self.mono(10.5)).foregroundStyle(palette.faint)
                    .padding(.top, 2)
            }
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

/// `[ CLAUDE ]`, and on hover `:usage`, which opens the agent's own usage page.
private struct AgentHeader: View {
    let agent: Agent
    /// The account, in the readout's own register: the plan lowercase beside the
    /// section's name, the rest said on hover.
    let identity: Identity?
    let note: String?
    let palette: TerminalPalette
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            SectionHeader(text: agent.title, palette: palette)
            if let plan = identity?.plan {
                Text(plan.lowercased())
                    .font(TerminalOverview.mono(9.5))
                    .foregroundStyle(palette.ghost)
                    .lineLimit(1)
                    .fixedSize()
                    .tip(identity?.description(for: agent) ?? "")
            }
            Command(":usage", palette: palette, color: palette.ghost, help: "Open \(agent.title)'s usage page") {
                NSWorkspace.shared.open(agent.usagePage)
            }
            .opacity(hovering ? 1 : 0)
            Spacer()
            if let note {
                Text(note).font(TerminalOverview.mono(9.5)).foregroundStyle(palette.ghost)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

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
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: 31, alignment: .trailing)
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
    /// Inverse video for a moment on click - a terminal's way of showing a key was taken -
    /// for commands whose effect is not otherwise visible right away, like `:r`.
    let flashes: Bool
    let action: () -> Void

    init(_ word: String, palette: TerminalPalette, color: Color, help: String, flashes: Bool = false, action: @escaping () -> Void) {
        self.word = word
        self.palette = palette
        self.color = color
        self.help = help
        self.flashes = flashes
        self.action = action
    }

    @State private var hovering = false
    @State private var flashing = false

    var body: some View {
        Button {
            action()
            guard flashes else { return }
            flashing = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                flashing = false
            }
        } label: {
            Text(word)
                .font(TerminalOverview.mono(10.5))
                .foregroundStyle(flashing ? palette.panel : (hovering ? palette.value : color))
                .underline(hovering && !flashing, color: palette.meterLit.opacity(0.5))
                .padding(.horizontal, 2)
                .background(flashing ? palette.meterLit : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .tip(help)
    }
}

/// ".", "..", "..." in step, the terminal's progress indicator; the same width as the
/// clock it replaces so nothing else moves.
private struct WalkingDots: View {
    let palette: TerminalPalette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 3 + 1
            Text(String(repeating: ".", count: step))
        }
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
