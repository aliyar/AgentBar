import Foundation

/// Reads what Codex leaves under `~/.codex`. It keeps no usage file of its own: the limits
/// ride along in the session transcript, in the last `token_count` event. So the newest
/// rollout is found by walking year/month/day (never by listing the thousands of them) and
/// only its tail is read. It is **only as fresh as the last Codex run**.
public enum CodexReader {
    struct RateLimits: Decodable {
        struct Window: Decodable {
            let used_percent: Double?
            let window_minutes: Double?
            let resets_at: Double?
        }
        let primary: Window?
        let secondary: Window?
    }

    struct Line: Decodable {
        struct Payload: Decodable { let rate_limits: RateLimits? }
        let payload: Payload?
    }

    /// The limits from the newest rollout, and when that file was written.
    public static func readLimits(in root: URL) -> (limits: [UsageLimit], written: Date?) {
        guard let file = newestRollout(in: root.appendingPathComponent("sessions")),
              let text = FileTail.read(file) else { return ([], nil) }
        return (limits(fromTranscript: text), FileTail.modificationDate(of: file))
    }

    /// The parsing on its own, testable without a session file on disk.
    public static func limits(fromTranscript text: String) -> [UsageLimit] {
        guard let limits = lastRateLimits(in: text) else { return [] }
        var result: [UsageLimit] = []
        for window in [limits.primary, limits.secondary] {
            guard let window, let used = window.used_percent else { continue }
            result.append(UsageLimit(agent: .codex, title: title(minutes: window.window_minutes),
                                     percentUsed: used,
                                     resetsAt: window.resets_at.map { Date(timeIntervalSince1970: $0) },
                                     windowLength: window.window_minutes.flatMap { $0 > 0 ? $0 * 60 : nil }))
        }
        return result
    }

    static func title(minutes: Double?) -> String {
        guard let minutes, minutes > 0 else { return "Usage" }
        return switch minutes {
        case ..<61: "Hourly"
        case ..<(60 * 24 + 1): "Daily"
        case ..<(60 * 24 * 7 + 1): "Weekly"
        default: "Monthly"
        }
    }

    /// The newest `rollout-*.jsonl`, found by descending the dated folders (year, month, day).
    public static func newestRollout(in sessions: URL) -> URL? {
        let manager = FileManager.default
        var folder = sessions
        for _ in 0..<3 {
            guard let names = try? manager.contentsOfDirectory(atPath: folder.path) else { return nil }
            guard let next = names.filter({ !$0.hasPrefix(".") && !$0.hasSuffix(".jsonl") }).max() else { break }
            folder = folder.appendingPathComponent(next)
        }
        guard let names = try? manager.contentsOfDirectory(atPath: folder.path) else { return nil }
        guard let newest = names.filter({ $0.hasSuffix(".jsonl") }).max() else { return nil }
        return folder.appendingPathComponent(newest)
    }

    private static func lastRateLimits(in text: String) -> RateLimits? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard line.contains("rate_limits"),
                  let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
                  let limits = decoded.payload?.rate_limits,
                  limits.primary != nil || limits.secondary != nil else { continue }
            return limits
        }
        return nil
    }
}
