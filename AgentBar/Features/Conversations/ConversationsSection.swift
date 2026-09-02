import AppKit
import SwiftUI
import AgentBarKit

/// The conversations running right now, newest activity first.
struct ConversationsSection: View {
    let conversations: [Conversation]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RuledHeading(text: "Active")
            ForEach(conversations) { conversation in
                ConversationRow(conversation: conversation)
            }
        }
    }
}

/// A conversation the agent is running: whether it is working, its name, and how full
/// its context is. Clicking it brings forward the app it runs in - the terminal or
/// editor the agent was started from.
private struct ConversationRow: View {
    let conversation: Conversation

    @State private var hovering = false
    @State private var expanded = false
    @State private var pulsing = false

    /// A lookup, not a walk: the reader already found which process owns the window.
    private var app: NSRunningApplication? {
        conversation.appPID.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
    }

    /// The details, each only when there is one: "Cursor · Opus 5 · high · main".
    private var details: [String] {
        [app?.localizedName, conversation.model, conversation.effort, conversation.branch]
            .compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if expanded, !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 20)
                    .padding(.bottom, 3)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.14), value: expanded)
    }

    private var row: some View {
        HStack(spacing: 8) {
            Button(action: focusOwningApp) {
                HStack(spacing: 8) {
                    StatusDot(busy: conversation.isBusy, pulsing: pulsing)
                    Text(conversation.name)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                        // A sentence is recognised by how it starts, so the end is what
                        // gives way - cutting the middle leaves neither half readable.
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    context
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(helpText)

            // Always there, so the row is visibly one that opens; it only brightens under
            // the pointer. Pointing right closed and down open is the disclosure every Mac
            // list uses, and says which way it goes.
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .rotationEffect(.degrees(expanded ? 0 : -90))
                    .foregroundStyle(hovering || expanded ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(details.isEmpty ? 0 : 1)
            .disabled(details.isEmpty)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .help("What it is running as")
        }
        .padding(.vertical, 3)
        // The highlight reaches past the content, but the content keeps the left edge
        // every other row sits on.
        .padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.07) : .clear))
        .padding(.horizontal, -5)
        .onHover { hovering = $0 }
        .onAppear { pulsing = true }
    }

    @ViewBuilder
    private var context: some View {
        if let percent = conversation.contextPercent {
            HStack(spacing: 5) {
                TickMeter(fraction: percent / 100, tint: Palette.level(percent), ticks: 12, height: 7)
                    .frame(width: 34)
                Text(Format.percent(percent))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } else if let tokens = conversation.contextTokens {
            // The limit is unknown here, so the tokens are the honest figure.
            Text(Format.compact(tokens))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }

    private func focusOwningApp() {
        app?.activate()
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

/// Filled and breathing while the agent works, an outline while it waits. One shape for
/// the whole state, and the only thing in the view that moves.
private struct StatusDot: View {
    let busy: Bool
    let pulsing: Bool

    var body: some View {
        ZStack {
            if busy {
                Circle()
                    .fill(Palette.calm.opacity(0.35))
                    .scaleEffect(pulsing ? 2.1 : 1)
                    .opacity(pulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)
                Circle().fill(Palette.calm)
            } else {
                Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.2)
            }
        }
        .frame(width: 7, height: 7)
        .frame(width: 12, height: 12)
    }
}

#Preview {
    ConversationsSection(conversations: Snapshot.sample.conversations)
        .padding(12)
        .frame(width: 340)
}
