import Foundation

/// Where each agent says whether it is working, and which part of it we care about.
///
/// Every one of the three publishes a Statuspage-v2-compatible summary, so there is one
/// parser and three addresses. Verified against the live pages on 4 Sep 2026; see
/// `docs/DEVELOPMENT.md` → "Service status" for the shapes and the traps.
public extension Agent {
    /// The page a person opens. `status.anthropic.com` redirects here; the new host is
    /// written out so a redirect is not needed to reach it.
    var statusPage: URL {
        switch self {
        case .claude: URL(string: "https://status.claude.com")!
        case .codex: URL(string: "https://status.openai.com")!
        case .cursor: URL(string: "https://status.cursor.com")!
        }
    }

    /// The machine-readable summary behind that page.
    var statusFeed: URL { statusPage.appendingPathComponent("api/v2/summary.json") }

    /// The components this agent runs on, by the names their pages use, matched by prefix.
    /// The rest of the page is listed in the panel but never decides whether the agent is
    /// unwell: claude.ai going down while Claude Code keeps working is not this agent's
    /// outage, and waking someone for it is the mistake this mapping exists to avoid.
    ///
    /// The names are matched rather than the opaque ids, so what the app watches can be
    /// checked against the page by reading it.
    var statusComponents: [String] {
        switch self {
        // "Claude API" is the endpoint AgentBar itself asks for the usage figures, so an
        // outage there explains a panel that has stopped answering as well as an agent that has.
        case .claude: ["Claude Code", "Claude API"]
        // `chatgpt.com/backend-api/wham` sits behind Codex API; the ChatGPT and web
        // surfaces are not what the CLI runs on.
        case .codex: ["Codex API"]
        // The two ways the agent is run here.
        case .cursor: ["CLI", "IDE"]
        }
    }
}
