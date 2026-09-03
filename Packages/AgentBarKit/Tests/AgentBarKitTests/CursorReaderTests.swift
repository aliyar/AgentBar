import Foundation
import Testing
@testable import AgentBarKit

/// The composer record shape seen on 3 Sep 2026 (Cursor 2.x, `_v: 18`).
@Suite("CursorReader")
struct CursorReaderTests {
    private func composer(id: String, updatedAgo: TimeInterval, now: Date, generating: Bool = false, preview: String = "selam") -> Data {
        let updated = Int((now.timeIntervalSince1970 - updatedAgo) * 1000)
        let bubbles = generating ? #"["b2"]"# : "[]"
        return Data("""
        {"_v":18,"composerId":"\(id)","name":"Greeting conversation","status":"\(generating ? "generating" : "aborted")",
         "fullConversationHeadersOnly":[
           {"bubbleId":"b1","type":1,"grouping":{"isRenderable":true,"hasText":true,"textPreview":"\(preview)"},"createdAt":"2026-09-03T07:28:51.268Z"},
           {"bubbleId":"b2","type":2,"grouping":{"isRenderable":false}}],
         "generatingBubbleIds":\(bubbles),"lastUpdatedAt":\(updated),"createdAt":1788352186348,
         "modelConfig":{"modelName":"grok-4.6","maxMode":false,"selectedModels":[{"modelId":"grok-4.6","parameters":[{"id":"effort","value":"medium"},{"id":"fast","value":"false"}]}]},
         "unifiedMode":"agent"}
        """.utf8)
    }

    @Test func recentAgentChatsBecomeConversations_2026_09_03() throws {
        let now = Date()
        let records = [
            composer(id: "recent", updatedAgo: 5 * 60, now: now),
            composer(id: "busy", updatedAgo: 3 * 3600, now: now, generating: true, preview: "**fix** the build"),
            composer(id: "old", updatedAgo: 2 * 3600, now: now),
            composer(id: "not-an-agent-chat", updatedAgo: 60, now: now),
        ]
        let projects = ["recent": "agentbar", "busy": "repobar", "old": "agentbar"]
        let conversations = CursorReader.conversations(fromComposers: records, projects: projects, now: now, editorPID: 777)
        // The old chat is gone; the busy one counts however old; chats without a transcript folder are not agent chats.
        #expect(conversations.map(\.id) == ["recent", "busy"])
        let recent = try #require(conversations.first)
        #expect(recent.agent == .cursor)
        #expect(recent.name == "selam")
        #expect(recent.project == "agentbar")
        #expect(!recent.isBusy)
        #expect(recent.model == "grok-4.6")
        #expect(recent.effort == "medium")
        #expect(recent.pid == 777 && recent.appPID == 777)
        #expect(recent.contextPercent == nil && recent.contextTokens == nil)
        let busy = try #require(conversations.last)
        #expect(busy.isBusy)
        #expect(busy.name == "fix the build")
        #expect(CursorReader.conversations(fromComposers: [Data("junk".utf8)], projects: projects, now: now, editorPID: nil).isEmpty)
    }

    @Test func projectSlugsRecoverDashedFolderNames() {
        let existing: Set<String> = ["/Users", "/Users/me", "/Users/me/Projects", "/Users/me/Projects/great-menubar", "/Users/me/Projects/agentbar"]
        #expect(CursorReader.projectName(fromSlug: "Users-me-Projects-agentbar", exists: existing.contains) == "agentbar")
        #expect(CursorReader.projectName(fromSlug: "Users-me-Projects-great-menubar", exists: existing.contains) == "great-menubar")
        // Nothing on disk: the last dashed part stands in.
        #expect(CursorReader.projectName(fromSlug: "Users-me-Elsewhere-thing", exists: { _ in false }) == "thing")
    }
}
