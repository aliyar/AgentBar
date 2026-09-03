import AppKit
import SwiftUI
import AgentBarKit

/// The conversations running right now, newest activity first: a caption, then a rounded
/// group with a row per conversation - agent mark, name, context meter, percent, chevron.
struct ConversationsSection: View {
    let conversations: [Conversation]

    @Environment(\.colorScheme) private var scheme
    /// Only one row is open at a time.
    @State private var expandedID: String?

    var body: some View {
        let glass = Palette.glass(scheme)
        VStack(alignment: .leading, spacing: 5) {
            GroupCaption(title: "Active")
            GroupBox_ {
                if conversations.isEmpty {
                    // The group stays so the panel keeps its shape; the row says why it is empty.
                    Text("No conversation running right now")
                        .font(.system(size: 11.5))
                        .foregroundStyle(glass.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                    if index > 0 { Rectangle().fill(glass.hairline).frame(height: 0.5) }
                    ConversationRow(conversation: conversation, expanded: expandedID == conversation.id) {
                        expandedID = expandedID == conversation.id ? nil : conversation.id
                    }
                }
            }
        }
    }
}

/// A conversation the agent is running: whether it is working, its name, and how full
/// its context is. One click opens its details; a second brings forward the app it runs
/// in - the terminal or editor the agent was started from.
private struct ConversationRow: View {
    let conversation: Conversation
    let expanded: Bool
    let toggle: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    /// A lookup, not a walk: the reader already found which process owns the window.
    private var app: NSRunningApplication? {
        conversation.appPID.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
    }

    /// The details, each only when there is one: "Ghostty · Fable 5.1 · high · main".
    private var details: [String] {
        [app?.localizedName, conversation.model, conversation.effort, conversation.branch]
            .compactMap { $0 }.filter { !$0.isEmpty }
    }

    private var detailLine: String {
        let parts = details.joined(separator: " · ")
        guard app != nil else { return parts }
        return parts.isEmpty ? "click to focus" : "\(parts) — click to focus"
    }

    var body: some View {
        let glass = Palette.glass(scheme)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                AgentMark(agent: conversation.agent, working: conversation.isBusy)
                Text(conversation.name)
                    .font(.system(size: 11.5, weight: glass.bodyWeight))
                    .foregroundStyle(glass.body)
                    .lineLimit(1)
                    // A sentence is recognised by how it starts, so the end is what
                    // gives way - cutting the middle leaves neither half readable.
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                context
                    .padding(.leading, 6)
                Button(action: toggle) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(glass.tertiary)
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tip("What it is running as")
            }
            if expanded, !detailLine.isEmpty {
                Text(detailLine)
                    .font(.system(size: 9))
                    .foregroundStyle(glass.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 22)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(expanded ? glass.selectedRow : (hovering ? glass.hoverRow : .clear))
        .contentShape(Rectangle())
        // First click opens the row (what it is running as, "click to focus"); the second
        // brings the app it runs in forward.
        .onTapGesture {
            if expanded { app?.activate() } else { toggle() }
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: expanded)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .tip(helpText)
    }

    @ViewBuilder
    private var context: some View {
        let glass = Palette.glass(scheme)
        if let percent = conversation.contextPercent {
            let level = Palette.level(percent)
            ThinBar(fraction: percent / 100, tint: Palette.color(level, scheme))
                .frame(width: 44)
            Text(Format.percent(percent))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(level == .calm ? glass.secondary : Palette.color(level, scheme))
                .lineLimit(1)
                .fixedSize()
                .frame(width: 31, alignment: .trailing)
        } else if let tokens = conversation.contextTokens {
            // The limit is unknown here, so the tokens are the honest figure.
            Text(Format.compact(tokens))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(glass.tertiary)
                .lineLimit(1)
                .frame(width: 44 + 8 + 31, alignment: .trailing)
        }
    }

    private var helpText: String {
        var parts = [conversation.project.isEmpty ? conversation.name : conversation.project]
        parts.append(contentsOf: details)
        parts.append(conversation.isBusy ? "working" : "idle")
        if let percent = conversation.contextPercent {
            parts.append("context \(Format.percent(percent)) full")
        } else if let tokens = conversation.contextTokens {
            parts.append("context \(Format.compact(tokens)) tokens")
        }
        if let name = app?.localizedName { parts.append("click to bring \(name) forward") }
        return parts.joined(separator: " · ")
    }
}

/// The agent's logo in its colour; a green dot in the corner, breathing, while the agent
/// works. The only thing in the panel that moves.
private struct AgentMark: View {
    let agent: Agent
    let working: Bool

    @Environment(\.colorScheme) private var scheme
    @State private var pulsing = false

    var body: some View {
        let glass = Palette.glass(scheme)
        ZStack(alignment: .bottomTrailing) {
            AgentGlyph(agent: agent, size: 12)
                .foregroundStyle(Palette.agent(agent, scheme))
                .frame(width: 14, height: 14)
            if working {
                ZStack {
                    Circle()
                        .fill(Palette.color(.calm, scheme).opacity(0.6))
                        .scaleEffect(pulsing ? 1.8 : 1)
                        .opacity(pulsing ? 0 : 1)
                        .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: pulsing)
                    Circle()
                        .fill(Palette.color(.calm, scheme))
                        .overlay(Circle().strokeBorder(glass.dotRing, lineWidth: 1))
                }
                .frame(width: 6, height: 6)
                .offset(x: 2, y: 2)
                .onAppear { pulsing = true }
            }
        }
        .frame(width: 14, height: 14)
    }
}

#Preview {
    ConversationsSection(conversations: Snapshot.sample.conversations)
        .padding(11)
        .frame(width: 340)
        .background(GlassBackground())
}

/// A thin solid bar for a conversation's context: a capsule track, filled from the left.
/// Quieter than the quota meters' ticks, as befits a secondary figure.
private struct ThinBar: View {
    let fraction: Double
    let tint: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let clamped = min(1, max(0, fraction))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.glass(scheme).track)
                Capsule().fill(tint)
                    // Anything above nothing shows at least a dot's worth.
                    .frame(width: clamped > 0 ? max(3, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: 3)
    }
}
