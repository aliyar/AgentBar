import Foundation

/// When an agent's account may be asked again.
///
/// The usage endpoints are undocumented and rate-limited, and nobody outside their owners
/// knows the limit. Claude's is shared by every client holding the same sign-in - Claude
/// Code's own `/usage`, a status line script, this app - so the only safe policy is to ask
/// seldom and to stop when told to. The numbers only move while the agent is used, which
/// is what sets the pace:
///
/// - **An agent that worked since the last answer** is asked every 10 minutes.
/// - **An agent that has not** is asked once an hour, for use made elsewhere (the web,
///   another Mac) that nothing on this one can see.
/// - **The refresh button** asks at most every 2 minutes.
/// - **A refusal (429)** stops every ask, the button's too, for as long as the server
///   says in `Retry-After`; without one, for 15 minutes, doubling with each refusal in a
///   row up to 2 hours. Asking again into a refusal is what kept one going for 17 hours.
///
/// Pure: every clock reading and every signal arrives as an argument.
public struct AccountSchedule: Equatable, Codable, Sendable {
    public enum Trigger: Sendable { case timer, manual }

    /// When the account was last asked, whatever came of it.
    public var lastAttempt: Date?
    /// No ask before this moment: the server refused and said, or was guessed, how long.
    public var blockedUntil: Date?
    /// Refusals in a row; the guessed wait doubles with each.
    public var refusals: Int

    static let whileWorking: TimeInterval = 10 * 60
    static let whileIdle: TimeInterval = 60 * 60
    static let manualFloor: TimeInterval = 2 * 60
    /// With nothing in hand yet, a failure that was not a refusal (offline, signed out)
    /// is tried again sooner than an hour.
    static let untilFirstAnswer: TimeInterval = 5 * 60
    static let firstRefusalWait: TimeInterval = 15 * 60
    static let longestRefusalWait: TimeInterval = 2 * 60 * 60

    public init(lastAttempt: Date? = nil, blockedUntil: Date? = nil, refusals: Int = 0) {
        self.lastAttempt = lastAttempt
        self.blockedUntil = blockedUntil
        self.refusals = refusals
    }

    /// Whether to ask now. `answeredAt` is when the account last gave numbers;
    /// `lastActivity` is when the agent last worked on this Mac.
    public func isDue(_ trigger: Trigger, now: Date, answeredAt: Date?, lastActivity: Date?) -> Bool {
        if let blockedUntil, blockedUntil > now { return false }
        let since = lastAttempt.map { now.timeIntervalSince($0) } ?? .infinity
        if trigger == .manual { return since >= Self.manualFloor }
        guard let answeredAt else { return since >= Self.untilFirstAnswer }
        let worked = lastActivity.map { $0 > answeredAt } ?? false
        return since >= (worked ? Self.whileWorking : Self.whileIdle)
    }

    public mutating func recordAttempt(at now: Date) {
        lastAttempt = now
    }

    public mutating func recordSuccess() {
        blockedUntil = nil
        refusals = 0
    }

    /// The server said "too often". Its own `Retry-After` wins; without one the wait is
    /// guessed, and grows with each refusal in a row.
    public mutating func recordRefusal(retryAfter: Date?, now: Date) {
        refusals += 1
        if let retryAfter, retryAfter > now {
            blockedUntil = retryAfter
        } else {
            let guess = Self.firstRefusalWait * pow(2, Double(refusals - 1))
            blockedUntil = now.addingTimeInterval(min(guess, Self.longestRefusalWait))
        }
    }
}

/// What the app keeps of one agent's account between launches: the last numbers it gave,
/// why the last ask failed, and the schedule. Without it every launch - and a development
/// build launches often - asked straight away, into whatever refusal was still running,
/// and showed nothing until an answer came.
public struct AccountRecord: Equatable, Codable, Sendable {
    public var answer: Reading?
    public var answeredAt: Date?
    public var problem: String?
    public var schedule: AccountSchedule

    public init(answer: Reading? = nil, answeredAt: Date? = nil, problem: String? = nil,
                schedule: AccountSchedule = AccountSchedule()) {
        self.answer = answer
        self.answeredAt = answeredAt
        self.problem = problem
        self.schedule = schedule
    }
}

/// `accounts.json`, beside the widget's snapshot in the App Group container. A debug and
/// a release build share it, as they share the sign-in and so the server's limit.
public struct AccountStore: Sendable {
    public let url: URL

    /// The store in the shared container, or nil without the App Group.
    public init?() {
        guard let container = AppGroup.container else { return nil }
        self.init(directory: container)
    }

    public init(directory: URL) {
        url = directory.appendingPathComponent("accounts.json")
    }

    public func write(_ records: [Agent: AccountRecord]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(records).write(to: url, options: .atomic)
    }

    /// Nothing, rather than a failure, for a file that is missing or no longer understood:
    /// the cost is one early ask.
    public func read() -> [Agent: AccountRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Agent: AccountRecord].self, from: data)) ?? [:]
    }
}
