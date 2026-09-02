import AppKit
import AgentBarKit

/// What the menu bar item shows when the gauge is on: a vertical bar per chosen window
/// (Claude's three by default, in their fixed order) and the time left on one window -
/// the fullest of them unless Settings names another - in that window's level colour.
/// No agent name, no percent text.
enum MenuBarGauge {
    static func make(from snapshot: Snapshot, agents: [Agent], bars chosen: [String],
                     time: AppSettings.MenuBarTime, now: Date) -> StatusItemGauge? {
        // A window that rolled over while its agent stays in use is running again, at 0%.
        let live = snapshot.limits.filter { agents.contains($0.agent) }.compactMap { limit -> UsageLimit? in
            if !limit.hasRolledOver(by: now) { return limit }
            guard let end = limit.currentWindowEnd(now: now, activeSince: snapshot.latestActivity(for: limit.agent)) else { return nil }
            return UsageLimit(agent: limit.agent, title: limit.title, percentUsed: 0, resetsAt: end, windowLength: limit.windowLength)
        }
        var windows = chosen.isEmpty ? live.filter { $0.agent == .claude } : live.filter { chosen.contains($0.id) }
        if windows.isEmpty { windows = live }
        guard !windows.isEmpty else { return nil }

        let bars = windows.map { limit in
            let level = Palette.level(limit.percentUsed)
            return StatusItemGauge.Bar(fraction: max(0.09, limit.percentUsed / 100),
                                       dark: Palette.nsColor(level, dark: true),
                                       light: Palette.nsColor(level, dark: false))
        }

        let clock: UsageLimit? = switch time {
        case .fullest: windows.max { $0.percentUsed < $1.percentUsed }
        case .window(let id): live.first { $0.id == id }
        case .none: nil
        }
        let title = clock.map { limit in
            limit.resetsAt.map { Format.short($0.timeIntervalSince(now)) } ?? Format.percent(limit.percentUsed)
        } ?? ""
        let level = Palette.level(clock?.percentUsed ?? 0)
        let summary = clock.map {
            "AgentBar — \($0.title) is \(Format.percent($0.percentUsed)) used, starts over in \(title)"
        } ?? "AgentBar — \(windows.count) windows"
        return StatusItemGauge(bars: bars, title: title,
                               titleDark: Palette.nsColor(level, dark: true),
                               titleLight: Palette.nsColor(level, dark: false),
                               summary: summary)
    }
}
