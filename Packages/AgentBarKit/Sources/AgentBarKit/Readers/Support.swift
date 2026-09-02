import Foundation

/// Decodes to nil instead of failing the whole container when one element is malformed.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

enum FileTail {
    /// The last `bytes` of a file as text. Only the tail is read - a session file runs to
    /// megabytes and everything before the end is history.
    static func read(_ url: URL, bytes: UInt64 = 512 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let truncated = size > bytes
        try? handle.seek(toOffset: truncated ? size - bytes : 0)
        guard let data = try? handle.readToEnd(), var text = String(data: data, encoding: .utf8) else { return nil }
        // The window almost certainly cut the first line in half.
        if truncated, let newline = text.firstIndex(of: "\n") { text = String(text[text.index(after: newline)...]) }
        return text
    }

    static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

enum ISODate {
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

enum Prose {
    /// A message as one line of plain prose: the agents write Markdown, and `**this**` in a
    /// menu bar row is noise, not emphasis.
    static func oneLine(_ text: String, limit: Int = 140) -> String {
        var flat = text
        for (pattern, replacement) in markdown {
            flat = flat.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        flat = flat.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count > limit ? String(flat.prefix(limit)) : flat
    }

    /// Stripped in this order: fenced code, then links, then the emphasis and list marks.
    private static let markdown: [(String, String)] = [
        ("```[\\s\\S]*?```", " "),                   // fenced code
        ("`([^`]*)`", "$1"),                          // inline code
        ("!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),      // links and images
        ("(?m)^\\s*#{1,6}\\s*", ""),                  // headings
        ("(?m)^\\s*>\\s*", ""),                       // quotes
        ("(?m)^\\s*[-*+]\\s+", ""),                   // bullets
        ("\\*\\*([^*]*)\\*\\*", "$1"),                // bold
        ("__([^_]*)__", "$1"),
        ("(?<![*\\w])\\*([^*]+)\\*(?![*\\w])", "$1"), // italics
        ("~~([^~]*)~~", "$1"),
    ]

    /// "claude-opus-5" -> "Opus 5"; anything unexpected is left as it is.
    static func modelName(_ raw: String) -> String {
        let parts = raw.replacingOccurrences(of: "claude-", with: "").split(separator: "-")
        guard let family = parts.first else { return raw }
        // Version parts are one or two digits; a trailing date stamp ("20251001") is not a version.
        let numbers = parts.dropFirst().prefix { $0.count <= 2 && $0.allSatisfy(\.isNumber) }
        let version = numbers.joined(separator: ".")
        return version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
    }
}
