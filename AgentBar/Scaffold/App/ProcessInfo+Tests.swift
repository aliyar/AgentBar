import Foundation

extension ProcessInfo {
    /// True when running inside an XCTest/Swift Testing host: the app must not start its
    /// refresh loop or the updater then.
    nonisolated var isRunningTests: Bool {
        environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestConfigurationFilePath"] != nil
    }
}
