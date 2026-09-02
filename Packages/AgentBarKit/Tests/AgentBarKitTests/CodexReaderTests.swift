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
