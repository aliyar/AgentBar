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

    public init(agent: Agent, title: String, percentUsed: Double, resetsAt: Date?) {
        self.agent = agent
        self.title = title
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
    }

    public var id: String { "\(agent.rawValue)|\(title)" }

    /// True once the window this measured has started over: the figure describes a
    /// window that no longer exists, so it is history, not a reading. Codex only writes
    /// while it runs, so a fortnight-old 96% would otherwise be drawn as today's.
    public func hasRolledOver(by now: Date) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt < now
    }
}
