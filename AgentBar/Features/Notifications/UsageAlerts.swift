import Foundation
import AgentBarKit

/// `UsageWatch`, remembered across launches. What it holds is which marks each window has
/// already been announced at, so a restart - or an update - part way through a week does not
/// say again what was said before it.
final class UsageAlerts {
    private static let key = "usageAlertMarks"
    private let defaults: UserDefaults
    private var watch: UsageWatch

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        watch = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(UsageWatch.self, from: $0) }
            ?? UsageWatch()
    }

    /// The alerts one snapshot earns; written back whenever what is remembered changed.
    func observe(_ limits: [UsageLimit], watching: Set<String>, thresholds: [Int], now: Date) -> [UsageWatch.Alert] {
        let before = watch
        let alerts = watch.observe(limits, watching: watching, thresholds: thresholds, now: now)
        if watch != before, let data = try? JSONEncoder().encode(watch) {
            defaults.set(data, forKey: Self.key)
        }
        return alerts
    }
}
