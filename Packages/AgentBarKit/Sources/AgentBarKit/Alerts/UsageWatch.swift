import Foundation

/// Decides when a window's use has crossed one of the marks the user asked to hear about.
///
/// Holds no clock and posts nothing: a reading in, the alerts it earns out, the same shape
/// as `StatusWatch`. What it remembers is, per window, the highest mark already announced
/// in the window running now; that is what turns "at or past 80%" on every read into one
/// message at 80% and one at 90%. It is `Codable` so the app can keep it across launches:
/// a restart at 85% has nothing new to say.
public struct UsageWatch: Equatable, Codable, Sendable {
    /// One message: this window has reached this mark.
    public struct Alert: Equatable, Sendable {
        public let limit: UsageLimit
        public let threshold: Int

        public init(limit: UsageLimit, threshold: Int) {
            self.limit = limit
            self.threshold = threshold
        }
    }

    struct Mark: Equatable, Codable, Sendable {
        /// The highest mark announced in this window.
        var threshold: Int
        /// When the window it was announced in ends: a later end is a new window.
        var resetsAt: Date?
    }

    /// A reset date that moves by less than this is the same window read twice; a window
    /// that starts over moves it by its whole length, five hours at the least.
    static let sameWindow: TimeInterval = 30 * 60
    /// How far below its mark a window without a reset date must fall before it is watched
    /// from the start again. Use only goes down when a window starts over, so a real drop
    /// is a new window; the margin keeps two sources a point apart from reading as one.
    static let rearmDrop: Double = 5

    var marks: [String: Mark] = [:]

    public init() {}

    /// Folds one reading in and returns what it crossed. `watching` is the windows the user
    /// chose, by `UsageLimit.id`; `thresholds` the marks, as percentages.
    ///
    /// - A window crosses several marks at once only by being read late; it is announced
    ///   once, at the highest, since "past 80%" beside "past 90%" says the same thing twice.
    /// - A window that has rolled over is history: its figure says nothing about now, so it
    ///   raises nothing and the window is watched from the start again.
    /// - A window that is no longer watched is forgotten, so turning it back on announces
    ///   where it stands.
    public mutating func observe(_ limits: [UsageLimit], watching: Set<String>, thresholds: [Int],
                                 now: Date) -> [Alert] {
        marks = marks.filter { watching.contains($0.key) }
        var alerts: [Alert] = []
        for limit in limits where watching.contains(limit.id) {
            if limit.hasRolledOver(by: now) {
                marks[limit.id] = nil
                continue
            }
            var mark = marks[limit.id]
            if let current = mark, isNewWindow(limit, since: current, now: now) { mark = nil }
            let reached = thresholds.filter { limit.percentUsed >= Double($0) }.max()
            if let reached, reached > (mark?.threshold ?? .min) {
                alerts.append(Alert(limit: limit, threshold: reached))
                mark = Mark(threshold: reached, resetsAt: limit.resetsAt)
            } else if var same = mark, let end = limit.resetsAt {
                // The same window, read again: follow its end as the account restates it.
                same.resetsAt = end
                mark = same
            }
            marks[limit.id] = mark
        }
        return alerts
    }

    private func isNewWindow(_ limit: UsageLimit, since mark: Mark, now: Date) -> Bool {
        if let then = mark.resetsAt {
            if then < now { return true }
            if let end = limit.resetsAt, end.timeIntervalSince(then) > Self.sameWindow { return true }
        }
        return limit.percentUsed < Double(mark.threshold) - Self.rearmDrop
    }
}
