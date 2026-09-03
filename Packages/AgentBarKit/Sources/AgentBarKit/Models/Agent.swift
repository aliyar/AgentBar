import Foundation

/// A coding agent whose usage the app can show. Adding one means a folder, a way to read
/// its limits, and nothing else: the views draw whatever comes back.
public enum Agent: String, CaseIterable, Identifiable, Codable, Sendable, CodingKeyRepresentable {
    case claude, codex, cursor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }

    /// SF Symbol used wherever the agent is drawn without its own icon.
    public var symbol: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .cursor: "cursorarrow.rays"
        }
    }

    /// The folder it keeps its data in, relative to the real home directory.
    public var folderName: String {
        switch self {
        case .claude: ".claude"
        case .codex: ".codex"
        case .cursor: "Library/Application Support/Cursor"
        }
    }

    public var defaultURL: URL { HomeDirectory.url.appendingPathComponent(folderName) }

    /// The folder as a person would write it.
    public var folderPath: String { "~/\(folderName)" }

    /// Whether the agent is on this Mac at all. One that is not installed is not shown.
    public var isInstalled: Bool { FileManager.default.fileExists(atPath: defaultURL.path) }

    /// Whether its folder can be read. Always true for an installed agent while the app is
    /// not sandboxed; kept as the one question to ask, for the day that changes.
    public var isReadable: Bool { FileManager.default.isReadableFile(atPath: defaultURL.path) }
}
