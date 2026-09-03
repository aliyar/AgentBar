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

    /// When a window starts over, as a clock: "14:44" today, "Sat 14:44" within the week,
    /// "12 Sep" beyond it - a weekday alone stops saying which one after six days.
    public static func clock(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
        if calendar.isDate(date, inSameDayAs: now) { return time }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days >= 0, days < 7 { return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(time)" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
