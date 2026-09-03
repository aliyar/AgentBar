import Foundation
import AgentBarKit

/// A snapshot with something in every row, for previews and the screenshot harness. The
/// figures are the design handoff's.
extension Snapshot {
    static var sample: Snapshot {
        let now = Date()
        return Snapshot(
            limits: [
                UsageLimit(agent: .claude, title: "Session (5h)", percentUsed: 0.4, resetsAt: now.addingTimeInterval(4 * 3600), windowLength: 5 * 3600),
                UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: 8, resetsAt: now.addingTimeInterval(86400 + 3600)),
                UsageLimit(agent: .claude, title: "Weekly · Fable", percentUsed: 9, resetsAt: now.addingTimeInterval(86400 + 3600)),
                UsageLimit(agent: .codex, title: "Daily", percentUsed: 46, resetsAt: now.addingTimeInterval(2 * 3600)),
                UsageLimit(agent: .codex, title: "Weekly", percentUsed: 91, resetsAt: now.addingTimeInterval(4 * 86400)),
                UsageLimit(agent: .cursor, title: "Pro · monthly", percentUsed: 63.5, resetsAt: now.addingTimeInterval(9 * 86400 + 5 * 3600), windowLength: 30 * 86400),
            ],
            conversations: [
                Conversation(agent: .claude, id: "1", name: "Port the reader into the package and pin the file shapes",
                             project: "agentbar", isBusy: true, pid: 1, contextPercent: 41, contextTokens: 410_000,
                             model: "Fable 5.1", effort: "high", branch: "main", lastActivity: now),
                Conversation(agent: .codex, id: "2", name: "Fix the appcast feed on the site",
                             project: "agentbar", isBusy: true, pid: 2, contextPercent: 22, contextTokens: 220_000,
                             model: "GPT-5", effort: "medium", branch: "site", lastActivity: now.addingTimeInterval(-60)),
                Conversation(agent: .claude, id: "3", name: "Done — the landing page builds as a static export.",
                             project: "repobar", isBusy: false, pid: 3, contextPercent: 31, contextTokens: 310_000,
                             model: "Opus 5", effort: "medium", branch: "site", lastActivity: now.addingTimeInterval(-600)),
                Conversation(agent: .codex, id: "4", name: "Waiting on review of release script",
                             project: "repobar", isBusy: false, pid: 4, contextPercent: 64, contextTokens: 640_000,
                             model: "GPT-5", effort: "high", branch: "release", lastActivity: now.addingTimeInterval(-1200)),
            ],
            lastWritten: [.claude: now, .codex: now.addingTimeInterval(-120), .cursor: now],
            readAt: now,
            accounts: [.claude: AccountStatus(fetchedAt: now), .codex: AccountStatus(fetchedAt: now), .cursor: AccountStatus(fetchedAt: now)])
    }
}
