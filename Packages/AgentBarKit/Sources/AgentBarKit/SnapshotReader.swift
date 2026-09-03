import Foundation

/// One read of everything the installed agents left on disk. Pure and synchronous: the
/// caller runs it off the main actor and publishes the result.
///
/// Nothing is asked of any server - these are the agents' own files, and the app never
/// sees a credential.
public enum SnapshotReader {
    /// Reads the given agents (those installed and readable; the rest contribute nothing).
    public static func read(agents: [Agent] = Agent.allCases, now: Date = .now) -> Snapshot {
        var snapshot = Snapshot(readAt: now)
        for agent in agents where agent.isReadable {
            let root = agent.defaultURL
            switch agent {
            case .claude:
                snapshot.take(ClaudeReader.read(in: root), for: .claude)
                snapshot.conversations += ClaudeReader.conversations(in: root)
            case .codex:
                snapshot.take(CodexReader.read(in: root), for: .codex)
                snapshot.conversations += CodexReader.conversations(in: root)
            case .cursor:
                // Cursor leaves no usage on disk (that comes from the account), only the
                // account it is signed in as, and its chats.
                snapshot.take(CursorReader.read(), for: .cursor)
                snapshot.conversations += CursorReader.conversations(home: HomeDirectory.url, now: now)
            }
        }
        snapshot.conversations = snapshot.conversations.sortedByActivity()
        return snapshot
    }
}
