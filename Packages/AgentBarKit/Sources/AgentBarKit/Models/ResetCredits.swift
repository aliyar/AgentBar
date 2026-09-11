import Foundation

/// Credits that start one of an agent's limits over before its time: an inventory rather
/// than a balance, since each credit carries its own expiry. Codex grants them; the
/// account lists them beside its usage (`wham/rate-limit-reset-credits`).
///
/// Not a window and not money, so neither a meter nor the caption's balance: the panel
/// counts them on a line of their own under the agent's windows, and lists each one's
/// expiry when that line is opened. AgentBar only counts them; it never redeems one.
public struct ResetCredits: Equatable, Codable, Sendable {
    public struct Credit: Equatable, Codable, Sendable {
        /// When it can no longer be used. Nil when the account names no expiry.
        public let expiresAt: Date?
        public let grantedAt: Date?

        public init(expiresAt: Date?, grantedAt: Date? = nil) {
            self.expiresAt = expiresAt
            self.grantedAt = grantedAt
        }
    }

    /// The credits the account reported available, the one that expires first first and
    /// any without an expiry last. Redeemed and expired ones are not kept.
    public let credits: [Credit]

    public init(credits: [Credit]) {
        self.credits = credits.sorted {
            ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture)
        }
    }

    /// The ones still usable at `now`. The account may still call a credit available a
    /// moment after its expiry has passed, and the panel is drawn between reads, so the
    /// expiry is what decides.
    public func available(at now: Date) -> [Credit] {
        credits.filter { $0.expiresAt.map { $0 > now } ?? true }
    }
}
