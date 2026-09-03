import SwiftUI
import WidgetKit
import AgentBarKit

/// The app's thresholds (60 / 85) and level colours, per appearance.
enum WidgetLevels {
    enum Level { case calm, warm, hot }

    static func level(_ percent: Double) -> Level {
        switch percent {
        case ..<60: .calm
        case ..<85: .warm
        default: .hot
        }
    }

    static func color(_ percent: Double, _ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        return switch level(percent) {
        case .calm: dark ? Color(red: 0.231, green: 0.761, blue: 0.541) : Color(red: 0.122, green: 0.541, blue: 0.384)
        case .warm: dark ? Color(red: 0.867, green: 0.627, blue: 0.227) : Color(red: 0.659, green: 0.478, blue: 0.118)
        case .hot: dark ? Color(red: 0.851, green: 0.361, blue: 0.322) : Color(red: 0.753, green: 0.224, blue: 0.184)
        }
    }
}

/// What every family needs from the snapshot.
extension Snapshot {
    /// The windows that are running now, with a rolled-over window projected forward while
    /// its agent is active, as the app's panel shows them.
    func liveLimits(at now: Date) -> [UsageLimit] {
        limits.compactMap { limit in
            if !limit.hasRolledOver(by: now) { return limit }
            guard let end = limit.currentWindowEnd(now: now, activeSince: latestActivity(for: limit.agent)) else { return nil }
            return UsageLimit(agent: limit.agent, title: limit.title, percentUsed: 0, resetsAt: end, windowLength: limit.windowLength)
        }
    }

    /// The fullest live window: what the small widget shows.
    func fullest(at now: Date) -> UsageLimit? {
        liveLimits(at: now).max { $0.percentUsed < $1.percentUsed }
    }

    /// "as of 12:04" once the app's last read is old enough to matter.
    func staleNote(at now: Date) -> String? {
        guard now.timeIntervalSince(readAt) > 10 * 60 else { return nil }
        return "as of \(readAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))"
    }
}

extension UsageLimit {
    /// Time left as the panel writes it, or a dash.
    func timeLeft(at now: Date) -> String {
        guard let resetsAt, resetsAt > now else { return "—" }
        return Format.short(resetsAt.timeIntervalSince(now))
    }

    /// "Weekly · all models" → "Weekly · all": the columns are narrow.
    var shortTitle: String { title.replacingOccurrences(of: " · all models", with: " · all") }
}

/// The empty widget: the app has not written yet, or the file is gone.
struct NothingYet: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open AgentBar once")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
