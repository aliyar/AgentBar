import Foundation

/// How a service describes itself, from working to gone. The order is the severity order:
/// a section that shows several services shows the largest of their levels.
///
/// Two vocabularies reach us and neither is ours. A status page states its own overall
/// indicator (`none`, `minor`, `major`, `critical`) and each of its components states a
/// different set (`operational`, `degraded_performance`, …). Both are mapped onto this one
/// in `StatusPage`, so nothing downstream has to know which page it came from.
public enum StatusLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case operational, maintenance, unknown, degraded, partial, outage

    /// Where it sits on the severity scale. Only used to compare.
    var rank: Int {
        switch self {
        case .operational: 0
        case .maintenance: 1
        case .unknown: 2
        case .degraded: 3
        case .partial: 4
        case .outage: 5
        }
    }

    public static func < (lhs: StatusLevel, rhs: StatusLevel) -> Bool { lhs.rank < rhs.rank }

    /// Whether this is the service being broken, as opposed to unknown or planned. Only
    /// these three raise an alarm: a maintenance window is not news, and "we could not
    /// tell" is not an outage.
    public var isIssue: Bool {
        switch self {
        case .degraded, .partial, .outage: true
        case .operational, .maintenance, .unknown: false
        }
    }

    /// What a row says. The words are the status pages' own, so what the panel says and
    /// what the page says when it is opened are the same words.
    public var title: String {
        switch self {
        case .operational: "Operational"
        case .maintenance: "Under maintenance"
        case .unknown: "Status unknown"
        case .degraded: "Degraded performance"
        case .partial: "Partial outage"
        case .outage: "Major outage"
        }
    }
}

/// One service on a status page - "Claude Code", "Codex API", "IDE" - and how it is doing.
public struct StatusComponent: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let level: StatusLevel
    /// One of the components this agent actually runs on (`Agent.statusComponents`). The
    /// others are listed for context and never decide the agent's level.
    public let isWatched: Bool

    public init(id: String, name: String, level: StatusLevel, isWatched: Bool) {
        self.id = id
        self.name = name
        self.level = level
        self.isWatched = isWatched
    }
}

/// An incident the page has open. Resolved ones are history and are not carried.
public struct Incident: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let impact: StatusLevel
    public let startedAt: Date?
    /// The page's own short link to the incident, when it publishes one.
    public let url: URL?

    public init(id: String, name: String, impact: StatusLevel, startedAt: Date?, url: URL?) {
        self.id = id
        self.name = name
        self.impact = impact
        self.startedAt = startedAt
        self.url = url
    }
}

/// One reading of one agent's status page.
public struct ServiceStatus: Equatable, Codable, Sendable {
    /// The worst of the components this agent runs on - not the page's overall indicator.
    /// claude.ai being down while Claude Code is fine is not this agent's problem.
    public var level: StatusLevel
    /// The page's own sentence about itself ("All Systems Operational"), when it has one.
    public var description: String?
    /// Every component the page lists, in its order.
    public var components: [StatusComponent]
    /// The incidents it has open, newest first. Often empty even during an outage.
    public var incidents: [Incident]
    /// When the page says it last changed.
    public var updatedAt: Date?
    /// When it was read here.
    public var checkedAt: Date
    /// `level` came from the page's overall indicator because none of the components this
    /// agent watches was found. A page that renames a component lands here rather than
    /// reporting nothing, and the mapping wants revisiting.
    public var isFallback: Bool

    public init(level: StatusLevel, description: String? = nil, components: [StatusComponent] = [],
                incidents: [Incident] = [], updatedAt: Date? = nil, checkedAt: Date = .now,
                isFallback: Bool = false) {
        self.level = level
        self.description = description
        self.components = components
        self.incidents = incidents
        self.updatedAt = updatedAt
        self.checkedAt = checkedAt
        self.isFallback = isFallback
    }

    /// The components that decided `level`, in the page's order. Empty on a fallback reading.
    public var watched: [StatusComponent] { components.filter(\.isWatched) }

    /// The line a row says beside the level: which of the watched components is unwell, or
    /// the page's own sentence when everything is. Nil when there is nothing to add.
    public var detail: String? {
        let unwell = watched.filter { $0.level.isIssue }
        if !unwell.isEmpty { return unwell.map(\.name).joined(separator: ", ") }
        if let name = incidents.first?.name { return name }
        return nil
    }
}
