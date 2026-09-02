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

    // MARK: Conversations

    struct SessionMeta: Decodable {
        struct Payload: Decodable {
            struct Git: Decodable { let branch: String? }
            let id: String?
            let cwd: String?
            let git: Git?
        }
        let type: String?
        let payload: Payload?
    }

    /// The running Codex sessions: one per `codex` process, matched to the newest rollout
    /// written from the process's working directory. Codex writes no pid anywhere, so the
    /// directory is the link; two sessions in one directory take the two newest rollouts.
    public static func conversations(
        in root: URL,
        processes: [ProcessTree.RunningProcess] = ProcessTree.processes(whosePathContains: "codex"),
        owningApplicationPID: (Int) -> Int? = ProcessTree.owningApplicationPID
    ) -> [Conversation] {
        // The native binary, not the node launcher or a plugin server it spawned.
        let running = processes.filter { $0.path.hasSuffix("/bin/codex") || $0.path.hasSuffix("/codex") }
        guard !running.isEmpty else { return [] }
        let rollouts = recentRollouts(in: root.appendingPathComponent("sessions"), days: 2)
        var taken: Set<URL> = []
        return running.compactMap { process -> Conversation? in
            guard let file = rollouts.first(where: { !taken.contains($0.url) && $0.meta.cwd == process.cwd }) else { return nil }
            taken.insert(file.url)
            guard let text = FileTail.read(file.url, bytes: 256 * 1024) else { return nil }
            let state = SessionState(fromTranscript: text)
            let project = URL(fileURLWithPath: process.cwd).lastPathComponent
            return Conversation(agent: .codex, id: file.meta.id ?? "\(process.pid)",
                                name: state.lastSaid ?? project, project: project,
                                isBusy: state.isBusy, pid: process.pid,
                                contextPercent: state.contextPercent, contextTokens: state.contextTokens,
                                model: state.model, effort: state.effort, branch: file.meta.git?.branch,
                                appPID: owningApplicationPID(process.pid),
                                lastActivity: FileTail.modificationDate(of: file.url))
        }
        .sortedByActivity()
    }

    struct RolloutFile {
        let url: URL
        let meta: SessionMeta.Payload
    }

    /// Today's and the previous days' rollouts, newest first, each with its first line read.
    static func recentRollouts(in sessions: URL, days: Int) -> [RolloutFile] {
        let manager = FileManager.default
        let calendar = Calendar.current
        var files: [URL] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let folder = sessions.appendingPathComponent(String(format: "%04d/%02d/%02d", parts.year!, parts.month!, parts.day!))
            guard let names = try? manager.contentsOfDirectory(atPath: folder.path) else { continue }
            files += names.filter { $0.hasSuffix(".jsonl") }.sorted(by: >).map { folder.appendingPathComponent($0) }
        }
        return files.compactMap { url in
            guard let line = firstLine(of: url),
                  let meta = try? JSONDecoder().decode(SessionMeta.self, from: Data(line.utf8)),
                  meta.type == "session_meta", let payload = meta.payload else { return nil }
            return RolloutFile(url: url, meta: payload)
        }
    }

    /// The first line, read in chunks until its newline: `session_meta` carries the whole
    /// system prompt and runs to tens of kilobytes.
    private static func firstLine(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var data = Data()
        while data.count < 4 * 1024 * 1024 {
            guard let chunk = try? handle.read(upToCount: 64 * 1024), !chunk.isEmpty else { break }
            data.append(chunk)
            if let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
                return String(data: data[..<newline], encoding: .utf8)
            }
        }
        return String(data: data, encoding: .utf8)
    }

    /// What the tail of a rollout says about the session right now.
    public struct SessionState: Equatable, Sendable {
        public var isBusy = false
        public var lastSaid: String?
        public var model: String?
        public var effort: String?
        public var contextPercent: Double?
        public var contextTokens: Int?

        struct Line: Decodable {
            struct Payload: Decodable {
                struct Content: Decodable {
                    let type: String?
                    let text: String?
                }
                struct Info: Decodable {
                    struct Usage: Decodable {
                        let input_tokens: Int?
                        let output_tokens: Int?
                    }
                    let model_context_window: Int?
                    let last_token_usage: Usage?
                }
                let type: String?
                let role: String?
                let content: [FailableDecodable<Content>]?
                let model: String?
                let effort: String?
                let info: Info?
            }
            let type: String?
            let payload: Payload?
        }

        /// Scans back from the end: the newest token count gives the context, the newest
        /// turn event says whether a turn is running, the newest words name the session.
        public init(fromTranscript text: String) {
            var sawTurnEvent = false
            for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
                guard let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
                      let payload = decoded.payload else { continue }
                switch (decoded.type, payload.type) {
                case ("event_msg", "task_started") where !sawTurnEvent:
                    isBusy = true; sawTurnEvent = true
                case ("event_msg", "task_complete") where !sawTurnEvent:
                    isBusy = false; sawTurnEvent = true
                case ("event_msg", "token_count"):
                    if contextTokens == nil, let usage = payload.info?.last_token_usage,
                       let carried = usage.input_tokens, carried > 0 {
                        contextTokens = carried + (usage.output_tokens ?? 0)
                        if let window = payload.info?.model_context_window, window > 0 {
                            contextPercent = min(100, Double(contextTokens!) / Double(window) * 100)
                        }
                    }
                case ("turn_context", _):
                    if model == nil { model = payload.model; effort = payload.effort }
                case ("response_item", "message"):
                    // The last thing actually said by a person or the agent; the harness's own
                    // <environment_context> and developer notes are not conversation.
                    if lastSaid == nil, payload.role == "user" || payload.role == "assistant",
                       let said = payload.content?.compactMap(\.value)
                        .last(where: { ($0.type == "input_text" || $0.type == "output_text") && !($0.text ?? "").isEmpty })?.text,
                       !said.hasPrefix("<") {
                        lastSaid = Prose.oneLine(said)
                    }
                default: break
                }
                if contextTokens != nil, lastSaid != nil, model != nil, sawTurnEvent { break }
            }
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
