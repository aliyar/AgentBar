import Foundation

/// One agent's usage, as a reader returns it: the windows it reports, what it holds
/// against running out of them, and when the agent last wrote any of it.
///
/// The same shape serves both sources, since they answer the same question: the files on
/// this Mac, and the agent's own account.
public struct Reading: Equatable, Sendable {
    public var limits: [UsageLimit]
    /// A prepaid balance or an unlimited allowance, when the agent reports one.
    public var credits: Credits?
    /// Whose figures these are: the plan, and the person signed in.
    public var identity: Identity
    /// When the agent wrote these figures; nil for an answer that came from the account.
    public var written: Date?
    /// Credits that start a limit over early, when the account lists them. Only Codex's
    /// account does; nil means not asked or not answered, never "none".
    public var resetCredits: ResetCredits?

    public init(limits: [UsageLimit] = [], credits: Credits? = nil,
                identity: Identity = Identity(), written: Date? = nil,
                resetCredits: ResetCredits? = nil) {
        self.limits = limits
        self.credits = credits
        self.identity = identity
        self.written = written
        self.resetCredits = resetCredits
    }

    public var isEmpty: Bool { limits.isEmpty && credits == nil && identity.isEmpty }

    /// The plan as a person would read it: "prolite" is the agent's spelling, "Pro Lite"
    /// is the plan. Anything unrecognised keeps its own words, tidied - never expanded
    /// into a name the account did not use.
    static func planName(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty else { return nil }
        if let known = ["prolite": "Pro Lite", "freeworkspace": "Free workspace",
                        "free_workspace": "Free workspace", "k12": "K-12"][raw] { return known }
        return raw.split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
