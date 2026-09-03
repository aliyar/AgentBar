import Foundation

/// Which account an agent's figures belong to: the plan it is on and the person signed
/// in. Both come off this Mac - the agents write them beside the sign-ins they already
/// keep - so neither costs a request.
///
/// The plan is drawn as a small badge beside the agent's name; the rest is what the badge
/// says when you rest on it. It is the answer to "whose numbers am I looking at?", which
/// is worth a glance and never worth a row.
public struct Identity: Equatable, Codable, Sendable {
    /// "Max 20x", "Pro Lite", "Free".
    public var plan: String?
    /// The address the agent is signed in with.
    public var email: String?
    /// The person's name, when the agent keeps one.
    public var name: String?

    public init(plan: String? = nil, email: String? = nil, name: String? = nil) {
        self.plan = plan
        self.email = email
        self.name = name
    }

    public var isEmpty: Bool { plan == nil && email == nil && name == nil }

    /// What resting on the badge says, in two parts: who is signed in, then the account
    /// they are signed in to. A name is the heading when there is one, since that is what
    /// a person recognises first; otherwise the address stands in for it.
    public func tip(for agent: Agent) -> (title: String?, detail: String?) {
        let plan = self.plan.map { "\($0) plan" }
        if let name, !name.isEmpty {
            return (name, [email, plan].compactMap { $0 }.joined(separator: " \u{00B7} "))
        }
        if let email, !email.isEmpty { return (email, plan) }
        return (plan.map { "\(agent.title) \u{00B7} \($0)" }, nil)
    }

    /// Whichever half each source knew: the files name the person, the account names the plan.
    public func merged(with other: Identity) -> Identity {
        Identity(plan: other.plan ?? plan, email: other.email ?? email, name: other.name ?? name)
    }
}
