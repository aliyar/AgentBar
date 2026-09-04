import Foundation

/// Decides when a service going down, or coming back, is worth saying out loud.
///
/// It holds no clock, opens no connection and knows nothing about notifications: one
/// reading goes in, at most one announcement comes out. That is what makes the rules below
/// testable, and they are the whole feature - a status page is easy to read and easy to
/// shout about at the wrong moment.
///
/// The rules, each one a mistake this avoids:
///
/// - **The first reading never announces.** Starting the app during an outage would
///   otherwise announce an outage the user is already living through.
/// - **Only a real issue latches.** Maintenance and "we could not tell" change nothing.
/// - **A failed read is not an outage.** `record(nil)` says the page could not be read at
///   all; dropped Wi-Fi looks exactly like a dead service and must never be reported as one.
/// - **Two consecutive readings must agree** before either edge is announced. At the
///   one-minute cadence an outage is polled at, that is two minutes of lateness in
///   exchange for never flapping.
public struct StatusWatch: Equatable, Sendable {
    public enum Transition: Equatable, Sendable {
        case wentDown(StatusLevel)
        case cameBack
    }

    /// What the last announcement said the service was: down, or working. Nil until the
    /// first reading settles it.
    private var isDown: Bool?
    /// The candidate the readings are agreeing on, and how many have agreed so far.
    private var pending: Bool?
    private var agreed = 0

    public init() {}

    /// True once a reading has been taken; a watch that has never read announces nothing.
    public var hasRead: Bool { isDown != nil }

    /// Whether the last settled reading was an issue.
    public var isFailing: Bool { isDown ?? false }

    /// Takes one reading. `nil` means the page could not be read at all - not that it said
    /// everything is fine. Returns the transition to announce, if this reading settled one.
    @discardableResult
    public mutating func record(_ level: StatusLevel?) -> Transition? {
        // Could not read: the last known state stands and nothing is announced. An
        // agreement in progress is abandoned rather than counted - the readings either
        // side of a failure are not consecutive.
        guard let level else {
            pending = nil
            agreed = 0
            return nil
        }
        // Maintenance and unknown are neither an outage nor a recovery. They leave the
        // latch exactly as it was.
        guard level.isIssue || level == .operational else {
            pending = nil
            agreed = 0
            return nil
        }
        let down = level.isIssue

        // The first reading sets the state and says nothing.
        guard let isDown else {
            self.isDown = down
            pending = nil
            agreed = 0
            return nil
        }
        guard down != isDown else {
            // Back to what was already announced: any disagreement in progress is over.
            pending = nil
            agreed = 0
            return nil
        }
        if pending == down {
            agreed += 1
        } else {
            pending = down
            agreed = 1
        }
        guard agreed >= Self.agreementsNeeded else { return nil }
        self.isDown = down
        pending = nil
        agreed = 0
        return down ? .wentDown(level) : .cameBack
    }

    /// How many readings must agree before a change is announced. Two: one is a flake.
    static let agreementsNeeded = 2
}
