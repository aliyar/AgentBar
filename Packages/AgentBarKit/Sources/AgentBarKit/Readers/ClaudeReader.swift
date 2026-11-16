import Foundation

/// Reads what Claude Code leaves under `~/.claude`: the running sessions in
/// `sessions/<pid>.json`, each session's context from the tail of its transcript in
/// `projects/`, and parses the rate-limit windows its account answers with.
///
/// **Claude Code writes no usage to disk.** A `cache/usage.json` may be there, but it is
/// a status line script's copy of the account's answer, on the machines that run one, as
/// old as that script's last successful ask; it was once read here as Claude Code's own,
/// and showed numbers hours old beside Claude's live ones. The windows come from the
/// account only (`AccountUsage`), parsed by `reading(from:)` below.
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
            let group: String?
            let percent: Double?
            let resets_at: String?
            let scope: Scope?
        }
        /// `extra_usage`: what the account spends once the plan's windows are full, as a
        /// monthly allowance with its own utilization. Off unless the person turned it on.
        struct ExtraUsage: Decodable {
            let is_enabled: Bool?
            let monthly_limit: Double?
            let used_credits: Double?
            let utilization: Double?
            let currency: String?
        }
        /// `spend`: the prepaid usage credits that cover the same moment. A balance with
        /// no limit is not a window; a limit with a percent is.
        struct Spend: Decodable {
            struct Money: Decodable {
                let amount_minor: Double?
                let currency: String?
                let exponent: Int?

                /// Minor units to whole ones: 1240 with exponent 2 is 12.40.
                var amount: Double? {
                    guard let amount_minor else { return nil }
                    return amount_minor / pow(10, Double(exponent ?? 2))
                }
            }
            let used: Money?
            let limit: Money?
            let balance: Money?
            let percent: Double?
            let enabled: Bool?
        }
        let five_hour: Window?
        let seven_day: Window?
        let limits: [Limit]?
        let extra_usage: ExtraUsage?
        let spend: Spend?
        let cedar_ember: ResetInventory?
    }

    /// `cedar_ember`: the limit resets the account holds, sent only when asked for with
    /// `?cedar_ember=1`. Shape from CodexBar (HEAD `1f6da9b`, 14 Nov 2026); not yet seen
    /// on this Mac. A grant's `id` is the handle that redeems it, so it is never decoded.
    struct ResetInventory: Decodable {
        struct Grant: Decodable {
            let label: String?
            let resets_left: Int?
            let starts_at: String?
            let ends_at: String?
            let paused: Bool?
        }
        let eligible: Bool?
        let grants: [FailableDecodable<Grant>]?
    }

    /// No inventory that size has been seen; one that claims it is malformed, not rich.
    static let mostResets = 50

    /// The resets usable at `now`, one credit per reset: a grant with two left is two.
    /// A grant that is paused, used up, not started or expired is left out, and so is one
    /// whose pause state is not stated. Nil when the account did not answer the question
    /// or the account is not eligible - never "none".
    static func resetCredits(in file: UsageFile, now: Date) -> ResetCredits? {
        guard let inventory = file.cedar_ember, inventory.eligible == true else { return nil }
        // The models that meter a week of their own, to name a reset that gives one back.
        let models = (file.limits ?? []).compactMap { $0.scope?.model?.display_name?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.lowercased() != "all models" }
        var credits: [ResetCredits.Credit] = []
        for grant in (inventory.grants ?? []).compactMap(\.value) {
            guard grant.paused == false, let left = grant.resets_left, left > 0 else { continue }
            let starts = ISODate.parse(grant.starts_at), ends = ISODate.parse(grant.ends_at)
            if let starts, starts > now { continue }
            if let ends, ends <= now { continue }
            // A bound that was sent but cannot be read is not an open one.
            if (grant.starts_at != nil && starts == nil) || (grant.ends_at != nil && ends == nil) { continue }
            guard credits.count + left <= mostResets else { return nil }
            let detail = grant.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sentence = detail?.isEmpty == false ? detail : nil
            credits += Array(repeating: ResetCredits.Credit(expiresAt: ends, grantedAt: starts,
                                                            label: resetKind(sentence, models: models),
                                                            detail: sentence),
                             count: left)
        }
        return ResetCredits(credits: credits)
    }

    /// A grant's label is a sentence ("One full limit reset (November 2026 …)", "New model
    /// launch: one Fable reset …", seen 16 Nov 2026), so the row gets its kind in the words
    /// claude.ai uses: "Full reset", "Fable reset". A sentence that names neither is kept
    /// as it is, and cut by the row.
    static func resetKind(_ sentence: String?, models: [String]) -> String? {
        guard let sentence else { return nil }
        let words = sentence.lowercased()
        if words.contains("full") { return "Full reset" }
        if let model = models.first(where: { words.contains($0.lowercased()) }) { return "\(model) reset" }
        return sentence
    }

    /// What the files say about the account: only who is signed in. The windows are the
    /// account's to report.
    public static func read(home: URL = HomeDirectory.url) -> Reading {
        Reading(identity: identity(home: home))
    }

    /// Who Claude Code is signed in as, from the settings file it keeps beside its folder.
    /// The plan is not written here - it rides in the sign-in itself.
    static func identity(home: URL) -> Identity {
        struct File: Decodable {
            struct Account: Decodable { let emailAddress: String? }
            let oauthAccount: Account?
        }
        guard let data = try? Data(contentsOf: home.appendingPathComponent(".claude.json")),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return Identity() }
        return Identity(email: file.oauthAccount?.emailAddress)
    }

    /// The parsing on its own, so the shape can be pinned by a test.
    public static func reading(from data: Data, now: Date = .now) -> Reading {
        guard let file = try? JSONDecoder().decode(UsageFile.self, from: data) else { return Reading() }
        return Reading(limits: limits(in: file), credits: credits(in: file),
                       resetCredits: resetCredits(in: file, now: now))
    }

    /// The windows, in the order the panel reads them: the session, the weekly window, the
    /// model-scoped weekly windows, then what is spent once they are full.
    ///
    /// The two named windows are the account's own answer for the two that matter, so they
    /// are what the panel shows. `limits[]` is read only for the windows they do not
    /// cover - a scoped week ("Weekly · Fable") - because it is the newer shape and may
    /// one day arrive carrying nothing else.
    static func limits(in file: UsageFile) -> [UsageLimit] {
        var result: [UsageLimit] = []
        if let window = file.five_hour, let used = window.utilization {
            result.append(UsageLimit(agent: .claude, title: "5h", percentUsed: used,
                                     resetsAt: ISODate.parse(window.resets_at), windowLength: 5 * 3600))
        } else if let session = file.limits?.first(where: { $0.kind == "session" }), let percent = session.percent {
            result.append(UsageLimit(agent: .claude, title: "5h", percentUsed: percent,
                                     resetsAt: ISODate.parse(session.resets_at), windowLength: 5 * 3600))
        }
        if let window = file.seven_day, let used = window.utilization {
            result.append(UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: used,
                                     resetsAt: ISODate.parse(window.resets_at), windowLength: 7 * 86400))
        } else if let weekly = file.limits?.first(where: { $0.kind == "weekly_all" }), let percent = weekly.percent {
            result.append(UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: percent,
                                     resetsAt: ISODate.parse(weekly.resets_at), windowLength: 7 * 86400))
        }
        result += scopedWeeklyLimits(in: file)
        if let extra = extraUsageLimit(in: file) { result.append(extra) }
        if let credits = creditsLimit(in: file) { result.append(credits) }
        return result.sortedByWindow()
    }

    /// The model-scoped weeks from `limits[]` - "Weekly · Fable". A scope that names all
    /// models is the weekly window again under another name, and is left out.
    private static func scopedWeeklyLimits(in file: UsageFile) -> [UsageLimit] {
        var seen: Set<String> = []
        return (file.limits ?? []).compactMap { limit -> UsageLimit? in
            guard limit.kind == "weekly_scoped", let percent = limit.percent else { return nil }
            let model = limit.scope?.model?.display_name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !model.isEmpty, model.lowercased() != "all models" else { return nil }
            guard seen.insert(model.lowercased()).inserted else { return nil }
            return UsageLimit(agent: .claude, title: "Weekly \u{00B7} \(model)", percentUsed: percent,
                              resetsAt: ISODate.parse(limit.resets_at), windowLength: 7 * 86400)
        }
    }

    /// What the account spends past the plan, as a window of its own. Shown only once the
    /// person has turned it on: an allowance nobody enabled is not a reading.
    ///
    /// Claude writes no reset for it, so the row carries none - the month it runs for is
    /// not ours to date.
    private static func extraUsageLimit(in file: UsageFile) -> UsageLimit? {
        guard let extra = file.extra_usage, extra.is_enabled == true else { return nil }
        if let used = extra.utilization {
            return UsageLimit(agent: .claude, title: "Extra usage", percentUsed: used, resetsAt: nil)
        }
        guard let spent = extra.used_credits, let limit = extra.monthly_limit, limit > 0 else { return nil }
        return UsageLimit(agent: .claude, title: "Extra usage", percentUsed: spent / limit * 100, resetsAt: nil)
    }

    /// Prepaid credits that are being spent against a ceiling: a window like any other.
    /// A balance with no ceiling has no percentage and comes back as `Credits` instead.
    private static func creditsLimit(in file: UsageFile) -> UsageLimit? {
        guard let spend = file.spend, spend.enabled == true else { return nil }
        if let percent = spend.percent, spend.limit?.amount != nil {
            return UsageLimit(agent: .claude, title: "Credits", percentUsed: percent, resetsAt: nil)
        }
        guard let used = spend.used?.amount, let limit = spend.limit?.amount, limit > 0 else { return nil }
        return UsageLimit(agent: .claude, title: "Credits", percentUsed: used / limit * 100, resetsAt: nil)
    }

    /// A balance held against the plan running out, when the account reports one.
    static func credits(in file: UsageFile) -> Credits? {
        guard let spend = file.spend, let balance = spend.balance?.amount, balance > 0 else { return nil }
        return Credits(balance: balance, currency: spend.balance?.currency ?? "USD")
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

    /// The Claude Code version the newest session file names, or nil when none does. Read
    /// from the files rather than by running `claude --version`, which starts the whole
    /// program for one line.
    public static func version(in root: URL) -> String? {
        struct File: Decodable {
            let version: String?
            let updatedAt: Double?
        }
        let folder = root.appendingPathComponent("sessions")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        return names.filter { $0.hasSuffix(".json") }
            .compactMap { name -> File? in
                guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else { return nil }
                return try? JSONDecoder().decode(File.self, from: data)
            }
            .filter { $0.version?.isEmpty == false }
            .max { ($0.updatedAt ?? 0) < ($1.updatedAt ?? 0) }?
            .version?.trimmingCharacters(in: .whitespaces)
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
    /// percentage is offered only when the limit is actually known - a `[1m]` marker in the
    /// model's name, or a context already past 200K, which can only be a 1M one (a Fable
    /// session was watched compacting at 997K: the 1M window is real). Otherwise the tokens
    /// are reported and the caller shows those instead of inventing a denominator - so a
    /// freshly compacted session shows tokens until it grows past 200K again.
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
