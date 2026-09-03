import Foundation
import Testing
@testable import AgentBarKit

/// The agents' files are undocumented and theirs to change. These fixtures are the exact
/// shapes seen on 2 Sep 2026 (Claude Code 2.1.252); if one of these fails, the format moved
/// and the reader has to follow it.
@Suite("ClaudeReader")
struct ClaudeReaderTests {
    /// The exact shape `~/.claude/cache/usage.json` had on 3 Sep 2026, trimmed to the
    /// fields the reader looks at. The named windows and `limits[]` both describe the
    /// session and the week; the panel takes the named ones and reads `limits[]` only for
    /// the scoped week that has nowhere else to come from.
    @Test func theNamedWindowsAreTheReadingAndLimitsAddsTheScopedWeek_2026_09_03() throws {
        let json = """
        {"five_hour":{"utilization":7.0,"resets_at":"2026-09-03T22:00:00.029145+00:00","limit_dollars":null},
         "seven_day":{"utilization":1.0,"resets_at":"2026-09-10T17:00:00.029167+00:00"},
         "seven_day_opus":null,"seven_day_sonnet":null,"nimbus_quill":{"utilization":0.0,"resets_at":null},
         "extra_usage":{"is_enabled":false,"monthly_limit":null,"utilization":null,"user_disabled":true},
         "spend":{"used":{"amount_minor":0,"currency":"USD","exponent":2},"limit":null,"percent":0,"enabled":false,"balance":null},
         "limits":[
           {"kind":"session","group":"session","percent":7,"resets_at":"2026-09-03T22:00:00.029145+00:00","scope":null,"is_active":true},
           {"kind":"weekly_all","group":"weekly","percent":1,"resets_at":"2026-09-10T17:00:00.029167+00:00","scope":null,"is_active":false},
           {"kind":"weekly_scoped","group":"weekly","percent":2,"resets_at":"2026-09-10T17:00:00.029358+00:00",
            "scope":{"model":{"id":null,"display_name":"Fable"}},"is_active":false}]}
        """
        let reading = ClaudeReader.reading(from: Data(json.utf8))
        #expect(reading.limits.map(\.title) == ["5h", "Weekly · all models", "Weekly · Fable"])
        // Used, never remaining: the number is taken as written.
        #expect(reading.limits.map(\.percentUsed) == [7, 1, 2])
        #expect(reading.limits.allSatisfy { $0.agent == .claude })
        #expect(reading.limits[0].resetsAt != nil)
        let lengths: [TimeInterval?] = [5 * 3600, 7 * 86400, 7 * 86400]
        #expect(reading.limits.map(\.windowLength) == lengths)
        // Windows nobody can name ("nimbus_quill") are not rows; neither is a disabled
        // allowance, and a zero balance is no balance.
        #expect(reading.credits == nil)
    }

    /// The two windows that matter are read from the account's own named fields, so a
    /// `limits[]` that one day arrives carrying only a scoped week cannot lose them.
    @Test func aLimitsArrayWithOnlyAScopedWeekKeepsTheSessionAndTheWeek() {
        let json = """
        {"five_hour":{"utilization":12.0,"resets_at":"2026-09-02T03:50:00Z"},
         "seven_day":{"utilization":5.0,"resets_at":null},
         "limits":[{"kind":"weekly_scoped","group":"weekly","percent":40,"scope":{"model":{"display_name":"Fable"}}}]}
        """
        let limits = ClaudeReader.reading(from: Data(json.utf8)).limits
        #expect(limits.map(\.title) == ["5h", "Weekly · all models", "Weekly · Fable"])
        #expect(limits.map(\.percentUsed) == [12, 5, 40])
    }

    /// A build that writes only `limits[]` still gets its two windows from there.
    @Test func theLimitsArrayStandsInWhenTheNamedWindowsAreMissing() {
        let json = #"{"limits":[{"kind":"session","percent":9},{"kind":"weekly_all","percent":3}]}"#
        let limits = ClaudeReader.reading(from: Data(json.utf8)).limits
        #expect(limits.map(\.title) == ["5h", "Weekly · all models"])
        #expect(limits.map(\.percentUsed) == [9, 3])
    }

    @Test func olderUsageFileFallsBackToTheNamedWindows() {
        let older = """
        {"five_hour":{"utilization":12.0,"resets_at":"2026-09-02T03:50:00Z"},"seven_day":{"utilization":5.0,"resets_at":null}}
        """
        let fallback = ClaudeReader.reading(from: Data(older.utf8)).limits
        #expect(fallback.map(\.title) == ["5h", "Weekly · all models"])
        #expect(fallback[0].resetsAt == ISODate.parse("2026-09-02T03:50:00Z"))
        #expect(fallback[1].resetsAt == nil)
    }

    @Test func nonsenseIsNothingToShowNeverACrash() {
        #expect(ClaudeReader.reading(from: Data("not json".utf8)).isEmpty)
        #expect(ClaudeReader.reading(from: Data("{}".utf8)).isEmpty)
        #expect(ClaudeReader.reading(from: Data(#"{"limits":[{"kind":"session"}]}"#.utf8)).isEmpty)
        #expect(ClaudeReader.contextUse(fromTranscript: "") == nil)
        #expect(ClaudeReader.contextUse(fromTranscript: "garbage\n{}\n") == nil)
    }

    /// A scope that names every model is the weekly window again; two rows saying the
    /// same thing is worse than one.
    @Test func aScopeOverAllModelsIsNotASecondWeeklyRow() {
        let json = """
        {"seven_day":{"utilization":5.0,"resets_at":null},
         "limits":[{"kind":"weekly_scoped","group":"weekly","percent":5,"scope":{"model":{"display_name":"All models"}}},
                   {"kind":"weekly_scoped","group":"weekly","percent":8,"scope":{"model":{"display_name":"Fable"}}},
                   {"kind":"weekly_scoped","group":"weekly","percent":9,"scope":{"model":{"display_name":"Fable"}}}]}
        """
        // The duplicate Fable entry is read once, and "All models" is left to `seven_day`.
        #expect(ClaudeReader.reading(from: Data(json.utf8)).limits.map(\.title)
            == ["Weekly · all models", "Weekly · Fable"])
    }

    /// Extra usage is money spent past the plan. It is a row only once the person has
    /// turned it on - an allowance nobody enabled is not a reading.
    @Test func extraUsageIsARowOnlyWhenItIsEnabled() {
        let off = #"{"extra_usage":{"is_enabled":false,"monthly_limit":100,"used_credits":40,"utilization":40}}"#
        #expect(ClaudeReader.reading(from: Data(off.utf8)).limits.isEmpty)

        let on = #"{"extra_usage":{"is_enabled":true,"monthly_limit":100,"used_credits":40,"utilization":31.5,"currency":"USD"}}"#
        let limits = ClaudeReader.reading(from: Data(on.utf8)).limits
        #expect(limits.map(\.title) == ["Extra usage"])
        #expect(limits[0].percentUsed == 31.5)
        // Claude writes no reset for it, so the row states none rather than inventing a month.
        #expect(limits[0].resetsAt == nil)
        #expect(limits[0].windowLength == nil)

        // Without a utilization the ratio is worked out from what it writes instead.
        let ratio = #"{"extra_usage":{"is_enabled":true,"monthly_limit":80,"used_credits":20}}"#
        #expect(ClaudeReader.reading(from: Data(ratio.utf8)).limits.map(\.percentUsed) == [25])
    }

    /// Prepaid credits spending against a ceiling are a window; a balance with no ceiling
    /// is not, and belongs beside the agent's name.
    @Test func creditsAreARowOnlyWhenTheySpendTowardsACeiling() {
        let spending = """
        {"spend":{"enabled":true,"percent":62,"used":{"amount_minor":6200,"currency":"USD","exponent":2},
                  "limit":{"amount_minor":10000,"currency":"USD","exponent":2},"balance":null}}
        """
        let limits = ClaudeReader.reading(from: Data(spending.utf8)).limits
        #expect(limits.map(\.title) == ["Credits"])
        #expect(limits[0].percentUsed == 62)

        let balanceOnly = """
        {"spend":{"enabled":true,"percent":0,"used":{"amount_minor":0,"currency":"USD","exponent":2},
                  "limit":null,"balance":{"amount_minor":1240,"currency":"USD","exponent":2}}}
        """
        let reading = ClaudeReader.reading(from: Data(balanceOnly.utf8))
        #expect(reading.limits.isEmpty)
        #expect(reading.credits == Credits(balance: 12.40, currency: "USD"))
        #expect(reading.credits?.caption == "$12.40 credits")
    }

    @Test func contextComesFromTheNewestAnswerAndTheLastWords_2026_09_02() throws {
        let transcript = """
        {"type":"user","gitBranch":"main","message":{"role":"user","content":[{"type":"text","text":"Please **fix** the `Makefile`"}]}}
        {"type":"assistant","gitBranch":"main","effort":"high","message":{"model":"claude-opus-5","usage":{"input_tokens":1000,"cache_read_input_tokens":50000,"cache_creation_input_tokens":2000},"content":[{"type":"text","text":"On it."}]}}
        {"type":"assistant","gitBranch":"main","effort":"high","message":{"model":"claude-opus-5","usage":{"input_tokens":1200,"cache_read_input_tokens":60000,"cache_creation_input_tokens":3000},"content":[{"type":"tool_use","name":"Bash","input":{}}]}}
        {"type":"progress","data":{}}
        """
        let context = try #require(ClaudeReader.contextUse(fromTranscript: transcript))
        // The newest answer's figures, even though it said nothing.
        #expect(context.tokens == 64_200)
        // 200K or 1M cannot be told apart here, so no percentage is invented.
        #expect(context.percent == nil)
        #expect(context.model == "Opus 5")
        #expect(context.effort == "high")
        #expect(context.branch == "main")
        // The scan goes back past the tool call for the last thing actually said, flattened.
        #expect(context.lastSaid == "On it.")
    }

    @Test func aMillionContextIsOnlyClaimedWhenKnown() throws {
        let marked = """
        {"type":"assistant","message":{"model":"claude-opus-5[1m]","usage":{"input_tokens":300000},"content":[{"type":"text","text":"x"}]}}
        """
        let byMarker = try #require(ClaudeReader.contextUse(fromTranscript: marked))
        #expect(byMarker.percent == 30)
        let big = """
        {"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":250000},"content":[]}}
        """
        let bySize = try #require(ClaudeReader.contextUse(fromTranscript: big))
        #expect(bySize.percent == 25)
        let small = """
        {"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":150000},"content":[]}}
        """
        #expect(try #require(ClaudeReader.contextUse(fromTranscript: small)).percent == nil)
        let empty = """
        {"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":0},"content":[]}}
        """
        #expect(ClaudeReader.contextUse(fromTranscript: empty) == nil)
    }

    @Test func sessionFilesNameRunningConversationsOnly() throws {
        let root = try TemporaryDirectory()
        let sessions = root.url.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let cwd = root.url.appendingPathComponent("Projects/agent.bar").path
        try #"{"pid":101,"sessionId":"s-101","cwd":"\#(cwd)","name":"agentbar #1","status":"busy","updatedAt":1756800000000,"statusUpdatedAt":1756800005000}"#
            .write(to: sessions.appendingPathComponent("101.json"), atomically: true, encoding: .utf8)
        try #"{"pid":102,"sessionId":"s-102","cwd":"\#(cwd)","name":"agentbar #2","status":"idle","updatedAt":1756800100000}"#
            .write(to: sessions.appendingPathComponent("102.json"), atomically: true, encoding: .utf8)
        try #"{"pid":103,"sessionId":"s-103","cwd":"\#(cwd)","name":"dead","status":"idle"}"#
            .write(to: sessions.appendingPathComponent("103.json"), atomically: true, encoding: .utf8)
        try "not json".write(to: sessions.appendingPathComponent("104.json"), atomically: true, encoding: .utf8)
        try "ignored".write(to: sessions.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        // A transcript for the first session: the last words become its name.
        let transcript = ClaudeReader.transcriptURL(in: root.url, cwd: cwd, sessionID: "s-101")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"type":"assistant","gitBranch":"feature/x","message":{"model":"claude-sonnet-5","usage":{"input_tokens":500},"content":[{"type":"text","text":"Done, tests pass."}]}}"#
            .write(to: transcript, atomically: true, encoding: .utf8)

        let conversations = ClaudeReader.conversations(in: root.url, isRunning: { $0 != 103 },
                                                       owningApplicationPID: { $0 + 1000 })
        // The dead one and the unreadable one are gone; the newest activity comes first.
        #expect(conversations.map(\.pid) == [102, 101])
        let named = try #require(conversations.last)
        #expect(named.id == "s-101")
        #expect(named.name == "Done, tests pass.")
        #expect(named.project == "agent.bar")
        #expect(named.isBusy)
        #expect(named.branch == "feature/x")
        #expect(named.model == "Sonnet 5")
        #expect(named.contextTokens == 500)
        #expect(named.appPID == 1101)
        #expect(named.lastActivity == Date(timeIntervalSince1970: 1_756_800_005))
        // No transcript: the agent's own name is the fallback.
        #expect(conversations.first?.name == "agentbar #2")
        #expect(conversations.first?.isBusy == false)
    }

    @Test func transcriptFolderFlattensTheWorkingDirectory() {
        let url = ClaudeReader.transcriptURL(in: URL(fileURLWithPath: "/h/.claude"), cwd: "/Users/me/Projects/agent.bar", sessionID: "abc")
        #expect(url.path == "/h/.claude/projects/-Users-me-Projects-agent-bar/abc.jsonl")
    }
}
