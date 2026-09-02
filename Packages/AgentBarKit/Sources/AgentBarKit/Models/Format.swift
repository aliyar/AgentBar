import Foundation

/// The short forms the meters and the gauge use. Shared with the widget, which draws the
/// same numbers in less room.
public enum Format {
    /// "44K", "1.2M" - a token count at a glance.
    public static func compact(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return "\(tokens / 1_000)K" }
        return "\(tokens)"
    }

    /// "4h 52m", "2d 3h", "40m" - the shorthand a status line uses: two units at most, the
    /// smaller one kept under a day because a five-hour window is watched by the minute.
    /// `coarse` keeps one unit: "27d ago", "4h ago".
    public static func short(_ seconds: TimeInterval, coarse: Bool = false) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86400, hours = (total % 86400) / 3600, minutes = (total % 3600) / 60
        if days > 0 { return (hours > 0 && !coarse) ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return (minutes > 0 && !coarse) ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(max(1, minutes))m"
    }

    /// "78%" - a percentage as the gauge shows it.
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}
