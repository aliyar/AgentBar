import Foundation

/// A reading per agent for previews, the screenshot harness and the panel's sample data.
/// One agent is unwell on purpose: an outage is the state worth being able to look at
/// without waiting for a real one, and it is the state the row, the roll-up, the incident
/// line and the menu bar mark are all designed around.
public extension ServiceStatus {
    static func sample(for agent: Agent, now: Date = .now) -> ServiceStatus {
        func component(_ name: String, _ level: StatusLevel, watched: Bool = false) -> StatusComponent {
            StatusComponent(id: name, name: name, level: level, isWatched: watched)
        }
        switch agent {
        case .claude:
            return ServiceStatus(
                level: .operational, description: "All Systems Operational",
                components: [component("claude.ai", .operational),
                             component("Claude Console (platform.claude.com)", .operational),
                             component("Claude API (api.anthropic.com)", .operational, watched: true),
                             component("Claude Code", .operational, watched: true),
                             component("Claude Cowork", .operational),
                             component("Claude for Government", .operational)],
                updatedAt: now.addingTimeInterval(-3600), checkedAt: now.addingTimeInterval(-40))
        case .codex:
            return ServiceStatus(
                level: .partial, description: "Partial System Outage",
                components: [component("Responses", .degraded),
                             component("Codex Web", .operational),
                             component("Codex API", .partial, watched: true),
                             component("Chat Completions", .operational)],
                incidents: [Incident(id: "9xz4", name: "Elevated errors for multiple models", impact: .partial,
                                     startedAt: now.addingTimeInterval(-22 * 60),
                                     url: URL(string: "https://stspg.io/9xz4hhmd1jzn"))],
                updatedAt: now.addingTimeInterval(-8 * 60), checkedAt: now.addingTimeInterval(-40))
        case .cursor:
            return ServiceStatus(
                level: .operational, description: "All Systems Operational",
                components: [component("CLI", .operational, watched: true),
                             component("IDE", .operational, watched: true),
                             component("Cloud Agents", .operational),
                             component("cursor.com", .operational)],
                updatedAt: now.addingTimeInterval(-2 * 86400), checkedAt: now.addingTimeInterval(-40))
        }
    }

    /// Every agent's sample reading, keyed as the panel takes them.
    static func sampleAll(now: Date = .now) -> [Agent: ServiceStatus] {
        Dictionary(uniqueKeysWithValues: Agent.allCases.map { ($0, sample(for: $0, now: now)) })
    }
}
