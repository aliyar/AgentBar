import Foundation
import Testing
@testable import AgentBarKit

/// Fixtures are the exact shapes seen on 2 Sep 2026 (Codex rollout v1).
@Suite("CodexReader")
struct CodexReaderTests {
    @Test func rateLimitsComeFromTheLastTokenCount_2026_09_02() throws {
        // Two token_count events: the later one wins, and the earlier is ignored.
        let transcript = """
        {"timestamp":"2026-08-05T22:24:03.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":10.0,"window_minutes":10080,"resets_at":1786290000}}}}
        {"timestamp":"2026-08-05T22:30:00.000Z","type":"event_msg","payload":{"type":"agent_message"}}
        {"timestamp":"2026-08-05T22:31:24.115Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":96.0,"window_minutes":10080,"resets_at":1786290599},"secondary":null,"plan_type":"plus"}}}
        """
        let limits = CodexReader.limits(fromTranscript: transcript)
        #expect(limits.count == 1)
        let weekly = try #require(limits.first)
        #expect(weekly.agent == .codex)
        #expect(weekly.title == "Weekly")
        #expect(weekly.percentUsed == 96)
        #expect(weekly.resetsAt == Date(timeIntervalSince1970: 1786290599))
        let week: TimeInterval = 10080 * 60
        #expect(weekly.windowLength == week)
    }

    @Test func windowsAreNamedForTheirLength() {
        func title(_ minutes: Double) -> String? {
            CodexReader.limits(fromTranscript:
                #"{"payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":4.0,"window_minutes":\#(minutes),"resets_at":1}}}}"#).first?.title
        }
        #expect(title(60) == "Hourly")
        #expect(title(300) == "Daily")
        #expect(title(1440) == "Daily")
        #expect(title(10080) == "Weekly")
        #expect(title(43200) == "Monthly")
        #expect(CodexReader.title(minutes: nil) == "Usage")
        #expect(CodexReader.title(minutes: 0) == "Usage")
    }

    @Test func bothWindowsAreReportedWhenPresent() {
        let both = #"{"payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":30,"window_minutes":300,"resets_at":10},"secondary":{"used_percent":70,"window_minutes":10080,"resets_at":20}}}}"#
        let limits = CodexReader.limits(fromTranscript: both)
        #expect(limits.map(\.title) == ["Daily", "Weekly"])
        #expect(limits.map(\.percentUsed) == [30, 70])
    }

    @Test func aTranscriptWithNoLimitsSaysNothing() {
        #expect(CodexReader.limits(fromTranscript: #"{"payload":{"type":"message"}}"#).isEmpty)
        #expect(CodexReader.limits(fromTranscript: "rate_limits but not json").isEmpty)
        #expect(CodexReader.limits(fromTranscript: #"{"payload":{"rate_limits":{}}}"#).isEmpty)
        #expect(CodexReader.limits(fromTranscript: "").isEmpty)
    }

    @Test func newestRolloutIsFoundByDescendingDatedFolders() throws {
        let root = try TemporaryDirectory()
        let sessions = root.url.appendingPathComponent("sessions")
        let manager = FileManager.default
        for path in ["2025/12/31", "2026/08/30", "2026/09/01", "2026/09/02"] {
            try manager.createDirectory(at: sessions.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try "old".write(to: sessions.appendingPathComponent("2026/09/01/rollout-2026-09-01T10-00-00-a.jsonl"), atomically: true, encoding: .utf8)
        try "early".write(to: sessions.appendingPathComponent("2026/09/02/rollout-2026-09-02T09-00-00-b.jsonl"), atomically: true, encoding: .utf8)
        try "late".write(to: sessions.appendingPathComponent("2026/09/02/rollout-2026-09-02T18-30-00-c.jsonl"), atomically: true, encoding: .utf8)
        try "noise".write(to: sessions.appendingPathComponent("2026/09/02/.DS_Store"), atomically: true, encoding: .utf8)

        let newest = try #require(CodexReader.newestRollout(in: sessions))
        #expect(newest.lastPathComponent == "rollout-2026-09-02T18-30-00-c.jsonl")
        #expect(CodexReader.newestRollout(in: root.url.appendingPathComponent("missing")) == nil)
    }
}

extension CodexReaderTests {
    /// The rollout shape seen on 2 Sep 2026 (Codex CLI 0.152.1).
    @Test func runningSessionsAreMatchedToRolloutsByWorkingDirectory_2026_09_02() throws {
        let root = try TemporaryDirectory()
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let today = root.url.appendingPathComponent(String(format: "sessions/%04d/%02d/%02d", parts.year!, parts.month!, parts.day!))
        try FileManager.default.createDirectory(at: today, withIntermediateDirectories: true)
        let rollout = """
        {"timestamp":"2026-09-02T21:12:13.000Z","type":"session_meta","payload":{"id":"01a063f7","timestamp":"2026-09-02T21:12:13.000Z","cwd":"/Users/me/Projects/agentbar","originator":"codex-tui","cli_version":"0.152.1","source":"cli","model_provider":"openai","git":{"branch":"main"},"context_window":258400}}
        {"timestamp":"2026-09-02T21:13:09.751Z","type":"event_msg","payload":{"type":"task_started","turn_id":"t1","started_at":1788383589,"model_context_window":258400}}
        {"timestamp":"2026-09-02T21:13:09.800Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\\n  <cwd>/Users/me</cwd>\\n</environment_context>"}]}}
        {"timestamp":"2026-09-02T21:13:09.900Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"selam"}]}}
        {"timestamp":"2026-09-02T21:13:10.000Z","type":"turn_context","payload":{"cwd":"/Users/me/Projects/agentbar","model":"gpt-5.6-terra","effort":"medium","summary":"auto"}}
        {"timestamp":"2026-09-02T21:13:12.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Selam! **Nasıl** yardımcı olabilirim?"}],"phase":"final_answer"}}
        {"timestamp":"2026-09-02T21:13:12.300Z","type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":258400,"total_token_usage":{"input_tokens":18064,"output_tokens":14,"total_tokens":18078},"last_token_usage":{"input_tokens":18064,"cached_input_tokens":9984,"output_tokens":14,"total_tokens":18078}},"rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1788769105},"secondary":null,"plan_type":"prolite"}}}
        {"timestamp":"2026-09-02T21:13:12.342Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"t1","last_agent_message":"Selam! Nasıl yardımcı olabilirim?"}}
        """
        try rollout.write(to: today.appendingPathComponent("rollout-2026-09-02T22-12-13-01a063f7.jsonl"), atomically: true, encoding: .utf8)
        // An older rollout from another directory, and one with no session on it.
        try #"{"type":"session_meta","payload":{"id":"old","cwd":"/Users/me/Projects/repobar"}}"#
            .write(to: today.appendingPathComponent("rollout-2026-09-02T09-00-00-old.jsonl"), atomically: true, encoding: .utf8)

        let processes = [
            ProcessTree.RunningProcess(pid: 501, path: "/x/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex", cwd: "/Users/me/Projects/agentbar"),
            ProcessTree.RunningProcess(pid: 500, path: "/usr/local/bin/node", cwd: "/Users/me/Projects/agentbar"),   // the launcher, not a session
            ProcessTree.RunningProcess(pid: 502, path: "/x/bin/codex", cwd: "/Users/me/Elsewhere"),                    // no rollout for it
        ]
        let conversations = CodexReader.conversations(in: root.url, processes: processes, owningApplicationPID: { $0 + 1000 })
        #expect(conversations.count == 1)
        let session = try #require(conversations.first)
        #expect(session.agent == .codex)
        #expect(session.id == "01a063f7")
        #expect(session.pid == 501)
        #expect(session.appPID == 1501)
        #expect(session.project == "agentbar")
        #expect(session.name == "Selam! Nasıl yardımcı olabilirim?")
        #expect(!session.isBusy)
        #expect(session.model == "gpt-5.6-terra")
        #expect(session.effort == "medium")
        #expect(session.branch == "main")
        #expect(session.contextTokens == 18078)
        // Codex writes its context window, so the percentage is honest: 18078 / 258400.
        #expect(session.contextPercent.map { ($0 * 10).rounded() / 10 } == 7.0)
    }

    @Test func aTurnInProgressIsBusy() {
        let text = """
        {"type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"fix it"}]}}
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"t2"}}
        """
        let state = CodexReader.SessionState(fromTranscript: text)
        #expect(state.isBusy)
        #expect(state.lastSaid == "fix it")
        #expect(state.contextTokens == nil)
        #expect(CodexReader.SessionState(fromTranscript: "").isBusy == false)
    }
}
