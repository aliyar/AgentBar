import Foundation
import Testing
@testable import AgentBarKit

@Suite("SnapshotStore")
struct SnapshotStoreTests {
    @Test func roundTripsThroughTheSharedFile() throws {
        let directory = try TemporaryDirectory()
        let store = SnapshotStore(directory: directory.url.appendingPathComponent("group"))
        #expect(store.read() == nil)
        // Whole seconds: ISO 8601 keeps no fractions.
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        var snapshot = Snapshot.sample
        snapshot.readAt = now
        snapshot.lastWritten = [.claude: now]
        snapshot.accounts = [.claude: AccountStatus(fetchedAt: now)]
        snapshot.limits = snapshot.limits.map {
            UsageLimit(agent: $0.agent, title: $0.title, percentUsed: $0.percentUsed, resetsAt: now.addingTimeInterval(3600), windowLength: $0.windowLength)
        }
        snapshot.conversations = snapshot.conversations.map {
            Conversation(agent: $0.agent, id: $0.id, name: $0.name, project: $0.project, isBusy: $0.isBusy, pid: $0.pid,
                         contextPercent: $0.contextPercent, contextTokens: $0.contextTokens, model: $0.model,
                         effort: $0.effort, branch: $0.branch, appPID: $0.appPID, lastActivity: now)
        }
        try store.write(snapshot)
        #expect(store.read() == snapshot)
        // A torn or foreign file reads as nothing, never as a crash.
        try Data("{".utf8).write(to: store.url)
        #expect(store.read() == nil)
    }
}
