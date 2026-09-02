import Foundation

/// A conversation running right now.
public struct Conversation: Identifiable, Hashable, Codable, Sendable {
    public let agent: Agent
    public let id: String
    /// What it is about: the last thing said in it, which is what a person recognises a
    /// conversation by. Falls back to the agent's own auto-generated name.
    public let name: String
    /// The project it is working in.
    public let project: String
    public let isBusy: Bool
    /// The agent's own process - what leads back to the window it is running in.
    public let pid: Int
    /// How full its context window is, 0...100 - nil when the limit cannot be known, and
    /// then `contextTokens` is what there is to show. A percentage of an unknown
    /// denominator is a made-up number.
    public let contextPercent: Double?
    /// What the model is carrying, in tokens.
    public let contextTokens: Int?
    /// The model it last answered with, written the way a person would say it.
    public let model: String?
    /// How hard it was told to think - "high", "medium".
    public let effort: String?
    /// The git branch it is working on; what tells two sessions in one project apart.
    public let branch: String?
    /// The process of the app it is running inside: iTerm, Terminal, Cursor. Resolved
    /// once here, so no view walks the process tree while it draws.
    public let appPID: Int?
    /// When the agent last wrote to this session's record - what orders the list.
    public let lastActivity: Date?

    public init(agent: Agent, id: String, name: String, project: String, isBusy: Bool, pid: Int,
                contextPercent: Double? = nil, contextTokens: Int? = nil, model: String? = nil,
                effort: String? = nil, branch: String? = nil, appPID: Int? = nil, lastActivity: Date? = nil) {
        self.agent = agent
        self.id = id
        self.name = name
        self.project = project
        self.isBusy = isBusy
        self.pid = pid
        self.contextPercent = contextPercent
        self.contextTokens = contextTokens
        self.model = model
        self.effort = effort
        self.branch = branch
        self.appPID = appPID
        self.lastActivity = lastActivity
    }
}

extension Array where Element == Conversation {
    /// Whatever moved last comes first - that is the one being watched. A working session
    /// breaks a tie, since it is about to move again anyway.
    public func sortedByActivity() -> [Conversation] {
        sorted { first, second in
            let a = first.lastActivity ?? .distantPast
            let b = second.lastActivity ?? .distantPast
            if a != b { return a > b }
            if first.isBusy != second.isBusy { return first.isBusy }
            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }
}
