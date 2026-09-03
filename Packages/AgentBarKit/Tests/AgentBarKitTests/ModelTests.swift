import Foundation
import Testing
@testable import AgentBarKit

@Suite("Models")
struct ModelTests {
    @Test func aLimitWhoseWindowHasRolledOverIsNotAReading() {
        let now = Date()
        let live = UsageLimit(agent: .codex, title: "Weekly", percentUsed: 96, resetsAt: now.addingTimeInterval(3600))
        // Codex writes only while it runs, so a fortnight-old 96% would otherwise be drawn
        // in red as if it were today's.
        let stale = UsageLimit(agent: .codex, title: "Weekly", percentUsed: 96, resetsAt: now.addingTimeInterval(-27 * 86400))
        #expect(!live.hasRolledOver(by: now))
        #expect(stale.hasRolledOver(by: now))
        // No reset time at all says nothing either way.
        #expect(!UsageLimit(agent: .claude, title: "x", percentUsed: 1, resetsAt: nil).hasRolledOver(by: now))
    }

    @Test func aRolledOverWindowIsProjectedForwardOnlyWhileTheAgentIsActive() {
        let now = Date(timeIntervalSince1970: 1_756_900_000)
        let session = UsageLimit(agent: .claude, title: "Session (5h)", percentUsed: 41,
                                 resetsAt: now.addingTimeInterval(-10 * 60), windowLength: 5 * 3600)
        // Still ahead: as reported.
        let ahead = UsageLimit(agent: .claude, title: "x", percentUsed: 1, resetsAt: now.addingTimeInterval(60), windowLength: 5 * 3600)
        #expect(ahead.currentWindowEnd(now: now, activeSince: nil) == now.addingTimeInterval(60))
        // Rolled over ten minutes ago and used since: the next window ends 5 h after the old one.
        #expect(session.currentWindowEnd(now: now, activeSince: now.addingTimeInterval(-60)) == now.addingTimeInterval(5 * 3600 - 10 * 60))
        // Rolled over and idle since: nothing to project.
        #expect(session.currentWindowEnd(now: now, activeSince: now.addingTimeInterval(-20 * 60)) == nil)
        #expect(session.currentWindowEnd(now: now, activeSince: nil) == nil)
        // Several windows ago: the one running now.
        let old = UsageLimit(agent: .claude, title: "x", percentUsed: 1, resetsAt: now.addingTimeInterval(-12 * 3600), windowLength: 5 * 3600)
        #expect(old.currentWindowEnd(now: now, activeSince: now) == now.addingTimeInterval(3 * 3600))
        // No length known: nothing to project.
        let unknown = UsageLimit(agent: .codex, title: "x", percentUsed: 1, resetsAt: now.addingTimeInterval(-60))
        #expect(unknown.currentWindowEnd(now: now, activeSince: now) == nil)
    }

    @Test func theWorstLimitIgnoresHistory() {
        let now = Date()
        let snapshot = Snapshot(limits: [
            UsageLimit(agent: .claude, title: "Session (5h)", percentUsed: 40, resetsAt: now.addingTimeInterval(60)),
            UsageLimit(agent: .codex, title: "Weekly", percentUsed: 96, resetsAt: now.addingTimeInterval(-60)),
            UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: 78, resetsAt: nil),
        ])
        #expect(snapshot.worstLimit(at: now)?.percentUsed == 78)
        #expect(Snapshot().worstLimit(at: now) == nil)
        #expect(Snapshot().isEmpty)
    }

    @Test func snapshotRoundTripsThroughJSON() throws {
        let now = Date(timeIntervalSince1970: 1_756_800_000)
        let snapshot = Snapshot(
            limits: [UsageLimit(agent: .claude, title: "Session (5h)", percentUsed: 42, resetsAt: now)],
            conversations: [Conversation(agent: .claude, id: "s", name: "Fix the build", project: "agentbar",
                                         isBusy: true, pid: 7, contextPercent: nil, contextTokens: 64_200,
                                         model: "Opus 5", effort: "high", branch: "main", appPID: 3, lastActivity: now)],
            lastWritten: [.claude: now, .codex: now.addingTimeInterval(-3600)],
            readAt: now,
            accounts: [.claude: AccountStatus(fetchedAt: now), .codex: AccountStatus(problem: "not signed in")])
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(Snapshot.self, from: data) == snapshot)
        // Agents are dictionary keys: the widget's JSON must stay a plain object, not a flat array.
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((object["lastWritten"] as? [String: Any])?.keys.sorted() == ["claude", "codex"])
    }

    @Test func conversationsAreOrderedByActivityThenBusyThenName() {
        let now = Date()
        func conversation(_ name: String, at date: Date?, busy: Bool = false) -> Conversation {
            Conversation(agent: .claude, id: name, name: name, project: "p", isBusy: busy, pid: 1, lastActivity: date)
        }
        let sorted = [
            conversation("b", at: nil), conversation("a", at: nil),
            conversation("idle", at: now), conversation("busy", at: now, busy: true),
            conversation("newest", at: now.addingTimeInterval(1)),
        ].sortedByActivity()
        #expect(sorted.map(\.name) == ["newest", "busy", "idle", "a", "b"])
    }

    @Test func proseIsFlattenedAndModelsArePretty() {
        #expect(Prose.oneLine("## Done\n\n- **fixed** the `Makefile`\n- see [docs](http://x)\n```swift\nlet x = 1\n```\n> quoted *word*")
                == "Done fixed the Makefile see docs quoted word")
        #expect(Prose.oneLine(String(repeating: "x", count: 200)).count == 140)
        #expect(Prose.modelName("claude-opus-5") == "Opus 5")
        #expect(Prose.modelName("claude-haiku-4-5-20251001") == "Haiku 4.5")
        #expect(Prose.modelName("claude-fable-5-1") == "Fable 5.1")
        #expect(Prose.modelName("gpt-5") == "Gpt 5")
    }

    @Test func fileTailDropsTheCutFirstLine() throws {
        let root = try TemporaryDirectory()
        let file = root.url.appendingPathComponent("t.jsonl")
        try "first line\nsecond line\nthird line\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(FileTail.read(file, bytes: 1000) == "first line\nsecond line\nthird line\n")
        #expect(FileTail.read(file, bytes: 15) == "third line\n")
        #expect(FileTail.read(root.url.appendingPathComponent("missing")) == nil)
    }

    @Test func processTreeAnswersForThisProcess() {
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        #expect(ProcessTree.isRunning(me))
        #expect(!ProcessTree.isRunning(2_000_000_000))
        let parent = ProcessTree.parentPID(of: me)
        #expect(parent != nil && parent! > 0)
    }
}
