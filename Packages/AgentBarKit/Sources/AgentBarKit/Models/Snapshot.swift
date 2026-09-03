import Foundation

/// Everything one read of the agents' files produced. The app publishes it, writes it for
/// the widget, and the views draw it; nothing downstream reads a file.
public struct Snapshot: Equatable, Codable, Sendable {
    public var limits: [UsageLimit]
    public var conversations: [Conversation]
    /// When each agent's numbers were last written. A figure is only as fresh as the last
    /// time that agent ran - Codex writes its limits mid-session and not otherwise.
    public var lastWritten: [Agent: Date]
    /// When this snapshot was taken.
    public var readAt: Date
    /// What asking each agent's account gave: when it last answered, or why it did not.
    public var accounts: [Agent: AccountStatus]
    /// What each agent holds against running out: a prepaid balance, or an unlimited
    /// allowance. Not a window, so it is drawn beside the agent's name and not as a row.
    public var credits: [Agent: Credits]
    /// Whose figures each agent's are: the plan, and the person signed in.
    public var identities: [Agent: Identity]

    public init(limits: [UsageLimit] = [], conversations: [Conversation] = [],
                lastWritten: [Agent: Date] = [:], readAt: Date = .now,
                accounts: [Agent: AccountStatus] = [:], credits: [Agent: Credits] = [:],
                identities: [Agent: Identity] = [:]) {
        self.limits = limits
        self.conversations = conversations
        self.lastWritten = lastWritten
        self.readAt = readAt
        self.accounts = accounts
        self.credits = credits
        self.identities = identities
    }

    /// Folds one agent's reading in: its windows, its balance, and when it was written.
    public mutating func take(_ reading: Reading, for agent: Agent) {
        limits += reading.limits
        if let credits = reading.credits { self.credits[agent] = credits }
        if !reading.identity.isEmpty {
            identities[agent] = (identities[agent] ?? Identity()).merged(with: reading.identity)
        }
        if let written = reading.written { lastWritten[agent] = written }
    }

    public var isEmpty: Bool { limits.isEmpty && conversations.isEmpty }

    public func limits(for agent: Agent) -> [UsageLimit] { limits.filter { $0.agent == agent } }

    /// The last time any of the agent's conversations moved.
    public func latestActivity(for agent: Agent) -> Date? {
        conversations.filter { $0.agent == agent }.compactMap(\.lastActivity).max()
    }

    /// The live window that is fullest - what the menu bar gauge shows. Rolled-over
    /// windows are history and do not count.
    public func worstLimit(at now: Date = .now) -> UsageLimit? {
        limits.filter { !$0.hasRolledOver(by: now) }.max { $0.percentUsed < $1.percentUsed }
    }
}

/// The state of one agent's account read.
public struct AccountStatus: Equatable, Codable, Sendable {
    /// When the account last answered with numbers.
    public var fetchedAt: Date?
    /// Why the last attempt gave nothing, in words for the panel; nil after a success.
    public var problem: String?

    public init(fetchedAt: Date? = nil, problem: String? = nil) {
        self.fetchedAt = fetchedAt
        self.problem = problem
    }
}
