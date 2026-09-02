import Foundation
import Testing
@testable import AgentBarKit

/// The agents' files are undocumented and theirs to change. These fixtures are the exact
/// shapes seen on 2 Sep 2026 (Claude Code 2.1.252); if one of these fails, the format moved
/// and the reader has to follow it.
@Suite("ClaudeReader")
struct ClaudeReaderTests {
    @Test func usageFileIsReadAsPercentUsed_2026_09_02() throws {
        let json = """
        {"five_hour":{"utilization":1.0,"resets_at":"2026-09-02T03:50:00.242541+00:00"},
         "seven_day":{"utilization":3.0,"resets_at":"2026-09-03T17:00:00.242559+00:00"},
         "limits":[
           {"kind":"session","group":"session","percent":42,"severity":"none","resets_at":"2026-09-02T03:50:00.242541+00:00","scope":null,"is_active":true},
           {"kind":"weekly_all","group":"weekly","percent":78,"severity":"none","resets_at":"2026-09-03T17:00:00.242559+00:00","scope":null,"is_active":true},
           {"kind":"weekly_scoped","group":"weekly","percent":23,"severity":"none","resets_at":"2026-09-03T18:00:00.242751+00:00",
            "scope":{"model":{"id":null,"display_name":"Fable"}},"is_active":true}]}
        """
        let limits = ClaudeReader.limits(from: Data(json.utf8))
        #expect(limits.map(\.title) == ["Session (5h)", "Weekly · all models", "Weekly · Fable"])
        // Used, never remaining: the number is taken as written.
        #expect(limits.map(\.percentUsed) == [42, 78, 23])
        #expect(limits.allSatisfy { $0.agent == .claude })
        #expect(limits[0].resetsAt != nil)
        let lengths: [TimeInterval?] = [5 * 3600, 7 * 86400, 7 * 86400]
        #expect(limits.map(\.windowLength) == lengths)
    }

    @Test func olderUsageFileFallsBackToTheNamedWindows() {
        let older = """
        {"five_hour":{"utilization":12.0,"resets_at":"2026-09-02T03:50:00Z"},"seven_day":{"utilization":5.0,"resets_at":null}}
        """
        let fallback = ClaudeReader.limits(from: Data(older.utf8))
        #expect(fallback.map(\.title) == ["Session (5h)", "Weekly · all models"])
        #expect(fallback[0].resetsAt == ISODate.parse("2026-09-02T03:50:00Z"))
        #expect(fallback[1].resetsAt == nil)
    }

    @Test func nonsenseIsNothingToShowNeverACrash() {
        #expect(ClaudeReader.limits(from: Data("not json".utf8)).isEmpty)
        #expect(ClaudeReader.limits(from: Data("{}".utf8)).isEmpty)
        #expect(ClaudeReader.limits(from: Data(#"{"limits":[{"kind":"session"}]}"#.utf8)).isEmpty)
        #expect(ClaudeReader.contextUse(fromTranscript: "") == nil)
        #expect(ClaudeReader.contextUse(fromTranscript: "garbage\n{}\n") == nil)
    }

    @Test func unknownLimitKindsGetAReadableTitle() {
        let json = #"{"limits":[{"kind":"monthly_extra","percent":5},{"percent":6},{"kind":"weekly_scoped","percent":7,"scope":{"model":{}}}]}"#
        let titles = ClaudeReader.limits(from: Data(json.utf8)).map(\.title)
        #expect(titles == ["Monthly Extra", "Limit", "Weekly · one model"])
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
