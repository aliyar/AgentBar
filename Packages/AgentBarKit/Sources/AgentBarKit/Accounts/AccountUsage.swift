import Foundation

/// Asks an agent's own account how much of each window is used - the only source that
/// knows about the other machines and the time the agent was not running. One GET per
/// agent, read-only, with the sign-in the agent already keeps on this Mac.
///
/// The endpoints are the ones the agents' own tools and the well-known menu bar apps use
/// (CodexBar, Blume); none is documented, so every accessor is defensive and a shape that
/// is not understood reads as a problem, never a crash.
public enum AccountUsage {
    public enum Problem: Error, Equatable, Sendable {
        case notSignedIn
        case unauthorized
        case offline(String)
        case badResponse(Int)
        case unreadable

        /// A few words for the panel.
        public var description: String {
            switch self {
            case .notSignedIn: "not signed in"
            case .unauthorized: "sign in again"
            case .offline: "offline"
            case .badResponse(429): "asked too often"
            case .badResponse(let code): "no answer (\(code))"
            case .unreadable: "unexpected answer"
            }
        }
    }

    /// The limits the account reports, or why it could not be asked.
    public static func fetch(_ agent: Agent, session: URLSession = .shared, now: Date = .now) async -> Result<[UsageLimit], Problem> {
        guard let request = request(for: agent, now: now) else { return .failure(.notSignedIn) }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.offline(error.localizedDescription))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { return .failure(.unauthorized) }
        guard (200..<300).contains(status) else { return .failure(.badResponse(status)) }
        let limits: [UsageLimit] = switch agent {
        case .claude: ClaudeReader.limits(from: data)
        case .codex: codexLimits(from: data)
        case .cursor: cursorLimits(from: data)
        }
        return limits.isEmpty ? .failure(.unreadable) : .success(limits)
    }

    static func request(for agent: Agent, now: Date) -> URLRequest? {
        var request: URLRequest
        switch agent {
        case .claude:
            guard let token = Credentials.claudeAccessToken() else { return nil }
            request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        case .codex:
            guard let codex = Credentials.codex(now: now) else { return nil }
            request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
            request.setValue("Bearer \(codex.accessToken)", forHTTPHeaderField: "Authorization")
            if let account = codex.accountID { request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id") }
        case .cursor:
            guard let cookie = Credentials.cursorSessionCookie(now: now) else { return nil }
            request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.setValue("AgentBar (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        return request
    }

    // MARK: Codex — chatgpt.com/backend-api/wham/usage (shape of 3 Sep 2026)

    struct CodexUsage: Decodable {
        struct Window: Decodable {
            let used_percent: Double?
            let limit_window_seconds: Double?
            let reset_at: Double?
        }
        struct RateLimit: Decodable {
            let primary_window: Window?
            let secondary_window: Window?
        }
        let plan_type: String?
        let rate_limit: RateLimit?
    }

    public static func codexLimits(from data: Data) -> [UsageLimit] {
        guard let usage = try? JSONDecoder().decode(CodexUsage.self, from: data), let limit = usage.rate_limit else { return [] }
        return [limit.primary_window, limit.secondary_window].compactMap { window in
            guard let window, let used = window.used_percent else { return nil }
            let minutes = window.limit_window_seconds.map { $0 / 60 }
            return UsageLimit(agent: .codex, title: CodexReader.title(minutes: minutes), percentUsed: used,
                              resetsAt: window.reset_at.map { Date(timeIntervalSince1970: $0) },
                              windowLength: window.limit_window_seconds.flatMap { $0 > 0 ? $0 : nil })
        }
    }

    // MARK: Cursor — cursor.com/api/usage-summary (shape of 3 Sep 2026)

    struct CursorUsage: Decodable {
        struct Individual: Decodable {
            struct Plan: Decodable {
                let enabled: Bool?
                let totalPercentUsed: Double?
            }
            struct OnDemand: Decodable {
                let enabled: Bool?
                let used: Double?
                let limit: Double?
            }
            let plan: Plan?
            let onDemand: OnDemand?
        }
        let billingCycleStart: String?
        let billingCycleEnd: String?
        let membershipType: String?
        let individualUsage: Individual?
    }

    public static func cursorLimits(from data: Data) -> [UsageLimit] {
        guard let usage = try? JSONDecoder().decode(CursorUsage.self, from: data) else { return [] }
        let start = ISODate.parse(usage.billingCycleStart)
        let end = ISODate.parse(usage.billingCycleEnd)
        let length = zip(start, end).map { $1.timeIntervalSince($0) }
        var limits: [UsageLimit] = []
        if let plan = usage.individualUsage?.plan, plan.enabled != false, let used = plan.totalPercentUsed {
            let plan = usage.membershipType.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Plan"
            limits.append(UsageLimit(agent: .cursor, title: "\(plan) · monthly", percentUsed: used, resetsAt: end, windowLength: length))
        }
        if let demand = usage.individualUsage?.onDemand, demand.enabled == true,
           let used = demand.used, let limit = demand.limit, limit > 0 {
            limits.append(UsageLimit(agent: .cursor, title: "On-demand", percentUsed: used / limit * 100, resetsAt: end, windowLength: length))
        }
        return limits
    }
}

private func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
