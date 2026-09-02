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
                let (limits, written) = ClaudeReader.readLimits(in: root)
                snapshot.limits += limits
                snapshot.lastWritten[.claude] = written
                snapshot.conversations += ClaudeReader.conversations(in: root)
            case .codex:
                let (limits, written) = CodexReader.readLimits(in: root)
                snapshot.limits += limits
                snapshot.lastWritten[.codex] = written
            }
        }
        return snapshot
    }
}
