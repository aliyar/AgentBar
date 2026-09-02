import Foundation

/// One limit window an agent reports: how much of it is used, and when it starts over.
public struct UsageLimit: Identifiable, Hashable, Codable, Sendable {
    public let agent: Agent
    /// "Session (5h)", "Weekly · all models", "Weekly · Fable".
    public let title: String
    /// How much of the window has been **used**, 0...100. Not what is left: a bar that
    /// fills as you spend is the only reading of a bar that needs no explaining.
    public let percentUsed: Double
    public let resetsAt: Date?
    /// How long the window runs, when known: what a rolled-over window offers once it is
    /// used again (Claude's session is 5 h, its weekly windows 7 d; Codex writes its own).
    public let windowLength: TimeInterval?

    public init(agent: Agent, title: String, percentUsed: Double, resetsAt: Date?, windowLength: TimeInterval? = nil) {
        self.agent = agent
        self.title = title
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
        self.windowLength = windowLength
    }

    public var id: String { "\(agent.rawValue)|\(title)" }

    /// True once the window this measured has started over: the figure describes a
    /// window that no longer exists, so it is history, not a reading. Codex only writes
    /// while it runs, so a fortnight-old 96% would otherwise be drawn as today's.
    public func hasRolledOver(by now: Date) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt < now
    }

    /// When the window running right now ends. The reported `resetsAt` while it is still
    /// ahead; after it has passed, the same length again from that moment - but only if
    /// the agent has been active since, because a window starts with use. Nothing is
    /// projected for an agent that has not run since the old window closed.
    public func currentWindowEnd(now: Date, activeSince lastActivity: Date?) -> Date? {
        guard let resetsAt else { return nil }
        if resetsAt >= now { return resetsAt }
        guard let windowLength, windowLength > 0, let lastActivity, lastActivity > resetsAt else { return nil }
        let windowsPassed = (now.timeIntervalSince(resetsAt) / windowLength).rounded(.down) + 1
        return resetsAt.addingTimeInterval(windowsPassed * windowLength)
    }
}
