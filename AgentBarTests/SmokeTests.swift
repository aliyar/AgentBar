import Foundation
import Testing
@testable import AgentBar

@Suite("Smoke")
struct SmokeTests {
    @Test func hostIsTheApp() {
        #expect(Bundle.main.bundleIdentifier == "com.greatpixels.AgentBar")
        #expect(ProcessInfo.processInfo.isRunningTests)
    }

    @Test func dependenciesBootstrapOnce() async {
        await MainActor.run {
            AppDependencies.bootstrap()
            let first = AppDependencies.shared
            AppDependencies.bootstrap()
            #expect(first === AppDependencies.shared)
        }
    }
}
