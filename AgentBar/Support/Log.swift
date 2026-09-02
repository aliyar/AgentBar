import OSLog

nonisolated enum Log {
    static let subsystem = "com.greatpixels.AgentBar"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let statusItem = Logger(subsystem: subsystem, category: "statusItem")
    static let updates = Logger(subsystem: subsystem, category: "updates")
}
