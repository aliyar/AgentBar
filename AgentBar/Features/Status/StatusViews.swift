import AppKit
import SwiftUI
import AgentBarKit

/// One agent's service, as a single mark before the agent's name.
///
/// A mark and nothing else. The word for what it is doing would be read on every panel
/// open to say "working" almost every time; the colour says as much at a glance, resting
/// on it says the rest, and clicking it opens the whole page.
struct AgentStatusDot: View {
    let agent: Agent
    let status: ServiceStatus?
    /// Why the page could not be read. The last good level stays beside it - a page that
    /// cannot be reached is not a service that is down.
    let problem: String?
    let now: Date
    let open: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: open) {
            StatusDot(level: status?.level, dimmed: !isUnwell)
                // A 6 pt dot is too small to aim at; the target around it is not.
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tip(tip.title, tip.detail)
    }

    /// Something is actually wrong with the service - not merely unread, or under
    /// maintenance. Only this is drawn at full strength.
    private var isUnwell: Bool { status?.level.isIssue == true }

    private var tip: (title: String?, detail: String?) {
        guard let status else {
            return ("\(agent.title) · service status", problem ?? "The status page has not been read yet.")
        }
        let read = status.isFallback
            ? "Read from \(agent.statusPage.host() ?? "the status page")."
            : "Read from \(status.watched.map(\.name).joined(separator: " and "))."
        let checked = "Checked \(Format.short(now.timeIntervalSince(status.checkedAt), coarse: true)) ago."
        let unread = problem.map { " The last read said: \($0)." } ?? ""
        return ("\(agent.title) · \(status.level.title)",
                "\(read) \(checked)\(unread) Click for everything the page lists.")
    }
}

/// The pages about one agent, behind a `⋯` at the end of its line: where it lives, the two
/// pages the panel's own figures come from, and its documentation.
struct AgentLinksMenu: View {
    let agent: Agent

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        Menu {
            ForEach(Array(agent.linkGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 { Divider() }
                ForEach(group) { link in
                    Button {
                        NSWorkspace.shared.open(link.url)
                    } label: {
                        Label(link.title, systemImage: link.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .medium))
                .frame(width: 16, height: 14)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // Both of these sit *outside* the menu. A `Menu` paints its own label in the
        // control colour, so a tint or an opacity applied inside it is discarded; applied
        // here they colour and composite what the menu has already drawn.
        .foregroundStyle(Palette.glass(scheme).tertiary)
        .opacity(hovering ? 1 : 0.35)
        .onHover { hovering = $0 }
        .tip("\(agent.title) on the web", "The two pages this panel reads, and the agent's own.")
    }
}

/// One agent's status, as a screen of its own over the panel.
///
/// Everything the page lists: the components this agent runs on at full strength, the rest
/// as context, whatever incidents are open, and a way to the page itself. A screen rather
/// than a fold because it is a different question from "how much is left" - answering it
/// should not push the meters you were reading off the bottom of the panel.
struct StatusScreen: View {
    let agent: Agent
    let status: ServiceStatus?
    let problem: String?
    let now: Date

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        let glass = Palette.glass(scheme)
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                if let checked {
                    Text(checked)
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(glass.tertiary)
                        .padding(.horizontal, 1)
                }
                GroupBox_ {
                    if let status {
                        summary(status, glass: glass)
                        Rectangle().fill(glass.hairline).frame(height: 0.5)
                        ForEach(status.components) { component in
                            row(component, glass: glass)
                        }
                    } else {
                        Note(problem.map { "The status page could not be read: \($0)." }
                             ?? "The status page has not answered yet.")
                    }
                    // Where all of this came from, under what it produced.
                    source(glass: glass)
                }
            }
            if let status, !status.incidents.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    GroupCaption(title: status.incidents.count == 1 ? "Incident" : "Incidents")
                    GroupBox_ {
                        ForEach(Array(status.incidents.enumerated()), id: \.element.id) { index, incident in
                            if index > 0 { Rectangle().fill(glass.hairline).frame(height: 0.5) }
                            IncidentLine(incident: incident, now: now, indent: 10)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    /// The page all of this was read from, at the foot of what it produced: a way out to
    /// the source, not a heading over it.
    private func source(glass: Palette.Glass) -> some View {
        Button { NSWorkspace.shared.open(agent.statusPage) } label: {
            HStack(spacing: 3) {
                Spacer(minLength: 6)
                Text(agent.statusPage.host() ?? "status page")
                    .underline(hovering, pattern: .solid)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7, weight: .semibold))
            }
            .font(.system(size: 9))
            .foregroundStyle(glass.tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .tip("Open \(agent.title)'s status page")
        .padding(.horizontal, 10)
        .padding(.top, 5)
        .padding(.bottom, 7)
    }

    private var checked: String? {
        guard let status else { return problem }
        let ago = "checked \(Format.short(now.timeIntervalSince(status.checkedAt), coarse: true)) ago"
        return problem.map { "\($0) · \(ago)" } ?? ago
    }

    /// The page's own sentence about itself, over the list it is a summary of.
    @ViewBuilder
    private func summary(_ status: ServiceStatus, glass: Palette.Glass) -> some View {
        HStack(spacing: 8) {
            StatusDot(level: status.level, dimmed: problem != nil)
            Text(status.description ?? status.level.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(glass.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func row(_ component: StatusComponent, glass: Palette.Glass) -> some View {
        HStack(spacing: 8) {
            StatusDot(level: component.level, dimmed: !component.isWatched)
            // The ones this agent runs on are the reading; the rest are context.
            HStack(spacing: 4) {
                Text(component.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(component.isWatched ? glass.secondary : glass.tertiary)
                    .lineLimit(1)
                // Says out loud what the ink strength only implies. An eye rather than a
                // bell: these rows are not switches, and a bell would promise one.
                if component.isWatched {
                    Image(systemName: "eye")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(glass.tertiary)
                }
            }
            Spacer(minLength: 6)
            // Colour is reserved for the components this agent runs on. The rest state
            // their trouble quietly: it is on the page, but it is not yours, and drawing
            // it in red would undo the reason the mapping exists.
            Text(component.level.title)
                .font(.system(size: 9))
                .foregroundStyle(component.isWatched && component.level.isIssue
                                 ? Palette.color(component.level, scheme) : glass.tertiary)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .tip(component.name, component.isWatched
             ? "Watched: \(agent.title) runs on this, and a change here is what raises the alarm. \(component.level.title)."
             : "On the same page, but not what \(agent.title) runs on, so it raises nothing. \(component.level.title).")
    }
}

/// The page's own words about what is happening, and when it started.
struct IncidentLine: View {
    let incident: Incident
    let now: Date
    /// Lines up under rows that begin with a dot; a group of its own needs no indent.
    var indent: CGFloat = 24

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let glass = Palette.glass(scheme)
        Button { if let url = incident.url { NSWorkspace.shared.open(url) } } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(incident.name)
                    .font(.system(size: 10))
                    .foregroundStyle(glass.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if let started = incident.startedAt {
                    Text(Format.short(now.timeIntervalSince(started), coarse: true))
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(glass.tertiary)
                        .fixedSize()
                }
            }
            .padding(.leading, indent)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(incident.url == nil)
        .tip(incident.url == nil ? nil : "Open the incident", incident.name)
    }
}

/// The one mark this feature draws: 6 pt, in the meters' own colours so a dot and a full
/// bar never disagree about what red means. Grey when the level is one nobody can read.
struct StatusDot: View {
    let level: StatusLevel?
    var dimmed = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Circle()
            .fill(level.map { Palette.color($0, scheme) } ?? Palette.glass(scheme).tertiary)
            .opacity(dimmed ? 0.45 : 1)
            .frame(width: 6, height: 6)
    }
}

#Preview("Caption") {
    let now = Date()
    return VStack(alignment: .leading, spacing: 16) {
        ForEach(Agent.allCases) { agent in
            GroupCaption(title: agent.title, badge: "Max 20x", trailing: "$12.40 credits",
                         leading: AnyView(AgentStatusDot(agent: agent,
                                                         status: .sample(for: agent, now: now),
                                                         problem: nil, now: now) {}),
                         accessory: AnyView(AgentLinksMenu(agent: agent)))
        }
    }
    .padding(11)
    .frame(width: 340)
    .background(GlassBackground())
    .preferredColorScheme(.dark)
}

#Preview("Screen") {
    let now = Date()
    return StatusScreen(agent: .codex, status: .sample(for: .codex, now: now), problem: nil, now: now)
        .padding(11)
        .frame(width: 340)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
}
