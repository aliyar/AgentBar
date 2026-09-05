import Foundation

/// Reads what Cursor leaves on this Mac about its agent chats. Cursor writes no usage on
/// disk (that comes from the account); its chats live in the editor's state database as
/// `composerData:<id>` rows, and the ones that ran as an agent also own a folder under
/// `~/.cursor/projects/<project slug>/agent-transcripts/<id>/`, which is what ties a chat
/// to a project. There is no process per chat: a chat is "running" while Cursor is
/// generating in it, and "active" while it moved in the last half hour.
public enum CursorReader {
    static let activeFor: TimeInterval = 30 * 60

    /// Cursor leaves no usage on disk - that comes from the account - but it does cache
    /// who is signed in and which plan they are on, beside its token.
    public static func read(home: URL = HomeDirectory.url) -> Reading {
        Reading(identity: Credentials.cursorIdentity(home: home))
    }

    struct Composer: Decodable {
        struct Header: Decodable {
            struct Grouping: Decodable {
                let hasText: Bool?
                let textPreview: String?
            }
            /// 1 is the person, 2 is the agent.
            let type: Int?
            let grouping: Grouping?
        }
        struct ModelConfig: Decodable {
            struct Selected: Decodable {
                struct Parameter: Decodable {
                    let id: String?
                    let value: String?
                }
                let parameters: [Parameter]?
            }
            let modelName: String?
            let selectedModels: [Selected]?
        }
        let composerId: String?
        let name: String?
        let status: String?
        /// Epoch milliseconds.
        let lastUpdatedAt: Double?
        let generatingBubbleIds: [String]?
        let fullConversationHeadersOnly: [FailableDecodable<Header>]?
        let modelConfig: ModelConfig?
    }

    /// The agent chats that moved recently, newest first.
    public static func conversations(
        home: URL = HomeDirectory.url,
        now: Date = .now,
        editorPID: Int? = ProcessTree.processes(whosePathContains: "Cursor.app/Contents/MacOS/Cursor").first?.pid
    ) -> [Conversation] {
        let database = home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard let db = SQLiteCopy(of: database) else { return [] }
        defer { db.close() }
        let composers = db.rows(in: "cursorDiskKV", keyLike: "composerData:%").map { Data($0.value.utf8) }
        return conversations(fromComposers: composers,
                             projects: agentProjects(home: home), now: now, editorPID: editorPID)
    }

    /// The parsing on its own: composer records, and which project folder each chat's
    /// transcript sits in.
    public static func conversations(fromComposers records: [Data], projects: [String: String],
                                     now: Date, editorPID: Int?) -> [Conversation] {
        records.compactMap { data -> Conversation? in
            guard let composer = try? JSONDecoder().decode(Composer.self, from: data),
                  let id = composer.composerId, let project = projects[id] else { return nil }
            let updated = composer.lastUpdatedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
            let generating = !(composer.generatingBubbleIds ?? []).isEmpty || composer.status == "generating"
            guard generating || (updated.map { now.timeIntervalSince($0) < activeFor } ?? false) else { return nil }
            let lastSaid = composer.fullConversationHeadersOnly?.compactMap(\.value)
                .last { $0.grouping?.hasText == true && !($0.grouping?.textPreview ?? "").isEmpty }?.grouping?.textPreview
            let name = lastSaid.map { Prose.oneLine($0) } ?? composer.name ?? project
            let effort = composer.modelConfig?.selectedModels?.first?.parameters?.first { $0.id == "effort" }?.value
            return Conversation(agent: .cursor, id: id, name: name, project: project, isBusy: generating,
                                pid: editorPID ?? 0, model: composer.modelConfig?.modelName, effort: effort,
                                appPID: editorPID, lastActivity: updated)
        }
        .sortedByActivity()
    }

    /// Chat id → project name, from the transcript folders Cursor keeps per project. The
    /// slug is the project path with its slashes turned into dashes; the last component is
    /// recovered by matching the slug against real folders, dash by dash.
    static func agentProjects(home: URL) -> [String: String] {
        let root = home.appendingPathComponent(".cursor/projects")
        guard let slugs = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return [:] }
        var projects: [String: String] = [:]
        for slug in slugs where !slug.hasPrefix(".") {
            let transcripts = root.appendingPathComponent("\(slug)/agent-transcripts")
            guard let ids = try? FileManager.default.contentsOfDirectory(atPath: transcripts.path) else { continue }
            let name = projectName(fromSlug: slug)
            for id in ids where !id.hasPrefix(".") { projects[id] = name }
        }
        return projects
    }

    /// "Users-me-Projects-side-project" → "side-project", by walking the slug as a path
    /// and letting a segment keep its dashes when the dashed folder exists.
    static func projectName(fromSlug slug: String, exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String {
        let parts = slug.split(separator: "-").map(String.init)
        var path = ""
        var index = 0
        var last = slug
        while index < parts.count {
            // The longest dashed segment that exists wins; otherwise one part.
            var taken = 1
            for length in stride(from: parts.count - index, through: 1, by: -1) {
                let segment = parts[index..<(index + length)].joined(separator: "-")
                if exists(path + "/" + segment) { taken = length; break }
            }
            let segment = parts[index..<(index + taken)].joined(separator: "-")
            path += "/" + segment
            last = segment
            index += taken
        }
        return last
    }
}
