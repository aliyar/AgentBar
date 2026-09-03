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

    /// What the account reports, or why it could not be asked.
    public static func fetch(_ agent: Agent, session: URLSession = .shared, now: Date = .now) async -> Result<Reading, Problem> {
        // Read once: the sign-in carries Claude's plan as well as its token.
        let claude = agent == .claude ? Credentials.claude() : nil
        guard let request = request(for: agent, now: now, claude: claude) else { return .failure(.notSignedIn) }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.offline(error.localizedDescription))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { return .failure(.unauthorized) }
        guard (200..<300).contains(status) else { return .failure(.badResponse(status)) }
        var reading: Reading = switch agent {
        case .claude: ClaudeReader.reading(from: data)
        case .codex: codexReading(from: data)
        case .cursor: cursorReading(from: data)
        }
        // Claude states no plan in its usage answer; its sign-in does.
        if let plan = claude?.plan { reading.identity.plan = plan }
        return reading.isEmpty ? .failure(.unreadable) : .success(reading)
    }

    static func request(for agent: Agent, now: Date, claude: Credentials.Claude? = nil) -> URLRequest? {
        var request: URLRequest
        switch agent {
        case .claude:
            guard let token = (claude ?? Credentials.claude())?.accessToken else { return nil }
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

    // MARK: Codex - chatgpt.com/backend-api/wham/usage (shape of 3 Sep 2026)

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
        /// A limit of its own alongside the plan's windows, named for what it meters:
        /// a model with its own allowance (Codex Spark) has one of these.
        struct AdditionalRateLimit: Decodable {
            let limit_name: String?
            let metered_feature: String?
            let rate_limit: RateLimit?
        }
        struct Credits: Decodable {
            let has_credits: Bool?
            let unlimited: Bool?
            let balance: Flexible<Double>?
        }
        let plan_type: String?
        let rate_limit: RateLimit?
        let credits: Credits?
        let additional_rate_limits: [FailableDecodable<AdditionalRateLimit>]?
    }

    public static func codexReading(from data: Data) -> Reading {
        guard let usage = try? JSONDecoder().decode(CodexUsage.self, from: data) else { return Reading() }
        var limits = windows(of: usage.rate_limit)
        // The named limits sit beside the plan's windows, never in place of them; a
        // malformed one is dropped and its siblings still count.
        for extra in (usage.additional_rate_limits ?? []).compactMap(\.value) {
            let name = (extra.limit_name ?? extra.metered_feature)?.trimmingCharacters(in: .whitespaces)
            guard let name, !name.isEmpty else { continue }
            let short = Prose.limitName(name)
            limits += windows(of: extra.rate_limit).map {
                UsageLimit(agent: .codex, title: "\($0.title) \u{00B7} \(short)", percentUsed: $0.percentUsed,
                           resetsAt: $0.resetsAt, windowLength: $0.windowLength,
                           fullName: short == name ? nil : name)
            }
        }
        return Reading(limits: limits.sortedByWindow(), credits: credits(from: usage.credits),
                       identity: Identity(plan: Reading.planName(usage.plan_type)))
    }

    /// The primary and secondary windows of one limit, named by how long they run and
    /// ordered shortest first - `primary` is not always the shorter of the two.
    private static func windows(of limit: CodexUsage.RateLimit?) -> [UsageLimit] {
        [limit?.primary_window, limit?.secondary_window].compactMap { window -> UsageLimit? in
            guard let window, let used = window.used_percent else { return nil }
            let minutes = window.limit_window_seconds.map { $0 / 60 }
            return UsageLimit(agent: .codex, title: CodexReader.title(minutes: minutes), percentUsed: used,
                              resetsAt: window.reset_at.map { Date(timeIntervalSince1970: $0) },
                              windowLength: window.limit_window_seconds.flatMap { $0 > 0 ? $0 : nil })
        }
    }

    private static func credits(from reported: CodexUsage.Credits?) -> Credits? {
        guard let reported else { return nil }
        let unlimited = reported.unlimited == true
        let balance = reported.balance?.value
        guard unlimited || (balance ?? 0) > 0 else { return nil }
        return Credits(balance: balance, isUnlimited: unlimited)
    }

    // MARK: Cursor - cursor.com/api/usage-summary (shape of 3 Sep 2026)

    struct CursorUsage: Decodable {
        /// Every figure below is in minor units: 2000 is $20.00.
        struct Bucket: Decodable {
            let enabled: Bool?
            let used: Double?
            let limit: Double?
        }
        struct Plan: Decodable {
            let enabled: Bool?
            let used: Double?
            let limit: Double?
            let totalPercentUsed: Double?
            let autoPercentUsed: Double?
            let apiPercentUsed: Double?
        }
        struct Individual: Decodable {
            let plan: Plan?
            let onDemand: Bucket?
            /// The personal cap a team or enterprise member spends against, reported
            /// instead of `plan` on those accounts.
            let overall: Bucket?
        }
        struct Team: Decodable {
            let onDemand: Bucket?
            /// The pool the whole team spends from.
            let pooled: Bucket?
        }
        let billingCycleStart: String?
        let billingCycleEnd: String?
        let membershipType: String?
        let isUnlimited: Bool?
        let individualUsage: Individual?
        let teamUsage: Team?
    }

    public static func cursorReading(from data: Data) -> Reading {
        guard let usage = try? JSONDecoder().decode(CursorUsage.self, from: data) else { return Reading() }
        let start = ISODate.parse(usage.billingCycleStart)
        let end = ISODate.parse(usage.billingCycleEnd)
        let length = zip(start, end).map { $1.timeIntervalSince($0) }
        let plan = Reading.planName(usage.membershipType)

        // An unlimited plan has no ceiling to fill, so a percentage of it would be a
        // number about nothing. The account is still shown - as unlimited.
        if usage.isUnlimited == true {
            return Reading(limits: [], credits: Credits(balance: nil, isUnlimited: true),
                           identity: Identity(plan: plan))
        }

        var limits: [UsageLimit] = []
        if let percent = planPercent(in: usage) {
            limits.append(UsageLimit(agent: .cursor, title: "Monthly", percentUsed: percent,
                                     resetsAt: end, windowLength: length))
        }
        for (title, bucket) in [("On-demand", usage.individualUsage?.onDemand),
                                ("Team on-demand", usage.teamUsage?.onDemand)] {
            guard let bucket, bucket.enabled == true,
                  let used = bucket.used, let limit = bucket.limit, limit > 0 else { continue }
            limits.append(UsageLimit(agent: .cursor, title: title, percentUsed: used / limit * 100,
                                     resetsAt: end, windowLength: length))
        }
        return Reading(limits: limits, identity: Identity(plan: plan))
    }

    /// What the headline monthly bar shows, from whichever figure the account reports.
    ///
    /// Cursor answers differently by plan: an individual gets `plan`, a team member gets
    /// a personal cap under `overall`, and an account with neither spends from the team's
    /// pool. Reading only the first of those left the other two with an empty panel.
    private static func planPercent(in usage: CursorUsage) -> Double? {
        if let plan = usage.individualUsage?.plan, plan.enabled != false {
            if let total = plan.totalPercentUsed { return total }
            // The two lanes are the same window measured apart; their mean is the window.
            if let auto = plan.autoPercentUsed, let api = plan.apiPercentUsed { return (auto + api) / 2 }
            if let lane = plan.apiPercentUsed ?? plan.autoPercentUsed { return lane }
            if let used = plan.used, let limit = plan.limit, limit > 0 { return used / limit * 100 }
        }
        for bucket in [usage.individualUsage?.overall, usage.teamUsage?.pooled] {
            guard let bucket, bucket.enabled != false,
                  let used = bucket.used, let limit = bucket.limit, limit > 0 else { continue }
            return used / limit * 100
        }
        return nil
    }
}

private func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
