import OSLog

nonisolated enum Log {
    /// The bundle id, so `make logs` and Console filter on it: `subsystem == "com.greatpixels.<App>"`.
    static let subsystem = Bundle.main.bundleIdentifier ?? "app"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let statusItem = Logger(subsystem: subsystem, category: "statusItem")
    static let updates = Logger(subsystem: subsystem, category: "updates")
}
