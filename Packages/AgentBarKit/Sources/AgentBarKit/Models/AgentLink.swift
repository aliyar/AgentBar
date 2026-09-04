import Foundation

/// A page about an agent worth opening from the panel.
public struct AgentLink: Identifiable, Equatable, Sendable {
    public let title: String
    public let url: URL
    /// SF Symbol for the menu row.
    public let symbol: String

    public var id: String { url.absoluteString }

    public init(_ title: String, _ url: URL, symbol: String) {
        self.title = title
        self.url = url
        self.symbol = symbol
    }
}

public extension Agent {
    /// Where the agent lives on the web, in two groups: first the two pages the panel's
    /// own figures are read from, then the agent's own - its front door, where its plan is
    /// paid for, and its documentation.
    ///
    /// The split is the point of the menu. The first group is "where what I am looking at
    /// came from"; the second is "the agent itself". Anything further - a changelog, a
    /// forum, a pricing page that only restates the billing one - is a browser bookmark's
    /// job, and a menu that lists everything is a menu nobody reads.
    var linkGroups: [[AgentLink]] {
        [[AgentLink("Usage", usagePage, symbol: "gauge.with.needle"),
          AgentLink("Status", statusPage, symbol: "waveform.path.ecg")],
         own]
    }

    /// Flattened, for anywhere that wants one list.
    var links: [AgentLink] { linkGroups.flatMap { $0 } }

    private var own: [AgentLink] {
        switch self {
        case .claude:
            // Claude's settings are fragment-routed panels over `/new`, not paths.
            [AgentLink("Claude", URL(string: "https://claude.ai")!, symbol: "house"),
             AgentLink("Billing", URL(string: "https://claude.ai/new#settings/billing")!, symbol: "creditcard"),
             AgentLink("Claude Code docs", URL(string: "https://docs.claude.com/en/docs/claude-code/overview")!,
                       symbol: "book")]
        case .codex:
            [AgentLink("Codex", URL(string: "https://chatgpt.com/codex")!, symbol: "house"),
             AgentLink("Codex docs", URL(string: "https://developers.openai.com/codex/")!, symbol: "book")]
        case .cursor:
            // Cursor moved its dashboard tabs from a query to a path in 2026.
            [AgentLink("Cursor", URL(string: "https://cursor.com")!, symbol: "house"),
             AgentLink("Billing", URL(string: "https://cursor.com/dashboard/billing")!, symbol: "creditcard"),
             AgentLink("Cursor docs", URL(string: "https://docs.cursor.com")!, symbol: "book")]
        }
    }
}
