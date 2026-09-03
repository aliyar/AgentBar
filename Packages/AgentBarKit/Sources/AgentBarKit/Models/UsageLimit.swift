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
    /// What the title was shortened from, when it was: the row says "Weekly · Spark" and
    /// resting on it says which model that is.
    public let fullName: String?

    public init(agent: Agent, title: String, percentUsed: Double, resetsAt: Date?,
                windowLength: TimeInterval? = nil, fullName: String? = nil) {
        self.agent = agent
        self.title = title
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
        self.windowLength = windowLength
        self.fullName = fullName
    }

    public var id: String { "\(agent.rawValue)|\(title)" }

    /// The window is one model's rather than the whole plan's: "Weekly · Fable".
    var isScoped: Bool { title.contains(" \u{00B7} ") }

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

public extension [UsageLimit] {
    /// Shortest window first - the one that fills soonest is the one being watched - and
    /// within one window the plan's own row before the models that meter their own. A
    /// limit with no window at all (what is spent once the plan is full) sorts last.
    func sortedByWindow() -> [UsageLimit] {
        enumerated().sorted { left, right in
            let a = left.element.windowLength ?? .greatestFiniteMagnitude
            let b = right.element.windowLength ?? .greatestFiniteMagnitude
            if a != b { return a < b }
            let scoped = (left.element.isScoped, right.element.isScoped)
            if scoped.0 != scoped.1 { return !scoped.0 }
            return left.offset < right.offset
        }
        .map(\.element)
    }
}
