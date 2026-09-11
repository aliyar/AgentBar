import Foundation

/// A snapshot with something in every row, for previews, the screenshot harness and the
/// widget gallery. Every kind of row the panel can draw is here - the plan's windows, a
/// model that meters its own, what is spent past the plan, a balance, credits that reset a
/// limit early, an account on each agent, and a conversation from each - so each can be
/// seen without waiting for an agent to be in exactly that state. The figures are the
/// design handoff's.
extension Snapshot {
    public static var sample: Snapshot {
        let now = Date()
        return Snapshot(
            limits: [
                UsageLimit(agent: .claude, title: "5h", percentUsed: 0.4, resetsAt: now.addingTimeInterval(4 * 3600), windowLength: 5 * 3600),
                UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: 8, resetsAt: now.addingTimeInterval(86400 + 3600), windowLength: 7 * 86400),
                UsageLimit(agent: .claude, title: "Weekly · Fable", percentUsed: 9, resetsAt: now.addingTimeInterval(86400 + 3600), windowLength: 7 * 86400),
                // Spent past the plan: a window with no reset anyone writes.
                UsageLimit(agent: .claude, title: "Extra usage", percentUsed: 31, resetsAt: nil),
                // Shortest window first, and within one window the plan's own row before
                // the model that meters its own - the order `sortedByWindow` produces.
                UsageLimit(agent: .codex, title: "5h", percentUsed: 46, resetsAt: now.addingTimeInterval(2 * 3600), windowLength: 5 * 3600),
                UsageLimit(agent: .codex, title: "5h · Spark", percentUsed: 12, resetsAt: now.addingTimeInterval(3 * 3600), windowLength: 5 * 3600, fullName: "GPT-5.3-Codex-Spark"),
                UsageLimit(agent: .codex, title: "Weekly", percentUsed: 91, resetsAt: now.addingTimeInterval(4 * 86400), windowLength: 7 * 86400),
                UsageLimit(agent: .codex, title: "Weekly · Spark", percentUsed: 5, resetsAt: now.addingTimeInterval(5 * 86400), windowLength: 7 * 86400, fullName: "GPT-5.3-Codex-Spark"),
                UsageLimit(agent: .cursor, title: "Monthly", percentUsed: 63.5, resetsAt: now.addingTimeInterval(9 * 86400 + 5 * 3600), windowLength: 30 * 86400),
                UsageLimit(agent: .cursor, title: "On-demand", percentUsed: 24, resetsAt: now.addingTimeInterval(9 * 86400 + 5 * 3600), windowLength: 30 * 86400),
            ],
            conversations: [
                Conversation(agent: .claude, id: "1", name: "Port the reader into the package and pin the file shapes",
                             project: "agentbar", isBusy: true, pid: 1, contextPercent: 41, contextTokens: 410_000,
                             model: "Fable 5.1", effort: "high", branch: "main", lastActivity: now),
                Conversation(agent: .codex, id: "2", name: "Fix the appcast feed on the site",
                             project: "agentbar", isBusy: true, pid: 2, contextPercent: 22, contextTokens: 220_000,
                             model: "GPT-5", effort: "medium", branch: "site", lastActivity: now.addingTimeInterval(-60)),
                // Cursor writes no context figure, so its chats show none.
                Conversation(agent: .cursor, id: "5", name: "Rename the settings pane and its tests",
                             project: "fetchbar", isBusy: true, pid: 5,
                             model: "Composer", effort: "high", lastActivity: now.addingTimeInterval(-240)),
                Conversation(agent: .claude, id: "3", name: "Done: the landing page builds as a static export.",
                             project: "fetchbar", isBusy: false, pid: 3, contextPercent: 31, contextTokens: 310_000,
                             model: "Opus 5", effort: "medium", branch: "site", lastActivity: now.addingTimeInterval(-600)),
                Conversation(agent: .codex, id: "4", name: "Waiting on review of release script",
                             project: "fetchbar", isBusy: false, pid: 4, contextPercent: 64, contextTokens: 640_000,
                             model: "GPT-5", effort: "high", branch: "release", lastActivity: now.addingTimeInterval(-1200)),
            ],
            lastWritten: [.claude: now, .codex: now.addingTimeInterval(-120), .cursor: now],
            readAt: now,
            accounts: [.claude: AccountStatus(fetchedAt: now), .codex: AccountStatus(fetchedAt: now), .cursor: AccountStatus(fetchedAt: now)],
            credits: [.codex: Credits(balance: 12.4)],
            identities: [.claude: Identity(plan: "Max 20x", email: "you@example.com"),
                         .codex: Identity(plan: "Pro Lite", email: "you@example.com", name: "Your Name"),
                         .cursor: Identity(plan: "Pro", email: "you@example.com")],
            resetCredits: [.codex: ResetCredits(credits: [
                ResetCredits.Credit(expiresAt: now.addingTimeInterval(3 * 86400 + 4 * 3600)),
                ResetCredits.Credit(expiresAt: now.addingTimeInterval(18 * 86400 + 7 * 3600)),
            ])])
    }
}
