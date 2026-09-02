import Foundation

/// Reads what Claude Code leaves under `~/.claude`: the rate-limit windows in
/// `cache/usage.json`, the running sessions in `sessions/<pid>.json`, and each session's
/// context from the tail of its transcript in `projects/`.
///
/// The formats are undocumented and Claude Code's to change. Every field is optional on the
/// way in; a shape that is not understood reads as nothing, never as a crash.
public enum ClaudeReader {
    // MARK: Limits

    struct UsageFile: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        struct Limit: Decodable {
            struct Scope: Decodable {
                struct Model: Decodable { let display_name: String? }
                let model: Model?
            }
            let kind: String?
            let percent: Double?
            let resets_at: String?
            let scope: Scope?
        }
        let five_hour: Window?
        let seven_day: Window?
        let limits: [Limit]?
    }

    /// `cache/usage.json`: one small file Claude Code keeps up to date on its own, whether
    /// or not a session is running. Returns the limits and when the file was written.
    public static func readLimits(in root: URL) -> (limits: [UsageLimit], written: Date?) {
        let url = root.appendingPathComponent("cache/usage.json")
        guard let data = try? Data(contentsOf: url) else { return ([], nil) }
        return (limits(from: data), FileTail.modificationDate(of: url))
    }

    /// The parsing on its own, so the shape can be pinned by a test.
    public static func limits(from data: Data) -> [UsageLimit] {
        guard let file = try? JSONDecoder().decode(UsageFile.self, from: data) else { return [] }

        // The `limits` array carries the scoped windows too ("Weekly · Fable"); the two
        // named windows are the fallback for a build that does not write it.
        if let limits = file.limits, !limits.isEmpty {
            let mapped = limits.compactMap { limit -> UsageLimit? in
                guard let percent = limit.percent else { return nil }
                return UsageLimit(agent: .claude, title: title(for: limit),
                                  percentUsed: percent, resetsAt: ISODate.parse(limit.resets_at),
                                  windowLength: windowLength(for: limit.kind))
            }
            if !mapped.isEmpty { return mapped }
        }
        var fallback: [UsageLimit] = []
        if let window = file.five_hour, let used = window.utilization {
            fallback.append(UsageLimit(agent: .claude, title: "Session (5h)", percentUsed: used,
                                       resetsAt: ISODate.parse(window.resets_at), windowLength: 5 * 3600))
        }
        if let window = file.seven_day, let used = window.utilization {
            fallback.append(UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: used,
                                       resetsAt: ISODate.parse(window.resets_at), windowLength: 7 * 86400))
        }
        return fallback
    }

    /// Claude does not write the length; its kinds imply it.
    private static func windowLength(for kind: String?) -> TimeInterval? {
        switch kind {
        case "session": 5 * 3600
        case "weekly_all", "weekly_scoped": 7 * 86400
        default: nil
        }
    }

    private static func title(for limit: UsageFile.Limit) -> String {
        switch limit.kind {
        case "session": "Session (5h)"
        case "weekly_all": "Weekly · all models"
        case "weekly_scoped":
            if let model = limit.scope?.model?.display_name, !model.isEmpty { "Weekly · \(model)" } else { "Weekly · one model" }
        case let other?: other.replacingOccurrences(of: "_", with: " ").capitalized
        case nil: "Limit"
        }
    }

    // MARK: Conversations

    struct SessionFile: Decodable {
        let pid: Int?
        let sessionId: String?
        let cwd: String?
        let name: String?
        let status: String?
        /// Epoch milliseconds; the agent rewrites these as the session moves.
        let updatedAt: Double?
        let statusUpdatedAt: Double?
    }

    /// `sessions/<pid>.json`: one file per running session, with the name Claude Code gave
    /// the conversation and whether it is working right now. A file is left behind when a
    /// session dies, so the process has to still be there.
    public static func conversations(
        in root: URL,
        isRunning: (Int) -> Bool = ProcessTree.isRunning,
        owningApplicationPID: (Int) -> Int? = ProcessTree.owningApplicationPID
    ) -> [Conversation] {
        let folder = root.appendingPathComponent("sessions")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }.compactMap { name -> Conversation? in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
                  let file = try? JSONDecoder().decode(SessionFile.self, from: data),
                  let pid = file.pid, isRunning(pid) else { return nil }
            let project = file.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
            let context = file.cwd.flatMap { cwd in
                file.sessionId.flatMap { contextUse(in: root, cwd: cwd, sessionID: $0) }
            }
            // What was last said names it; the agent's auto-generated name (project plus a
            // number) is the fallback, and tells two sessions apart far less well.
            let label = context?.lastSaid ?? (file.name?.isEmpty == false ? file.name! : project)
            return Conversation(agent: .claude, id: file.sessionId ?? "\(pid)", name: label,
                                project: project, isBusy: file.status == "busy", pid: pid,
                                contextPercent: context?.percent, contextTokens: context?.tokens,
                                model: context?.model, effort: context?.effort, branch: context?.branch,
                                appPID: owningApplicationPID(pid),
                                lastActivity: [file.updatedAt, file.statusUpdatedAt].compactMap { $0 }.max()
                                    .map { Date(timeIntervalSince1970: $0 / 1000) })
        }
        .sortedByActivity()
    }

    // MARK: Context

    public struct ContextUse: Equatable, Sendable {
        /// nil when the limit cannot be known; then `tokens` is what there is to show.
        public let percent: Double?
        public let tokens: Int
        public let model: String?
        public let effort: String?
        public let branch: String?
        public let lastSaid: String?
    }

    struct TranscriptLine: Decodable {
        struct Block: Decodable {
            let type: String?
            let text: String?
        }
        struct Message: Decodable {
            struct Usage: Decodable {
                let input_tokens: Int?
                let cache_read_input_tokens: Int?
                let cache_creation_input_tokens: Int?
            }
            let model: String?
            let usage: Usage?
            /// Only the text blocks matter here; a tool call has nothing to read.
            let content: [FailableDecodable<Block>]?
        }
        let type: String?
        let message: Message?
        let effort: String?
        let gitBranch: String?
    }

    /// The transcript folder is the working directory with its separators flattened.
    static func transcriptURL(in root: URL, cwd: String, sessionID: String) -> URL {
        let folder = cwd.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
        return root.appendingPathComponent("projects/\(folder)/\(sessionID).jsonl")
    }

    static func contextUse(in root: URL, cwd: String, sessionID: String) -> ContextUse? {
        guard let text = FileTail.read(transcriptURL(in: root, cwd: cwd, sessionID: sessionID), bytes: 256 * 1024)
        else { return nil }
        return contextUse(fromTranscript: text)
    }

    /// How full a session's context is, read from the tail of its own transcript: the last
    /// answer's input plus both cache figures is what the model is carrying.
    ///
    /// **The limit is not reliably written anywhere.** `message.model` says `claude-opus-5`
    /// whether the session is the 200K or the 1M one; a fresh session names neither. So the
    /// percentage is offered only when the limit is actually known - a `[1m]` marker anywhere
    /// in the tail, or a context already past 200K, which can only be a 1M one. Otherwise
    /// the tokens are reported and the caller shows those instead of inventing a denominator.
    public static func contextUse(fromTranscript text: String) -> ContextUse? {
        var tokens: Int?
        var model: String?
        var effort: String?
        var branch: String?
        var lastSaid: String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let decoded = try? JSONDecoder().decode(TranscriptLine.self, from: Data(line.utf8)) else { continue }
            if branch == nil, let found = decoded.gitBranch, !found.isEmpty { branch = found }
            // The most recent thing actually said - a turn made only of tool calls has
            // nothing to show, so the scan keeps going back until it finds words.
            if lastSaid == nil, decoded.type == "assistant" || decoded.type == "user",
               let blocks = decoded.message?.content {
                let said = blocks.compactMap(\.value).last { $0.type == "text" && !($0.text ?? "").isEmpty }?.text
                lastSaid = said.map { Prose.oneLine($0) }
            }
            // The newest answer carries the token figures, but a working session's last
            // turns are often tool calls with nothing said in them - so the scan keeps
            // going back for the words even once the numbers are in hand.
            if tokens == nil, let usage = decoded.message?.usage {
                tokens = (usage.input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0)
                    + (usage.cache_creation_input_tokens ?? 0)
                model = decoded.message?.model
                effort = decoded.effort
            }
            if tokens != nil, lastSaid != nil, branch != nil { break }
        }
        guard let tokens, tokens > 0 else { return nil }

        let isMillion = text.contains("[1m]") || tokens > 200_000
        let percent = isMillion ? min(100, Double(tokens) / 1_000_000 * 100) : nil
        return ContextUse(percent: percent, tokens: tokens, model: model.map(Prose.modelName),
                          effort: effort, branch: branch, lastSaid: lastSaid)
    }
}
