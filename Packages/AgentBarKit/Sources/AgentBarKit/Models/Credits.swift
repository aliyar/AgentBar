import Foundation

/// What an agent's account holds against the moment its plan runs out: a balance of
/// prepaid credits, or an allowance that is simply unlimited.
///
/// This is not a window and has no reset, so it is never a usage row: it belongs beside
/// the agent's name, not among its meters. A balance that spends into a *limit* is a
/// window and comes back as a `UsageLimit` instead (Claude's extra usage, Cursor's
/// on-demand).
public struct Credits: Equatable, Codable, Sendable {
    /// The balance in whole currency units. Nil when the account reports none.
    public let balance: Double?
    /// ISO currency code; "USD" unless the account says otherwise.
    public let currency: String
    /// The account has an allowance with no ceiling, so a balance means nothing.
    public let isUnlimited: Bool

    public init(balance: Double?, currency: String = "USD", isUnlimited: Bool = false) {
        self.balance = balance
        self.currency = currency
        self.isUnlimited = isUnlimited
    }

    /// Nothing to say: no balance, and no unlimited allowance to mention.
    public var isEmpty: Bool { isUnlimited ? false : (balance ?? 0) <= 0 }

    /// "$12.40 credits", or "unlimited credits". Nil when there is nothing to show.
    public var caption: String? {
        if isUnlimited { return "unlimited credits" }
        guard let balance, balance > 0 else { return nil }
        return "\(Format.money(balance, currency: currency)) credits"
    }
}
