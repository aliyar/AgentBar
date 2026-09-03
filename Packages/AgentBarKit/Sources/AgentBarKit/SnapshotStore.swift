import Foundation

/// The App Group the app and its widget share. A Developer ID app uses the Team-ID form:
/// Sequoia checks `group.…` identifiers against a provisioning profile and prompts.
public enum AppGroup {
    public static let id = "RCQFGHVGQJ.com.greatpixels.AgentBar"

    /// The group's container, or nil when the entitlement is missing.
    public static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}

/// The one file the widget reads. The app reads the agents and writes a snapshot here
/// after every read; the widget - sandboxed, unable to read the agents' folders - decodes
/// it and nothing else. So the widget is only as fresh as the last time the app ran.
public struct SnapshotStore: Sendable {
    public let url: URL

    /// The store in the shared container, or nil without the App Group.
    public init?() {
        guard let container = AppGroup.container else { return nil }
        self.init(directory: container)
    }

    public init(directory: URL) {
        url = directory.appendingPathComponent("snapshot.json")
    }

    /// Written atomically: the widget never sees half a file.
    public func write(_ snapshot: Snapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    public func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }
}
